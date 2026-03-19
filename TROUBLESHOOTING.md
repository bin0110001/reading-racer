# Troubleshooting Guide - Multiplayer Racing Game

## Common Issues & Solutions

### Issue 1: Vehicles Not Spawning

**Symptom:** Game starts but no vehicles visible, only empty track

**Possible Causes:**
1. VehicleSpawner script error
2. GameManager not initialized
3. Vehicle models not found

**Solutions:**
```godot
# 1. Check console for errors (Window → Toggle Output Console)
# Should see: "Race initialized with 8 players"

# 2. Verify GameManager in scene
# - Open scenes/main.tscn
# - Look for GameManager node in scene tree
# - Should be first child of Main

# 3. Check VehicleSpawner script
# - Verify it's attached to VehicleSpawner node
# - Add debug print to _ready():
#
# func _ready() -> void:
#     print("VehicleSpawner ready")
#     game_manager = ...
#     print("GameManager found: ", game_manager != null)
#     spawn_all_vehicles()
#     print("Spawned vehicles: ", len(spawned_vehicles))

# 4. Check vehicle model paths
# - Verify these files exist:
#   - res://models/vehicle-truck-yellow.glb
#   - res://models/vehicle-truck-green.glb
#   - res://models/vehicle-truck-purple.glb
#   - res://models/vehicle-truck-red.glb
```

---

### Issue 2: Countdown Doesn't Start

**Symptom:** Press SPACE but nothing happens, game stays in "Waiting for Players"

**Possible Causes:**
1. SPACE input not bound
2. RaceController not in scene
3. GameManager state not transitioning

**Solutions:**
```godot
# 1. Check input bindings
# - Project → Project Settings → Input Map
# - Look for "bounce" (space) action since countdown uses it
# - If missing, add it:
#   - Click "Add Item"
#   - Type "bounce"
#   - Click "Add Event"
#   - Press SPACE

# 2. Verify RaceController in scene
# - Open scenes/main.tscn
# - Look for RaceController node
# - Script should be RaceController.gd

# 3. Test countdown manually
# - Add this to RaceController._ready():
#   game_manager.start_countdown()  # Auto-start for testing
# - Run game - should see countdown

# 4. Add debug output
# - Edit GameManager.gd, in _on_countdown_start():
#
# func _on_countdown_start() -> void:
#     print("Countdown started!")
#     countdown_timer = COUNTDOWN_SECONDS
#     # ...
```

---

### Issue 3: Vehicles Don't Move

**Symptom:** Vehicles spawn but don't respond to input, stay stationary

**Possible Causes:**
1. Physics disabled (race not started)
2. Vehicle input not working
3. Sphere physics body issue

**Solutions:**
```godot
# 1. Verify race started
# - Game must show countdown first
# - Then show live HUD
# - Only then will vehicles move
# - Check HUD to confirm race state

# 2. Test input
# - Add to vehicle.gd _physics_process:
#
# func _physics_process(delta):
#     print("Input X: %f, Z: %f" % [input.x, input.z])
#     # ... rest of code

# 3. Check physics process enabled
# - Vehicle should have set_physics_process(true)
# - Only GameManager calls this when race starts
# - Add debug in vehicle._ready():
#
# print("Physics enabled: ", is_physics_processing())

# 4. Verify sphere collision shape
# - In main.tscn, check Vehicle/Sphere
# - Should have CollisionShape3D child
# - Shape should be SphereShape3D with radius 0.5
```

---

### Issue 4: Lap Times Not Updating

**Symptom:** Race runs but HUD shows 0 laps, times don't increment

**Possible Causes:**
1. Checkpoints not created
2. Vehicle not triggering checkpoint
3. GameManager not detecting checkpoint cross

