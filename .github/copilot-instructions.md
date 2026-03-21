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
  - **✅ All non-test scripts must load successfully** - If any non-test script has syntax/type errors, Godot validation fails
  - **✅ All test scripts must compile** - Test files need to load without errors so their preload() statements work
  - If test scripts fail to compile (e.g., if a `preload()` in a test file fails), the entire test suite is skipped/blocked

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
