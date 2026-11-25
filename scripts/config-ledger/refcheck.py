#!/usr/bin/env python3
"""Report missing local paths referenced by agent configuration and Orca prompts."""
import datetime as dt
import json
import os
from pathlib import Path
import re
import subprocess
import sys

HOME = Path.home()
STATE = HOME / '.local/state/config-ledger'
# Avoid URL components and relative path components; retain variables and globs
# so unresolvable references can be reported as skipped.
PATH = re.compile(r'(?<![\w/.:~$}\\-])(?:~(?=/)|\$(?:\{[A-Za-z_][\w]*-?\}|[A-Za-z_][\w]*)(?=/)|/)(?:[^\s\"\'`;,|(){}「」『』、。・]+)')
VARIABLE = re.compile(r'\$(?:\{([A-Za-z_][\w]*)-?\}|([A-Za-z_][\w]*))')
JSON_STRING = re.compile(r'"(?:\\.|[^"\\])*"')


def references(text):
    for number, line in enumerate(text.splitlines(), 1):
        for match in PATH.finditer(line):
            value = match.group().rstrip('.,:!?)')
            value = re.sub(r'(?<=\.app)(?=[ぁ-んァ-ン一-龯]).*', '', value)
            # TOML hook keys append event metadata to an actual path.
            value = re.sub(r':(?:session_start|user_prompt_submit|pre_tool_use|permission_request|post_tool_use|subagent_start|subagent_stop|stop|interrupt):\d+:\d+$', '', value)
            if value:
                yield number, value


def classify(value):
    if re.search(r'<[^>]*>|[*?\[\]]', value):
        return None, 'placeholder or glob'
    missing = [m.group(1) or m.group(2) for m in VARIABLE.finditer(value)
               if (m.group(1) or m.group(2)) not in os.environ]
    if missing or '$' in VARIABLE.sub('', value):
        return None, 'unresolved variable'
    expanded = os.path.expanduser(VARIABLE.sub(lambda m: os.environ[m.group(1) or m.group(2)], value))
    if not os.path.isabs(expanded):
        return None, 'not an absolute path after expansion'
    if expanded in ('/tmp', '/private/tmp') or expanded.startswith(('/tmp/', '/private/tmp/')):
        return None, 'scratch path'
    if re.fullmatch(r'/[A-Za-z][\w-]*', expanded) and not Path(expanded).exists():
        return None, 'ambiguous slash command or root path'
    return Path(expanded), None


def command_json(*args):
    proc = subprocess.run(args, capture_output=True, text=True, timeout=30, check=True)
    data = json.loads(proc.stdout)
    if data.get('ok') is False:
        raise RuntimeError(f'{args[0]} command failed: {data}')
    return data.get('result', data)


def main():
    broken, skipped, errors = [], [], []
    checked = 0

    def check(source, value, line=None, target=None):
        nonlocal checked
        record = {'source': source, 'reference': value}
        if line is not None:
            record['line'] = line
        path, reason = classify(str(target) if target is not None else value)
        if reason:
            skipped.append({**record, 'reason': reason})
        else:
            checked += 1
            if not path.exists():
                broken.append({**record, 'resolved': str(path)})

    for root in (HOME / '.claude/skills', HOME / '.agents/skills', HOME / '.codex'):
        def onerror(exc):
            errors.append(f'{root}: {exc}')
        for directory, dirs, files in os.walk(root, followlinks=False, onerror=onerror):
            for name in sorted(dirs + files):
                path = Path(directory) / name
                if path.is_symlink():
                    try:
                        raw = os.readlink(path)
                        target = Path(raw) if os.path.isabs(raw) else path.parent / raw
                        check(str(path), raw, target=target)
                    except OSError as exc:
                        errors.append(f'{path}: {exc}')

    bot_root = HOME / '.orca/bots'
    sources = [HOME / '.claude/CLAUDE.md', HOME / '.claude/settings.json',
               HOME / '.codex/AGENTS.md', HOME / '.codex/config.toml']
    for bot in sorted(bot_root.glob('*')):
        if bot.is_dir():
            sources.extend([bot / 'SOUL.md', bot / 'MEMORY.md', bot / '.claude/settings.json'])
            sources.extend(sorted((bot / 'memory').glob('**/*.md')))
    sources.extend(sorted((bot_root / 'new-bot/team').glob('*.sh')))
    for source in sources:
        if not source.exists():
            continue
        try:
            content = source.read_text(encoding='utf-8', errors='replace')
            if source.suffix == '.json':
                json.loads(content)  # Do not silently accept malformed settings.
                for number, line in enumerate(content.splitlines(), 1):
                    for token in JSON_STRING.finditer(line):
                        for _, value in references(json.loads(token.group())):
                            check(str(source), value, number)
            else:
                for line, value in references(content):
                    check(str(source), value, line)
        except (OSError, ValueError) as exc:
            errors.append(f'{source}: {exc}')

    try:
        automations = command_json('orca', 'automations', 'list', '--json')['automations']
        for automation in automations:
            identifier = automation['id']
            detail = command_json('orca', 'automations', 'show', identifier, '--json')['automation']
            prompt = detail.get('prompt') or automation.get('prompt') or ''
            for line, value in references(prompt):
                check(f'orca automation {identifier} ({automation["name"]})', value, line)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError, RuntimeError) as exc:
        errors.append(f'automations: {exc}')

    result = {'generated_at': dt.datetime.now(dt.timezone.utc).isoformat(),
              'checked': checked, 'broken': broken, 'skipped': skipped, 'errors': errors}
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    (STATE / 'refcheck.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for item in broken:
        print(f"{item['source']}:{item.get('line', '-')}: {item['reference']} -> {item['resolved']}")
    for error in errors:
        print(error, file=sys.stderr)
    print(f'{checked} checked; {len(broken)} broken; {len(skipped)} skipped; {len(errors)} errors')
    print(STATE / 'refcheck.json')
    return int(bool(broken or errors))


if __name__ == '__main__':
    sys.exit(main())