**Solutions:**
```godot
# 1. Verify checkpoints exist
# - Add debug to RaceTrack._ready():
#
# func _ready():
#     # ... existing code ...
#     print("Checkpoint count: ", len(checkpoints))
#     for i in range(len(checkpoints)):
#         print("Checkpoint %d position: %s" % [i, checkpoints[i].position])

# 2. Check checkpoint positions match track
# - In RaceTrack._create_default_checkpoints()
# - Verify positions are on/near your track
# - Default positions:
#   - Checkpoint 0: (3.5, 1, 5) - Start/Finish
#   - Checkpoint 1: (15, 1, 5)
#   - Checkpoint 2: (15, 1, -15)
#   - Checkpoint 3: (-15, 1, -15)

# 3. Debug checkpoint detection
# - Add to RaceTrack._on_checkpoint_triggered():
#
# func _on_checkpoint_triggered(body, checkpoint_index):
#     print("Vehicle crossed checkpoint %d: %s" % [checkpoint_index, body.name])
#     if body.has_meta("player_id"):
#         print("  Player ID: %d" % body.get_meta("player_id"))

# 4. Test lap completion
# - Add to GameManager.player_triggered_checkpoint():
#
# print("Checkpoint: P%d, CP%d, Current Sector: %d, New Sector: %d" % [
#     player_id, checkpoint_id, 
#     players[player_id]["sector"], 
#     checkpoint_id + 1
# ])
```

---

### Issue 5: Results Screen Shows Wrong Data

**Symptom:** Final screen displays incorrect times or repeated positions

**Possible Causes:**
1. Lap times not being recorded correctly
2. Player finish order not tracked
3. Data formatting issue

**Solutions:**
```godot
# 1. Check player data
# - Add to GameManager._finish_player():
#
# var player_data = players[player_id]
# print("Player %d finished:" % player_id)
# print("  Laps: %d" % player_data["lap"])
# print("  Time: %.2f" % player_data["finish_time"])
# print("  Lap times: %s" % player_data["lap_times"])

# 2. Verify completion order
# - Print player_completion_order in _on_race_finished():
#
# print("Completion order: %s" % player_completion_order)

# 3. Check time formatting
# - Test _format_time() function in RaceHUD
# - Should produce MM:SS.ms format
# - Example: "03:45.67"

# 4. Verify all players finish
# - Check that all 8 players complete race
# - If stuck waiting, might need to lower lap count for testing
```

---

### Issue 6: Performance Issues / Lag

**Symptom:** Game runs slow or drops frames

**Solutions:**
```godot
# 1. Check physics count
# - 8 vehicles = 8 RigidBody3D + ray casting
# - Use Profiler: Debug → Monitor → Physics/Rendering
# - Target: 60 FPS, <16.67ms per frame

# 2. Reduce vehicle complexity
# - Simplify vehicle models
# - Use fewer particles
# - Reduce physics simulation steps:
#   
#   Project → Project Settings → Physics → 3D
#   → Set "Iterations Per Second" to 30 (default 60)

# 3. Check draw call count
# - Debug → Profiler → Rendering
# - Target: <100 draw calls
# - Reduce by combining materials

# 4. Disable debug visualization
# - Remove debug_shape_custom_color from RayCast3D
# - Remove debug shapes from checkpoints

# 5. Use simpler checkpoint system
# - Current system creates many Area3D nodes
# - Could optimize with single large collision area
# - Or use spatial hashing instead
```

---

### Issue 7: Error: "Cannot find script at ..."

**Symptom:** Scene won't load, error about missing scripts

**Solution:**
```godot
# 1. Verify script files exist
# - Open File Manager
# - Check scripts folder contains:
#   ✓ GameManager.gd
#   ✓ RaceTrack.gd
#   ✓ RaceHUD.gd
#   ✓ RaceController.gd
#   ✓ VehicleSpawner.gd
#   ✓ vehicle.gd
#   ✓ NetworkManager.gd

# 2. If missing any, recreate from documentation

# 3. Reload scripts in Godot
# - File → Reload Opened Resources
# - Or close and reopen project

# 4. Check scene file paths
# - Open scenes/main.tscn in text editor
# - Look for ExtResource entries
# - Should match script locations exactly
```

---

### Issue 8: "Race initialized with 0 players"

**Symptom:** Game shows this message - no vehicles registered

**Causes:**
1. VehicleSpawner not executed
2. GameManager not ready
3. await statement failing

