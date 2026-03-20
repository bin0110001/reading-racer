After updating a GDScript file, run the repository helper script to parse, lint, check formatting, and validate with Godot all at once.

1) Install or update the gdtoolkit CLI:

python -m pip install -U gdtoolkit

2) Run the check script (recommended):

```powershell
# From the repository root
powershell -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1
```

This will:

- Run gdparse to check syntax
- Run gdlint to check code style
- Run gdformat to check formatting
- Run Godot validation (--headless --script --check-only) to catch strict parser errors

3) (Optional) Auto-format all scripts:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1 -Fix
```

---

## Test Lessons Learned (use this as a checklist)

- Use `GdUnitTestSuite` with `assert_that()` methods (not old `assert_true`, `assert_not_null`, etc.) for GdUnit4.
- Avoid older magic helpers (`watch_signals(self)`) in new tests unless the harness actually defines them.
- Use real script name casing from project paths (`reading_hud.gd`, `phoneme_player.gd`) to avoid `load()` mismatches.
- Construct objects with required init args if the class uses `new(...)` (e.g., `StraightSegment.new(0, pos, length)`).
- For trigger state checks, avoid non-existent methods and use fields that exist (`all_pickups_collected`).
- `gdscript-check.ps1` now includes `tests/scripts` and runs GDUnit CLI; expect exit `101` for warnings/orphans.
- Keep failing/edge tests focused: fix strict parser path first, then test-case logic.

If we run into other issues creating GD Scripts, keep this up to date.

Inline quick-run command (really good):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1
```
