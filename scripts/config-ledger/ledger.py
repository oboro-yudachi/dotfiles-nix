#!/usr/bin/env python3
"""Build a local, content-free inventory from the machine's configuration records."""
import csv
import datetime as dt
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
from collections import Counter, defaultdict

HOME = Path.home()
OUT = HOME / '.local/state/config-ledger'
NOW = dt.datetime.now(dt.timezone.utc)
CUTOFF = NOW - dt.timedelta(days=90)
FIELDS = ('id', 'kind', 'name', 'source_of_truth', 'installed', 'last_used',
          'use_count_90d', 'use_evidence', 'owner', 'depends_on', 'rebuildable',
          'rebuildable_reason')


def run(*args, cwd=None, check=True):
    p = subprocess.run(args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                       text=True, errors='replace')
    if check and p.returncode:
        raise RuntimeError(f'{args[0]} failed ({p.returncode})')
    return p.stdout if p.returncode == 0 else None


def command_json(*args):
    data = json.loads(run(*args))
    if data.get('ok') is False:
        raise RuntimeError(f'{args[0]} command failed')
    return data.get('result', data)


def read_json(path):
    with path.open(encoding='utf-8') as f:
        return json.load(f)


def date(value):
    try:
        if value is None:
            return None
        if isinstance(value, (int, float)):
            d = dt.datetime.fromtimestamp(value / 1000, dt.timezone.utc)
        else:
            d = dt.datetime.fromisoformat(value.replace('Z', '+00:00'))
            if d.tzinfo is None:
                d = d.replace(tzinfo=dt.timezone.utc)
        return d.astimezone(dt.timezone.utc)
    except (ValueError, TypeError, OverflowError, OSError):
        return None


def iso(value):
    return value.isoformat().replace('+00:00', 'Z') if value else None


def row(kind, name, key=None, **kw):
    result = dict(id=f'{kind}:{key or name}', kind=kind, name=name,
                  source_of_truth=None, installed=[], last_used=None,
                  use_count_90d=None, use_evidence=[], owner=None, depends_on=[],
                  rebuildable='unknown', rebuildable_reason='unknown')
    result.update(kw)
    return result


def protected(path):
    return bool(re.search(r'(^|[/_. -])(drafts?|backups?|notes?|reports?)([/_. -]|$)',
                          str(path), re.I))


def usage_event(events, key, when, evidence):
    if key and when:
        events[key].append((when, evidence))


def usage_fields(events):
    if not events:
        return dict(last_used=None, use_count_90d=0, use_evidence=[])
    return dict(last_used=iso(max(t for t, _ in events)),
                use_count_90d=sum(t >= CUTOFF for t, _ in events),
                use_evidence=sorted({e for _, e in events}))


def read_logs():
    events = defaultdict(list)
    patterns = [(HOME / '.claude/projects', '*/*.jsonl', 'claude'),
                (HOME / '.codex/sessions', '**/*.jsonl', 'codex')]
    path_re = re.compile(r'(?<![\w/])(?:~|/)[^\s\"\'`;&|<>]*?/([^/\s\"\'`;&|<>]+)/SKILL\.md')
    for root, pattern, origin in patterns:
        for path in sorted(root.glob(pattern)):
            try:
                with path.open(encoding='utf-8', errors='replace') as f:
                    for line in f:
                        try:
                            record = json.loads(line)
                        except (ValueError, TypeError):
                            continue
                        when = date(record.get('timestamp'))
                        if not when:
                            continue
                        if origin == 'claude':
                            content = record.get('message', {}).get('content', [])
                            if not isinstance(content, list):
                                continue
                            for item in content:
                                if not isinstance(item, dict) or item.get('type') != 'tool_use':
                                    continue
                                inp = item.get('input', {})
                                if not isinstance(inp, dict):
                                    continue
                                if item.get('name') == 'Skill':
                                    skill = inp.get('skill')
                                    if isinstance(skill, str):
                                        usage_event(events, skill, when, 'claude Skill tool_use')
                                elif item.get('name') in ('Read', 'Bash'):
                                    text = inp.get('file_path', '') if item['name'] == 'Read' else inp.get('command', '')
                                    for name in set(path_re.findall(str(text))):
                                        usage_event(events, name, when, 'claude SKILL.md read')
                        else:
                            payload = record.get('payload', {})
                            if payload.get('type') not in ('function_call', 'custom_tool_call'):
                                continue
                            text = payload.get('arguments', payload.get('input', ''))
                            for name in set(path_re.findall(str(text).replace('\\/', '/'))):
                                usage_event(events, name, when, 'codex SKILL.md read')
            except OSError:
                raise RuntimeError(f'cannot read {path}') from None
    return events


