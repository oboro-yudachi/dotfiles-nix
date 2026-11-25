#!/usr/bin/env python3
"""Quarantine stale plugin caches, merged worktrees, and merged branches."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

HOME = Path.home()
STATE = HOME / '.local/state'
ROOT = STATE / 'quarantine'
LEDGER = STATE / 'config-ledger/ledger.json'
PROTECTED = re.compile(r'(^|[/_. -])(drafts?|backups?|notes?|reports?)([/_. -]|$)', re.I)


def run(*args, cwd=None):
    p = subprocess.run(args, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode:
        raise RuntimeError(f'{args}: {p.stderr.strip()}')
    return p.stdout.strip()


def git(repo, *args):
    return run('git', '-C', str(repo), *args)


def worktrees(repo):
    blocks = git(repo, 'worktree', 'list', '--porcelain').split('\n\n')
    return [dict(line.split(' ', 1) for line in b.splitlines() if ' ' in line) for b in blocks if b]


def default_ref(repo):
    try:
        return git(repo, 'symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD')
    except RuntimeError:
        for name in ('main', 'master'):
            try:
                git(repo, 'rev-parse', '--verify', 'refs/heads/' + name)
                return name
            except RuntimeError:
                pass
    return None


def orca_worktrees():
    data = json.loads(run('orca', 'worktree', 'ps', '--json'))
    result = data['result']
    if not data.get('ok') or result.get('truncated') or result.get('hostScope', {}).get('omittedHostIds'):
        raise RuntimeError('Orca worktree list incomplete')
    return result['worktrees']


def idle(path, entries):
    for w in entries:
        if w.get('path') != str(path):
            continue
        if (w.get('status') not in ('inactive',) or w.get('terminalVerdict') != 'none'
                or any(a.get('state') not in ('done', 'idle') for a in w.get('agents', []))):
            return False
    return True


def size(path):
    # du reports allocated bytes and does not follow symlinks.
    return int(run('du', '-sk', str(path)).split()[0]) * 1024


def contains_protected(path):
    for root, dirs, files in os.walk(path, followlinks=False):
        dirs[:] = [d for d in dirs if d != '.git']
        if any(PROTECTED.search(str(Path(root) / name)) for name in dirs + files):
            return True
    return False


def candidates(date):
    rows = json.loads(LEDGER.read_text())['rows']
    installed = json.loads((HOME / '.claude/plugins/installed_plugins.json').read_text())['plugins']
    installed_paths = {str(Path(e['installPath']).resolve()) for v in installed.values() for e in v if e.get('installPath')}
    # Only plugin families represented in the ledger and the installed manifest.
    families = {Path(e['installPath']).parent for v in installed.values() for e in v if e.get('installPath')}
    ledger_paths = {str(Path(i['location']).resolve()) for r in rows if r['kind'] == 'plugin' for i in r['installed'] if i.get('location')}
    entries = orca_worktrees()
    found = []
    def add(kind, original, new, repo=None, head=None, byte_size=0):
        identifier = kind + '-' + hashlib.sha256((str(repo) + ':' + str(original)).encode()).hexdigest()[:16]
        found.append(dict(id=identifier, kind=kind, original=str(original), new=str(new), repo=str(repo) if repo else None, git_head=head, size=byte_size))
    for family in sorted(families):
        if not any(str(p).startswith(str(family) + '/') for p in ledger_paths):
            continue
        for path in sorted(family.iterdir()):
            if path.is_symlink() or not path.is_dir() or str(path.resolve()) in installed_paths or PROTECTED.search(str(path)):
                continue
            add('plugin', path, ROOT / date / 'plugins' / path.relative_to(HOME / '.claude/plugins/cache'), byte_size=size(path))
    repos = {r['source_of_truth'] for r in rows if r['kind'] in ('branch', 'worktree') and r['source_of_truth']}
    for repo in sorted(repos):
        if not Path(repo).is_dir():
            continue
        default = default_ref(repo)
        if not default:
            continue
        merged = set(git(repo, 'branch', '--merged', default, '--format=%(refname:short)').splitlines())
        wts = worktrees(repo)
        checked = {w.get('branch', '').removeprefix('refs/heads/') for w in wts}
        main_path = wts[0].get('worktree') if wts else None
        repo_key = hashlib.sha256(repo.encode()).hexdigest()[:12]
        for r in rows:
            if r['source_of_truth'] != repo or r['rebuildable'] != 'yes':
                continue
            if r['kind'] == 'worktree':
                path = Path(r['installed'][0]['location'])
                info = next((w for w in wts if w.get('worktree') == str(path)), None)
                if (not info or str(path) == main_path or not path.is_dir() or path.resolve() == Path.cwd().resolve()
                    or PROTECTED.search(str(path)) or not idle(path, entries) or info.get('locked') is not None):
                    continue
                branch = info.get('branch', '').removeprefix('refs/heads/')
                if not branch or branch not in merged or git(path, 'status', '--porcelain', '--untracked-files=all'):
                    continue
                if contains_protected(path):
                    continue
                add('worktree', path, ROOT / date / 'worktrees' / repo_key / path.name, repo, git(path, 'rev-parse', 'HEAD'), size(path))
            elif r['kind'] == 'branch':
                branch = r['name']
                if branch not in merged or branch in checked or branch == default or branch == default.removeprefix('origin/') or branch.startswith('quarantine/') or PROTECTED.search(branch):
                    continue
                add('branch', branch, f'quarantine/{date}/{branch}', repo, git(repo, 'rev-parse', 'refs/heads/' + branch))
    return found


def save(path, data):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def move(item, reverse=False):
    source, dest = (item['new'], item['original']) if reverse else (item['original'], item['new'])
    if item['kind'] == 'branch':
        repo = item['repo']
        if git(repo, 'rev-parse', '--verify', 'refs/heads/' + source) != item['git_head']:
            raise RuntimeError('branch head changed: ' + source)
        # git branch -m refuses an existing destination without -M.
        git(repo, 'branch', '-m', source, dest)
    else:
        source, dest = Path(source), Path(dest)
        if not source.is_dir() or dest.exists() or dest.is_symlink():
            raise RuntimeError(f'missing source or occupied destination: {source} -> {dest}')
        dest.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        if item['kind'] == 'worktree':
            if git(source, 'rev-parse', 'HEAD') != item['git_head'] or git(source, 'status', '--porcelain', '--untracked-files=all'):
                raise RuntimeError('worktree changed: ' + str(source))
            git(item['repo'], 'worktree', 'move', str(source), str(dest))
        else:
            os.rename(source, dest)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest='command', required=True)
    for command in ('plan', 'apply'):
        q = sub.add_parser(command)
        q.add_argument('--kind', choices=['plugin', 'worktree', 'branch'], action='append')
        q.add_argument('--only', action='append')
        q.add_argument('--date', default=dt.date.today().isoformat())
        q.add_argument('--include-worktrees', action='store_true',
                       help='allow worktrees; git worktree move causes Orca to drop them from its list, even after restore')
    q = sub.add_parser('restore')
    q.add_argument('manifest', type=Path)
    q.add_argument('--only')
    a = p.parse_args()
    if a.command == 'restore':
        data = json.loads(a.manifest.read_text())
        selected = [i for i in data['items'] if not a.only or i['id'] == a.only]
        if not selected:
            raise RuntimeError('no matching manifest item')
        for item in reversed(selected):
            if item['status'] == 'pending':
                if item['kind'] == 'branch':
                    def exists(ref):
                        return subprocess.run(['git', '-C', item['repo'], 'show-ref', '--verify', '--quiet', 'refs/heads/' + ref]).returncode == 0
                    original_exists, new_exists = exists(item['original']), exists(item['new'])
                else:
                    original_exists, new_exists = Path(item['original']).exists(), Path(item['new']).exists()
                if original_exists and not new_exists:
                    continue
                if original_exists or not new_exists:
                    raise RuntimeError('cannot determine pending item state: ' + item['id'])
            elif item['status'] != 'moved':
                continue
            move(item, reverse=True)
            item['status'] = 'restored'
            save(a.manifest, data)
        return
    if not re.fullmatch(r'\d{4}-\d{2}-\d{2}(?:-[a-zA-Z0-9_-]+)?', a.date):
        raise RuntimeError('invalid date')
    if a.kind and 'worktree' in a.kind and not a.include_worktrees:
        p.error('worktrees require --include-worktrees: git worktree move causes Orca to drop them from its list, even after restore')
    items = [i for i in candidates(a.date) if (not a.kind or i['kind'] in a.kind) and (not a.only or i['id'] in a.only)]
    if not a.include_worktrees:
        items = [i for i in items if i['kind'] != 'worktree']
    for i in items:
        print(f"{i['id']} {i['original']} -> {i['new']} ({i['size']} bytes)")
    if a.command == 'plan':
        return
    manifest = ROOT / a.date / 'manifest.json'
    manifest.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    if manifest.exists():
        raise RuntimeError('manifest already exists: ' + str(manifest))
    data = dict(created_at=dt.datetime.now(dt.timezone.utc).isoformat(), items=items)
    for i in items:
        i['status'] = 'pending'
    save(manifest, data)
    for i in items:
        move(i)
        i['status'] = 'moved'
        save(manifest, data)
    print('manifest:', manifest)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError) as exc:
        print(f'quarantine: {exc}', file=sys.stderr)
        sys.exit(1)
