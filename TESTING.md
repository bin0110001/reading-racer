# GDUnit4 Testing Setup - Reading Racer

## What's Been Set Up

I've configured GDUnit4 for the Reading Racer project and created comprehensive unit tests to diagnose what's not loading correctly.

### Test Files Created

1. **tests/unit/systems/test_track_generator.gd**
   - Tests TrackGenerator initialization, segment generation, and position lookup
   - Validates that StraightSegment and CurveSegment work correctly
   - Checks heading interpolation for curves

2. **tests/unit/systems/test_trigger_areas.gd**
   - Tests ReadingPickupTrigger, ReadingObstacleTrigger, and ReadingFinishGateTrigger
   - Validates signal declarations and initialization
   - Checks that trigger functions exist (trigger_pickup, trigger_obstacle)

3. **tests/unit/systems/test_control_profiles.gd**
   - Tests LaneChangeController, SmoothSteeringController, and ThrottleSteeringController
   - Validates mode names and required methods
   - Checks steering influence values for each mode

4. **tests/unit/systems/test_reading_mode_setup.gd**
   - Tests that all required scripts can be loaded
   - Validates ReadingContentLoader, ReadingSettingsStore, ReadingHUD, PhonemePlayer
   - Checks reading_mode.tscn scene loads

### Diagnostic Tools Created

1. **scripts/reading/startup_diagnostic.gd** (Autoload)
   - Runs automatically when the game starts
   - Checks if all classes are properly initialized
   - Reports which classes are available and which are missing
   - Validates the reading_mode.tscn scene exists

2. **scripts/reading/startup_debugger.gd** (Can be attached to reading_mode.tscn)
   - Detailed startup debugging for the reading mode scene
   - Checks scene node structure
   - Validates content loader, settings, track generator
   - Tests control profile and trigger instantiation

## Running the Tests

### Option 1: Run via GDUnit4 GUI (Recommended)
1. Open the project in Godot 4.6
2. Go to panel → Tests → GDUnit4
3. Click "Run all tests" or select specific test files
4. View test results and any failures

### Option 2: Run from Command Line
```powershell
cd c:\Projects\reading-racer
godot -s ./addons/gdUnit4/bin/gd_unit_cmd.gd --headless --verbose
```

### Option 3: View Diagnostic Output
1. Run the game with F5
2. Check the Godot console output for diagnostic information
3. The startup_diagnostic.gd autoload will print which classes are available

## Interpreting Test Results

### Successful Test Output
```
✓ TrackGenerator should be instantiable
✓ Should generate at least one segment
✓ Should retrieve segment at index
```

### Failed Test Output
```
✗ Should generate at least one segment
  Expected: not empty
  Actual: []
```

## What Each Test Checks

### Track Generator Tests
- ✓ Can instantiate TrackGenerator
- ✓ Initialization clears segments
- ✓ generate_to_distance() creates segments
- ✓ Segments have valid headings
- ✓ Can look up segments by position

### Trigger Tests
- ✓ All trigger classes instantiate
- ✓ All triggers have required signals
- ✓ Triggers have handler methods (trigger_pickup, trigger_obstacle)
- ✓ Finish gate can set pickup state

### Control Profile Tests
- ✓ All profiles instantiate
- ✓ Profiles have correct mode names
- ✓ All required methods exist
- ✓ Steering influence values are correct:
  - LaneChange: 1.0 (full auto-steer)
  - SmoothSteering: ~0.5 (partial auto-steer)
  - ThrottleSteering: 0.0 (no auto-steer)

### Setup Tests
- ✓ All GDScript files can be loaded
- ✓ All required classes are available
- ✓ reading_mode.tscn scene exists

## Debugging

If tests fail, check:

1. **Class Not Found Errors**
   - Verify the class has a `class_name` declaration at the top
   - Ensure file paths match the class names
   - Check that files are not ignored by .gitignore

2. **Initialization Errors**
   - Run startup_debugger.gd to see which initialization step fails
   - Check if dependencies are properly loaded

3. **Scene Structure Errors**
   - Verify reading_mode.tscn has required child nodes: Road, SpawnRoot, Player, CameraRig, ReadingHUD, PhonemePlayer
   - Check node types match expected types (Node3D, Area3D, etc.)

## Next Steps

1. **Run the tests** to identify what's not working
2. **Fix critical failures** (missing classes, initialization errors)
3. **Verify in-game** that:
   - Corners appear in the track
   - Letters trigger phonemes
   - Obstacles cause slowdown
   - Finish gate works
   - All three control modes function

## Quick Diagnostics

To see immediate diagnostic output without running tests:

1. Open Godot and run the scene
2. Look at the Godot console output
3. Search for "=== Reading Racer Diagnostic Report ===" to see class availability
4. The startup_diagnostic.gd autoload will list which systems loaded successfully

## Commands for Common Tasks

```powershell
# Run all validation checks
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1

# Auto-format all scripts
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1 -Fix

# Format specific files
gdformat scripts/reading/*.gd
```

## Test Structure

```
tests/
├── unit/
│   └── systems/
│       ├── test_track_generator.gd      # Track & segment tests
│       ├── test_trigger_areas.gd        # Trigger class tests
│       ├── test_control_profiles.gd     # Control mode tests
│       └── test_reading_mode_setup.gd   # Scene & loader tests
```

All tests use GDUnit4's assertion library. See `assert_*` functions in test files for examples.