def skills(events):
    lock_path = HOME / '.agents/.skill-lock.json'
    lock = read_json(lock_path).get('skills', {}) if lock_path.exists() else {}
    found = defaultdict(list)
    for root in (HOME / '.agents/skills', HOME / '.claude/skills'):
        for p in sorted(root.glob('*')):
            if p.is_dir() and (p / 'SKILL.md').is_file():
                found[p.name].append((p, None, None))
    for agent in ('.claude', '.codex'):
        for p in sorted((HOME / agent / 'plugins/cache').glob('*/*/*/skills/*')):
            if p.is_dir() and (p / 'SKILL.md').is_file():
                found[p.name].append((p, p.parent.parent.name, p.parent.parent.parent.name))
    rows = []
    for name, entries in sorted(found.items()):
        installations = [dict(location=str(p), version=v) for p, v, _ in entries]
        targets = sorted({str(p.resolve()) for p, _, _ in entries if p.is_symlink() and p.resolve().exists()})
        source = targets[0] if targets else (str(lock_path) if name in lock else None)
        cache_only = all(v for _, v, _ in entries)
        yes = bool(targets or name in lock or cache_only)
        status = 'yes' if yes else 'unknown'
        reason = 'plugin cache versions' if cache_only else ('source exists' if targets else ('skills lock' if name in lock else 'unknown'))
        if any(protected(p) for p, _, _ in entries):
            status, reason = 'no', 'notes, reports, drafts or backups'
        ev = list(events.get(name, []))
        for _, _, plugin in entries:
            if plugin:
                ev += events.get(f'{plugin}:{name}', [])
        rows.append(row('skill', name, source_of_truth=source, installed=installations,
                        depends_on=sorted({p for _, _, p in entries if p}),
                        rebuildable=status, rebuildable_reason=reason, **usage_fields(ev)))
    return rows


def plugins():
    result = {}
    manifest = HOME / '.claude/plugins/installed_plugins.json'
    for name, entries in read_json(manifest).get('plugins', {}).items():
        r = result.setdefault(name, row('plugin', name, source_of_truth=str(manifest)))
        r['installed'].extend(dict(location=e.get('installPath'), version=e.get('version')) for e in entries)
    for e in command_json('codex', 'plugin', 'list', '--json').get('installed', []):
        name = e['pluginId']
        r = result.setdefault(name, row('plugin', name))
        source = e.get('source') or {}
        if source.get('path') and Path(source['path']).exists():
            r['source_of_truth'] = source['path']
        for p in sorted((HOME / '.codex/plugins/cache').glob(f'*/{e["name"]}/{e.get("version", "*")}')):
            r['installed'].append(dict(location=str(p), version=e.get('version')))
    for r in result.values():
        if r['installed'] and all('/plugins/cache/' in (i['location'] or '') for i in r['installed']):
            r.update(rebuildable='yes', rebuildable_reason='plugin cache versions')
        r['installed'].sort(key=lambda x: (x['location'] or '', x['version'] or ''))
    return list(result.values())


def bots_and_automations():
    bots = command_json('orca', 'bot', 'list', '--json').get('bots', [])
    rows = []
    for bot in bots:
        events, cursor = defaultdict(list), None
        while True:
            args = ['orca', 'bot', 'item', 'list', '--all', '--bot', bot['name'], '--limit', '100', '--json']
            if cursor:
                args += ['--cursor', cursor]
            result = command_json(*args)
            for item in result.get('items', []):
                usage_event(events, bot['name'], date(item.get('createdAt')), 'orca bot item created')
            cursor = result.get('nextCursor') or result.get('next_cursor')
            if not cursor:
                break
        rows.append(row('bot', bot['name'], source_of_truth='orca bot list',
                        owner=bot['name'], **usage_fields(events[bot['name']])))
    data = command_json('orca', 'automations', 'list', '--json')
    summaries = {x['automationId']: x.get('usageSummary') for x in data.get('items', [])}
    for a in data.get('automations', []):
        summary = summaries.get(a['id']) or {}
        last = date(summary.get('lastRunAt') or a.get('lastRunAt'))
        # Aggregate run totals have no 90-day breakdown.
        rows.append(row('automation', a['name'], key=a['id'], source_of_truth='orca automations list',
                        owner=(a.get('bot') or {}).get('botId'), last_used=iso(last),
                        use_evidence=['orca automation lastRunAt'] if last else []))
    return rows