**Solutions:**
```gdscript
# 1. Add explicit initialization
# - In RaceController._ready(), after await:
#
# if game_manager.get_players_count() == 0:
#     print("No players found - spawning vehicles")
#     if vehicle_spawner.has_method("spawn_all_vehicles"):
#         vehicle_spawner.spawn_all_vehicles()

# 2. Remove await if causing issues
# - In RaceController._ready(), change:
#     await get_tree().process_frame
# - To immediate call:
#     _initialize_race()

# 3. Check spawn order
# - GameManager must be ready before vehicles spawn
# - VehicleSpawner calls game_manager.register_player()
# - If GameManager not initialized, registration fails
```

---

### Issue 9: Controller Input Not Working

**Symptom:** Keyboard works but gamepad input ignored

**Solutions:**
```godot
# 1. Check input map for gamepad actions
# - Project → Project Settings → Input Map
# - "forward" should have:
#   - Key: W
#   - Joy Axis: Right Trigger (or device 0, axis 5)
# - "left" should have:
#   - Key: A  
#   - Joy Axis: Left Stick (or device -1, axis 0, -1.0)

# 2. Test controller detection
# - Add to vehicle._ready():
#
# print("Connected joypads: ", Input.get_connected_joypads())

# 3. Verify multiple controllers
# - System → Settings → Devices → Input
# - Should list all connected controllers
# - Test each one separately

# 4. Change input polling
# - Add to vehicle._handle_input():
#
# input.x = Input.get_joy_axis(player_id, JOY_AXIS_LEFT_X)
# input.z = Input.get_joy_axis(player_id, JOY_AXIS_LEFT_Y)
```

---

### Issue 10: Network Multiplayer Not Working

**Symptom:** Server/client connections fail

**Solutions:**
```godot
# 1. Verify ENet is available
# - Godot must have ENet plugin
# - Download from asset library if needed

# 2. Check firewall
# - Windows Defender → Allow app through firewall
# - Add Godot.exe for both Public and Private

# 3. Test local network first
# - Server: 127.0.0.1 (localhost)
# - Client: 127.0.0.1 on same machine
# - Once working, try LAN IP (192.168.x.x)

# 4. Add debug output
# - In NetworkManager._ready():
#
# print("Network initialized")
# print("Is server: %s" % is_server())
# print("Is client: %s" % is_client())

# 5. Check peer count
# - Add to _on_peer_connected():
#
# print("Total peers: %d" % len(get_connected_peers()))
```

---

## Debug Mode Setup

Add this to a script for easy debugging:

```gdscript
var DEBUG = true

func _ready() -> void:
    if DEBUG:
        print("=== DEBUG MODE ENABLED ===")
        print("GameManager: ", game_manager != null)
        print("RaceTrack: ", race_track != null)
        print("RaceHUD: ", race_hud != null)
        print("VehicleSpawner: ", vehicle_spawner != null)

func debug_state() -> void:
    if DEBUG:
        print("=== RACE STATE ===")
        print("State: %s" % GameManager.RaceState.keys()[game_manager.current_state])
        print("Players: %d" % game_manager.get_players_count())
        for pid in game_manager.players:
            var data = game_manager.players[pid]
            print("  P%d: Lap %d, Time %.1f" % [pid, data["lap"], data["race_time"]])
```

---

## Gathering Diagnostic Info

When reporting issues, provide:
1. Error message from console (exact text)
2. Which step fails (startup, countdown, racing, etc)
3. Number of vehicles visible
4. Any debug output from suggestions above
5. Godot version (should be 4.5)
6. OS (Windows/Mac/Linux)

---

## Quick Reference: Normal Output

When everything works correctly, you should see:

```
Race initialized with 8 players
Connected joypads: [0]  # Or more for multiple controllers
= RACE HUD ===
P1: Lap 1 [00:15.32]
P2: Lap 0 [00:12.45]
P3: Lap 1 [00:16.01]
... (and so on for all 8)
```

---

**Still having issues?** Reference QUICKSTART.md and MULTIPLAYER_RACING_GUIDE.md for more details!
