#!/usr/bin/env python3
"""Compare the recorded installations with their configuration sources."""
import argparse
import datetime as dt
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tarfile

HOME = Path.home()
STATE = HOME / '.local/state/config-ledger'
PSTACK = HOME / 'repo/02_oss/pstack-codex/pstack'
OBORO = HOME / 'repo/01_dev/oboro-skills'


def git(*args):
    env = dict(os.environ, GIT_TERMINAL_PROMPT='0', GIT_SSH_COMMAND='ssh -oBatchMode=yes')
    return subprocess.run(['git', '-C', str(OBORO), *args], check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env,
                          timeout=90).stdout


def files(root):
    if not root.is_dir():
        raise FileNotFoundError(root)
    return {str(p.relative_to(root)): p.read_bytes() for p in root.rglob('*')
            if p.is_file() and '.in_use' not in p.relative_to(root).parts}


def compare(label, expected, installed, differences):
    if not installed.is_dir():
        differences.append(f'{label}: missing directory {installed}')
        return
    actual = files(installed)
    for name in sorted(expected.keys() | actual.keys()):
        if name not in actual:
            differences.append(f'{label}: missing {name}')
        elif name not in expected:
            differences.append(f'{label}: extra {name}')
        elif expected[name] != actual[name]:
            differences.append(f'{label}: changed {name}')


def check_skill_lock(folder, entry, root, differences):
    name = entry.get('skillName', folder)
    installed = root / folder
    if not installed.is_dir():
        differences.append(f'skill lock: missing installed folder {folder} (skillName {name})')
    elif name != folder:
        skill = installed / 'SKILL.md'
        if not skill.is_file():
            differences.append(f'skill lock: missing {skill}')
            return
        text = skill.read_text(encoding='utf-8')
        frontmatter = re.match(r'\A---\s*\n(.*?)\n---\s*(?:\n|$)', text, re.DOTALL)
        match = re.search(r'^name:\s*[\'"]?([\w-]+)[\'"]?\s*$', frontmatter.group(1), re.MULTILINE) if frontmatter else None
        if not match:
            differences.append(f'skill lock: {folder} has no valid installed name')
        elif match.group(1) != folder:
            differences.append(f'skill lock: {folder} has installed name {match.group(1)}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--offline', action='store_true', help='use the last fetched default branch')
    args = parser.parse_args()
    differences = []
    errors = []

    def check(name, fn):
        try:
            fn()
        except (OSError, ValueError, KeyError, subprocess.SubprocessError, tarfile.TarError) as exc:
            detail = exc.stderr.decode(errors='replace').strip() if isinstance(exc, subprocess.CalledProcessError) and exc.stderr else str(exc)
            errors.append(f'{name}: check failed: {detail.replace(chr(10), " ")}')

    ledger = json.loads((STATE / 'ledger.json').read_text(encoding='utf-8'))

    def pstack():
        version = json.loads((PSTACK / '.codex-plugin/plugin.json').read_text())['version']
        cache = HOME / '.codex/plugins/cache/pstack-codex/pstack' / version
        compare(f'pstack Codex {version}', files(PSTACK), cache, differences)
        for source in sorted((PSTACK / 'agents').glob('*.toml')):
            target = HOME / '.codex/agents' / source.name
            if not target.is_file():
                differences.append(f'pstack role: missing {target}')
            elif source.read_bytes() != target.read_bytes():
                differences.append(f'pstack role: changed {target}')
    check('pstack', pstack)

    def oboro():
        if not args.offline:
            git('fetch', '--quiet', 'origin')
        ref = git('symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD').decode().strip()
        archive = git('archive', ref, 'oboro')
        with tarfile.open(fileobj=io.BytesIO(archive), mode='r:') as tar:
            expected = {m.name.removeprefix('oboro/'): tar.extractfile(m).read()
                        for m in tar.getmembers() if m.isfile()}
        version = json.loads(expected['.claude-plugin/plugin.json'])['version']
        for agent in ('.claude', '.codex'):
            cache = HOME / agent / 'plugins/cache/oboro-skills/oboro' / version
            compare(f'oboro {agent} {version}', expected, cache, differences)
    check('oboro', oboro)

    def plugins():
        manifest = json.loads((HOME / '.claude/plugins/installed_plugins.json').read_text())
        for name, entries in sorted(manifest['plugins'].items()):
            plugin, marketplace = name.split('@', 1)
            for entry in entries:
                version = entry['version']
                expected = HOME / '.claude/plugins/cache' / marketplace / plugin / version
                path = Path(entry['installPath']).expanduser()
                if path != expected:
                    differences.append(f'Claude plugin {name}: version {version} points to {path}, expected {expected}')
                if not expected.is_dir():
                    differences.append(f'Claude plugin {name}: missing cache {expected}')
    check('Claude plugins', plugins)

    def skills():
        lock = json.loads((HOME / '.agents/.skill-lock.json').read_text())['skills']
        for folder, entry in sorted(lock.items()):
            check_skill_lock(folder, entry, HOME / '.agents/skills', differences)
        root = HOME / '.claude/skills'
        for path in sorted(root.rglob('*')):
            if path.is_symlink() and not path.exists():
                differences.append(f'Claude skill symlink: broken {path} -> {os.readlink(path)}')
    check('skills', skills)

    result = {'generated_at': dt.datetime.now(dt.timezone.utc).isoformat(),
              'ledger_generated_at': ledger.get('generated_at'), 'offline': args.offline,
              'differences': differences, 'errors': errors}
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    (STATE / 'drift.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for line in differences:
        print(line)
    for line in errors:
        print(line, file=sys.stderr)
    return 1 if differences or errors else 0


if __name__ == '__main__':
    sys.exit(main())