def git_rows():
    rows = []
    repos = command_json('orca', 'repo', 'list', '--json').get('repos', [])
    for repo in repos:
        if repo.get('kind') != 'git':
            continue
        path = repo['path']
        if not Path(path).is_dir():
            print(f'skipped unavailable repository: {path}', file=sys.stderr)
            continue
        default = run('git', 'symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD', cwd=path, check=False)
        default = default.strip() if default else None
        if not default:
            for candidate in ('main', 'master'):
                if run('git', 'rev-parse', '--verify', candidate, cwd=path, check=False):
                    default = candidate
                    break
        merged_text = run('git', 'branch', '--merged', default, '--format=%(refname:short)', cwd=path, check=False) if default else None
        merged = set(merged_text.splitlines()) if merged_text is not None else set()
        branches = run('git', 'for-each-ref', '--format=%(refname:short)', 'refs/heads', cwd=path).splitlines()
        for branch in branches:
            status = 'yes' if branch in merged else 'unknown'
            rows.append(row('branch', branch, key=f'{path}:{branch}', source_of_truth=path,
                            rebuildable=status, rebuildable_reason='merged branch' if status == 'yes' else 'unknown'))
        porcelain = run('git', 'worktree', 'list', '--porcelain', cwd=path)
        for block in porcelain.strip().split('\n\n'):
            info = dict(line.split(' ', 1) for line in block.splitlines() if ' ' in line)
            wt = info.get('worktree')
            if not wt:
                continue
            branch = info.get('branch', '').removeprefix('refs/heads/')
            changes = run('git', 'status', '--porcelain', '--untracked-files=normal', cwd=wt, check=False)
            if changes is None:
                state, reason = 'unknown', 'git status unavailable'
            elif changes:
                state, reason = 'no', 'uncommitted changes'
            elif protected(wt):
                state, reason = 'no', 'notes, reports, drafts or backups'
            elif branch in merged:
                state, reason = 'yes', 'clean worktree with merged branch'
            else:
                state, reason = 'unknown', 'unknown'
            rows.append(row('worktree', Path(wt).name, key=wt, source_of_truth=path,
                            installed=[dict(location=wt, version=None)], depends_on=[branch] if branch else [],
                            rebuildable=state, rebuildable_reason=reason))
            if state == 'no' and reason == 'uncommitted changes':
                for branch_row in rows:
                    if branch_row['id'] == f'branch:{path}:{branch}':
                        branch_row.update(rebuildable='no', rebuildable_reason=reason)
    return rows


def directories():
    events = defaultdict(list)
    history = HOME / '.zsh_history'
    if history.exists():
        for line in history.read_text(encoding='utf-8', errors='replace').splitlines():
            match = re.match(r'^: (\d+):\d+;(.*)$', line)
            if not match:
                continue
            try:
                words = shlex.split(match.group(2))
            except ValueError:
                continue
            if len(words) == 2 and words[0] == 'cd' and not words[1].startswith('-'):
                target = Path(os.path.expanduser(words[1]))
                if target.is_absolute():
                    usage_event(events, str(target), dt.datetime.fromtimestamp(int(match.group(1)), dt.timezone.utc), 'zsh cd')
    paths = []
    for root in (HOME / 'repo', HOME / '.agents', HOME / 'dev', HOME / 'orca'):
        if root.is_dir():
            for first in sorted(root.iterdir()):
                if first.is_dir() and not first.is_symlink():
                    paths.append(first)
                    paths.extend(p for p in sorted(first.iterdir()) if p.is_dir() and not p.is_symlink())
    rows = []
    for p in paths:
        size = run('du', '-sk', str(p), check=False)
        ev = usage_fields(events[str(p)])
        if not ev['last_used']:
            ev['last_used'] = iso(dt.datetime.fromtimestamp(p.stat().st_mtime, dt.timezone.utc))
            ev['use_evidence'] = ['directory mtime (last resort)']
        if size:
            ev['use_evidence'].append('du KiB: ' + size.split()[0])
        state = 'no' if protected(p) else 'unknown'
        rows.append(row('directory', p.name, key=str(p), source_of_truth=str(p),
                        installed=[dict(location=str(p), version=None)], rebuildable=state,
                        rebuildable_reason='notes, reports, drafts or backups' if state == 'no' else 'unknown', **ev))
    return rows


def main():
    rows = skills(read_logs()) + plugins() + bots_and_automations() + git_rows() + directories()
    rows.sort(key=lambda r: r['id'])
    OUT.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(OUT, 0o700)
    with (OUT / 'ledger.json').open('w', encoding='utf-8') as f:
        json.dump({'generated_at': iso(NOW), 'rows': rows}, f, ensure_ascii=False, indent=2)
        f.write('\n')
    with (OUT / 'ledger.csv').open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()
        for r in rows:
            writer.writerow({k: json.dumps(v, ensure_ascii=False, sort_keys=True) if isinstance(v, (list, dict)) else v for k, v in r.items()})
    for field in ('kind', 'rebuildable'):
        print(field, json.dumps(dict(sorted(Counter(r[field] for r in rows).items())), ensure_ascii=False))
    print('least-used skills')
    for r in sorted((r for r in rows if r['kind'] == 'skill'), key=lambda r: (r['use_count_90d'], r['last_used'] or '', r['name']))[:10]:
        print(r['name'], r['use_count_90d'], r['last_used'] or '-')
    print(OUT / 'ledger.json')
    print(OUT / 'ledger.csv')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, ValueError) as exc:
        print(f'ledger: {exc}', file=sys.stderr)
        sys.exit(1)
