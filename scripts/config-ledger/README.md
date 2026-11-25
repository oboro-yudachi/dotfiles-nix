# Configuration ledger

From the repository root, run each morning:

```sh
python3 scripts/config-ledger/drift.py; drift=$?; python3 scripts/config-ledger/refcheck.py; refs=$?; [ "$drift" -eq 0 ] && [ "$refs" -eq 0 ]
```

Both checks run even if the first fails. The command exits 0 when neither check finds a problem, and 1 otherwise. Drift reports differences or check errors; refcheck reports broken references or check errors. The detailed results are written to `~/.local/state/config-ledger/drift.json` and `~/.local/state/config-ledger/refcheck.json`. Drift uses the existing `ledger.json` in that directory and fetches the oboro default branch; refresh the inventory with `python3 scripts/config-ledger/ledger.py` when needed.

The skills lock's `skillName` identifies the upstream skill. Drift reports a different folder name unless the folder and upstream name are listed in `INTENDED_RENAMES` in `drift.py`; for those pairs, it checks that the installed `SKILL.md` declares the folder name. This does not verify that a future `skills update` preserves the rename.
