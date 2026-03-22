After updating a GDScript file, run the repository helper script to parse, lint, check formatting, and validate with Godot all at once.

1) Install or update the gdtoolkit CLI:

python -m pip install -U gdtoolkit

2) Run the check script (recommended):

```powershell
# From the repository root
powershell -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1
```

If Godot is not on `PATH`, pass it explicitly or set `GODOT_BIN`:

```powershell
$env:GODOT_BIN = 'C:\Path\To\Godot.exe'
powershell -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1
```

You can also point the checker at a specific Godot project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1 -ProjectRoot .
```

If you need to override which GDUnit test roots are executed, pass one or more `-GdUnitTarget` values:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1 -GdUnitTarget test/scripts
powershell -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1 -GdUnitTarget test/scripts, tests/scripts
```

This will:

- Run gdparse to check syntax
- Run gdlint to check code style
- Run gdformat to check formatting
- Run Godot project validation (`--headless --check-only`) to catch strict parser errors
- Run GDUnit CLI when the project has both `test` or `tests` scripts and `addons/gdUnit4/bin/GdUnitCmdTool.gd`
  - **✅ All project scripts must load successfully**
  - **✅ Test scripts must compile before the suite can execute**
  - **✅ GDUnit results are read from the current run's XML report, not stale stdout heuristics**
  - **✅ Orphan-node warnings fail the run and tell you to add `collect_orphan_node_details()` to the leaking test**

3) (Optional) Auto-format all scripts:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1 -Fix
```

4) Run the checker's PowerShell regression tests when you change the runner:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1 -RunTests
```

---

## Test Lessons Learned (use this as a checklist)

- Use `GdUnitTestSuite` with `assert_that()` methods (not old `assert_true`, `assert_not_null`, etc.) for GdUnit4.
- Avoid older magic helpers (`watch_signals(self)`) in new tests unless the harness actually defines them.
- Use real script name casing from project paths (`reading_hud.gd`, `phoneme_player.gd`) to avoid `load()` mismatches.
- Construct objects with required init args if the class uses `new(...)` (e.g., `StraightSegment.new(0, pos, length)`).
- For trigger state checks, avoid non-existent methods and use fields that exist (`all_pickups_collected`).
- `gdscript-check.ps1` auto-discovers the Godot project root, scans project `.gd` files while excluding generated and gdUnit addon files, and runs GDUnit from a per-run report directory.
- `gdscript-check.ps1` auto-discovers GDUnit roots under `test/` and `tests/`, but you can override them with `-GdUnitTarget` when a project needs explicit targeting.
- Treat orphan-node warnings as failures and use `collect_orphan_node_details()` in the leaking test to capture the offending nodes.
- Keep failing/edge tests focused: fix strict parser path first, then test-case logic.
- **CRITICAL: Treat skipped tests as failures.** If any test file doesn't run due to syntax/compilation errors in source code, those count as failures. The full test suite won't execute if a `preload()` statement in a test file fails (e.g., if reading_mode.gd has syntax errors, test_reading_mode_setup tests won't run). Always verify:
  1. gdparse passes (syntax check on all 31 files)
  2. Godot validation passes (all non-test AND test scripts must compile without errors)
  3. GDUnit CLI executes (test files load and run)
- **New workflow**: When an error is reported, do NOT fix it directly; first add a regression test that fails for that same error message, then implement the code fix, and then re-run tests to confirm the regression test now passes.
- **Test validity rule**: a test must be executed by the suite to count. A test that is not included or is skipped is not a test.
If we run into other issues creating GD Scripts, keep this up to date.

Inline quick-run command (really good):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1
```
