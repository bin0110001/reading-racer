Path to Godot:

    D:\Gadot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe

****Important: If GDUnit results.xml missing fix it. Never dismiss it as an unrelated issue.**

After updating a GDScript file, run the repository helper script to parse, lint, check formatting, validate with Godot, and test scenes all at once.

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
- **Check for duplicate global class_name declarations** (catches naming conflicts before runtime)
- Run Godot project validation (`--check-only`) in non-headless mode by default; use `--headless` only in CI where UI is unavailable
- Run GDUnit CLI when the project has both `test` or `tests` scripts and `addons/gdUnit4/bin/GdUnitCmdTool.gd`
  - **✅ All project scripts must load successfully**
  - **✅ Test scripts must compile before the suite can execute**
  - **✅ GDUnit results are read from the current run's XML report, not stale stdout heuristics**
  - **✅ Orphan-node warnings fail the run and tell you to add `collect_orphan_node_details()` to the leaking test**
  - **✅ Scene Runner tests validate scene structure, initialization, and gameplay flows (Phase 2-3)**

3) (Optional) Auto-format all scripts:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1 -Fix
```

4) Run the checker's PowerShell regression tests when you change the runner:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1 -RunTests
```

---

## Error Discovery Pipeline (Four-Layer Validation)

The validation pipeline now catches four categories of errors before launch:

1. **Syntax & Code Quality** (gdparse, gdlint, gdformat)

   - Syntax errors, parse failures
   - Code style violations
   - Formatting issues
2. **Global Scope Conflicts** (NEW - Check-DuplicateGlobalClassNames)

   - Duplicate `class_name` declarations across files
   - Example: having both `scripts/CameraController3D.gd` and `scripts/reading/CameraController3D.gd` is caught immediately
3. **Type & Load Failures** (Godot validation)

   - Script compilation errors
   - Missing dependencies
   - Type mismatches
4. **Scene & Gameplay Integration** (GDUnit Scene Runner tests - NEW)

   - Scene structure and node hierarchy integrity
   - Signal connections and initialization
   - No orphaned nodes during gameplay
   - Game state transitions and input handling
   - Critical gameplay flows (reading_mode.tscn player movement, UI updates, etc.)

---

## Scene Runner Tests (NEW)

Scene Runner tests are GDUnit integration tests that validate entire scenes with simulated input/gameplay.

Files:

- `test/scripts/scenes/test_scene_loader.gd` — Basic smoke tests (all scenes load)
- `test/scripts/scenes/test_scene_runner_integration.gd` — Advanced gameplay tests (reading_mode.tscn input, state, updates)

These tests:

- ✅ Verify all .tscn files can be instantiated without errors
- ✅ Simulate gameplay (player input, frame advancement)
- ✅ Check scene state transitions
- ✅ Detect orphaned nodes during simulation
- ✅ Run as part of GDUnit suite automatically

Example: When you modify `reading_mode.tscn`, the suite will immediately test that it loads, initializes state, and simulates 30 frames without crashes.

---

## Test Lessons Learned (use this as a checklist)

- Use `GdUnitTestSuite` with `assert_that()` methods (not old `assert_true`, `assert_not_null`, etc.) for GdUnit4.
- Avoid older magic helpers (`watch_signals(self)`) in new tests unless the harness actually defines them.
- Use real script name casing from project paths (`reading_hud.gd`, `phoneme_player.gd`) to avoid `load()` mismatches.
- Construct objects with required init args if the class uses `new(...)` (e.g., `StraightSegment.new(0, pos, length)`).
- For trigger state checks, avoid non-existent methods and use fields that exist (`all_pickups_collected`).
- `gdscript-check.ps1` auto-discovers the Godot project root, scans project `.gd` files while excluding generated and gdUnit addon files, and runs GDUnit from a per-run report directory.
- `gdscript-check.ps1` auto-discovers GDUnit roots under `test/` and `tests/`, but you can override them with `-GdUnitTarget` when a project needs explicit targeting.
- **Duplicate class_name rule**: Only one script can declare `class_name MyClass`. If you see "Class X hides a global script class" errors at launch, run gdscript-check to catch them during development.
- Treat orphan-node warnings as failures and use `collect_orphan_node_details()` in the leaking test to capture the offending nodes.
- Keep failing/edge tests focused: fix strict parser path first, then test-case logic.
- **CRITICAL: Treat skipped tests as failures.** If any test file doesn't run due to syntax/compilation errors in source code, those count as failures. The full test suite won't execute if a `preload()` statement in a test file fails (e.g., if reading_mode.gd has syntax errors, test_reading_mode_setup tests won't run). Always verify:
  1. gdparse passes (syntax check on all .gd files)
  2. Duplicate class_name check passes (no global scope conflicts)
  3. Godot validation passes (all non-test AND test scripts must compile without errors)
  4. GDUnit CLI executes (test files load and run)
  5. Scene Runner tests pass (scene structure and gameplay flows validated)
- **New workflow**: When an error is reported, do NOT fix it directly; first add a regression test that fails for that same error message, then implement the code fix, and then re-run tests to confirm the regression test now passes.
- **Test validity rule**: a test must be executed by the suite to count. A test that is not included or is skipped is not a test.
- **Scene Runner best practices**:
  - Use `scene_runner("res://path/to/scene.tscn")` to load a scene for testing
  - Simulate gameplay with `await runner.simulate_frames(frame_count, ms_per_frame)`
  - Check scene state with `runner.get_property()` and assertions
  - GDUnit orphan detection is automatic; tests will fail if nodes are leaked
- If we run into other issues creating GD Scripts or scene tests, keep this up to date.
- UI text for kid-focused pages should be minimal and icon-first (e.g., arrows for selection, emoji for actions, short labels).

## Painting debug guide
- Root log file: `.github/painting_debug_log.md`
- Always update this file when applying a new hypothesis or code change for painting.
- Include: symptom, file(s) changed, patch details, engine/log output, and result.
- Call out whether fix is in overlay path (`OverlayAtlasManager` + `CameraBrush`) or decal path (`Decal` nodes).

Note for Copilot: when trapping persistent painting bugs, reference and append this file for thread safety and onboarding.

Inline quick-run command (really good):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1
```
