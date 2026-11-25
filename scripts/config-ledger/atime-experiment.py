#!/usr/bin/env python3
"""Record whether reads update access time on the state directory's volume."""

import datetime
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time


def stamp(ns):
    return datetime.datetime.fromtimestamp(ns / 1e9, datetime.timezone.utc).isoformat()


def main():
    state = Path.home() / ".local/state/config-ledger"
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    with tempfile.TemporaryDirectory(prefix="atime-", dir=state) as tmp:
        path = Path(tmp) / "sample"
        path.write_bytes(b"sample")
        created = path.stat().st_atime_ns
        time.sleep(1.1)
        path.read_bytes()
        fresh_read = path.stat().st_atime_ns
        old = time.time() - 2 * 86400
        os.utime(path, (old, old))
        before_old_read = path.stat().st_atime_ns
        path.read_bytes()
        after_old_read = path.stat().st_atime_ns
        mount = subprocess.run(["df", str(path)], text=True, capture_output=True, check=True).stdout.splitlines()[-1].split()[-1]
        mount_lines = subprocess.run(["mount"], text=True, capture_output=True, check=True).stdout.splitlines()
        options = {point: next((line.rsplit(" (", 1)[-1].rstrip(")").split(", ") for line in mount_lines if f" on {point} (" in line), []) for point in (mount, "/System/Volumes/Data")}
    result = {"path": str(state), "df_mount": mount, "mount_options": options,
              "created_atime": stamp(created), "fresh_read_atime": stamp(fresh_read),
              "old_atime_before_read": stamp(before_old_read), "old_atime_after_read": stamp(after_old_read),
              "fresh_read_updated": fresh_read > created, "old_read_updated": after_old_read > before_old_read}
    output = state / "atime-experiment.json"
    output.write_text(json.dumps(result, indent=2) + "\n")
    output.chmod(0o600)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
