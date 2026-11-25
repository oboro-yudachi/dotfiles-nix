#!/usr/bin/env python3
"""List non-rebuildable ledger locations without moving them."""
import csv
import datetime as dt
import json
from pathlib import Path
import subprocess
import sys

STATE = Path.home() / '.local/state/config-ledger'


def main():
    ledger = json.loads((STATE / 'ledger.json').read_text(encoding='utf-8'))
    locations = {}
    for row in ledger['rows']:
        if row['rebuildable'] != 'no':
            continue
        for installation in row['installed']:
            if installation.get('location'):
                locations.setdefault(installation['location'], set()).add(row['rebuildable_reason'])
    candidates = []
    errors = []
    for location, reasons in locations.items():
        path = Path(location)
        try:
            stat = path.lstat()
            result = subprocess.run(['du', '-sk', str(path)], capture_output=True, text=True, check=True)
            candidates.append({'path': location, 'size_bytes': int(result.stdout.split()[0]) * 1024,
                               'last_modified': dt.datetime.fromtimestamp(stat.st_mtime, dt.timezone.utc).isoformat(),
                               'reason': '; '.join(sorted(reasons))})
        except (OSError, ValueError, subprocess.SubprocessError) as exc:
            errors.append(f'{location}: {exc}')
    candidates.sort(key=lambda item: (-item['size_bytes'], item['path']))
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    output = STATE / 'candidates.csv'
    with output.open('w', encoding='utf-8', newline='') as file:
        writer = csv.DictWriter(file, fieldnames=['path', 'size_bytes', 'last_modified', 'reason'])
        writer.writeheader()
        writer.writerows(candidates)
    for item in candidates[:20]:
        print(f"{item['size_bytes']:>14}  {item['last_modified']}  {item['path']}")
    for error in errors:
        print(error, file=sys.stderr)
    print(f'{len(candidates)} locations; {len(errors)} errors; {output}')
    return int(bool(errors))


if __name__ == '__main__':
    sys.exit(main())
