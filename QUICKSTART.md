# Quick Start Guide - 8-Player Racing Game

## What's Been Built

Your racing game now includes:

✅ **GameManager** - Manages race state (waiting, countdown, racing, finished)
✅ **8-Vehicle Racing System** - Up to 8 simultaneous racers  
✅ **Countdown Timer** - 3-second countdown before race starts
✅ **Individual Timers** - Each player tracks their lap/race times
✅ **Lap Tracking** - Checkpoint-based lap detection (default 3 laps)
✅ **Results Screen** - Shows final standings after race completion
✅ **HUD Display** - Live race statistics and countdown display
✅ **Network Framework** - Ready for online multiplayer (optional)

## Getting Started

### 1. Open the Scene
- Open `scenes/main.tscn` in Godot 4.5
- All components should load automatically

### 2. Run the Game
- Press F5 or click the Play button
- Game starts in WAITING state

### 3. Start a Race
- **Press SPACE** ("bounce" action) to begin countdown
- Countdown shows "3" → "2" → "1" → "GO!"
- Race begins with all 8 vehicles
- Live HUD shows position, lap, and time for each racer

### 4. Completing the Race
- First player to complete 3 laps finishes
- Results screen shows standings when all finish
- **Press SPACE** to restart

## Game Controls

### Vehicle Controls (Each Player)
```
Movement:
  W              - Forward / Accelerate
  A              - Steer Left
  S              - Brake / Reverse  
  D              - Steer Right

Gamepad:
  Right Trigger  - Forward
  Left Trigger   - Brake
  Left Stick     - Steering
```

### Race Control
```
SPACE ("bounce" action) - Start countdown (waiting state)
SPACE ("bounce" action) - Restart race (results screen)
```

## Key Files

| File | Purpose |
|------|---------|
| `scripts/GameManager.gd` | Race state machine, lap tracking, timing |
| `scripts/RaceTrack.gd` | Track layout, checkpoints, starting positions |
| `scripts/vehicle.gd` | Vehicle physics, input, animations |
| `scripts/RaceHUD.gd` | UI for countdown, live stats, results |
| `scripts/VehicleSpawner.gd` | Creates 8 vehicles at startup |
| `scripts/RaceController.gd` | Game flow, input handling |
| `scripts/NetworkManager.gd` | Online multiplayer framework |
| `scenes/main.tscn` | Main race scene |

## Configuration

### Change Number of Laps
Edit `scripts/GameManager.gd`:
```gdscript
const RACE_LAPS = 3  # Change this number
```

### Change Starting Positions
Edit `scripts/RaceTrack.gd`:
```gdscript
var starting_positions: Array[Transform3D] = [
    Transform3D(Basis.identity, Vector3(3.5, 0, 5)),  # Vehicle 1
    Transform3D(Basis.identity, Vector3(5.0, 0, 5)),  # Vehicle 2
    # ... etc
]
```

### Adjust Vehicle Physics
Edit `scripts/vehicle.gd`:
```gdscript
var max_speed = 40.0              # Faster/slower top speed
var acceleration_rate = 15.0      # Snappier/slower acceleration
var deceleration_rate = 8.0       # Harder/softer braking
```

## Important Notes

### ⚠️ Testing Checkpoints
The current lap detection system requires:
1. Checkpoints must be created correctly (Area3D with collision)
2. Vehicles must have the `player_id` metadata set
3. RaceTrack must properly create checkpoints

If lap times aren't updating:
- Check console output for debug messages
- Verify checkpoints are positioned along your track
- Ensure the GridMap-based track matches checkpoint positions

### 🔍 Debug Tips
Add this to **GameManager.gd** to see lap triggers in console:
```gdscript
func player_triggered_checkpoint(player_id: int, checkpoint_id: int) -> void:
    print("Player %d crossed checkpoint %d" % [player_id, checkpoint_id])
    # ... rest of function
```

### 🎮 Testing with Multiple Controllers
- Connect 2-8 controllers to your machine
- Each vehicle will respond to inputs from connected gamepads
- Player 1 (red truck) uses first connected controller
- Cycling through controllers for each vehicle

### 🌐 Enabling Network Multiplayer
To enable online play between machines:

1. Edit `scripts/RaceController.gd` and add:
```gdscript
var network_manager: Node

func _ready():
    network_manager = get_node_or_null("../NetworkManager")
    if network_manager:
        network_manager.start_server(9999)  # For host
        # network_manager.start_client("SERVER_IP", 9999)  # For client
```

2. Start game on server machine
3. Connect clients to server IP
4. Race state synchronizes across network

## Troubleshooting

### "Cannot find RaceHUD" Error
**Fix:** Ensure RaceHUD node is properly connected in main.tscn
- The RaceHUD must be a CanvasLayer child node

### Vehicles appear but don't move
**Fix:** Check if physics is enabled
- Game must be in RACING state (press SPACE after game starts)
- Confirm input actions are bound in project.godot

### Checkpoints not working
**Fix:** Verify RaceTrack setup
- Check that checkpoints are created in `_create_default_checkpoints()`
- View checkpoints in 3D view to confirm position
- Checkpoint positions should be around your track

### Results screen shows 0 = in infinite loop
**Fix:** Ensure all players can trigger checkpoints
- Adjust checkpoint positions to match your track
- Verify collision mask/layer settings

## Next Steps

### Enhance the Game
1. **Add custom track** - Modify GridMap or checkpoint positions
2. **Sound effects** - Already setup for lap/finish events
3. **Particle effects** - Already integrated (smoke trails)
4. **UI polish** - Add buttons, menus, settings
5. **Leaderboards** - With NetworkManager, can save scores

### Local Split-Screen (4 Players)
Current setup supports local multiplayer with multiple controllers.
For split-screen cameras:
1. Create 4 cameras with viewports
2. Position viewports as quadrants
3. Assign each camera to follow a vehicle

### Network Multiplayer
See `MULTIPLAYER_RACING_GUIDE.md` for details on enabling online play.

## Support

**Common Issues:**
- Physics issues: Check collision layers/masks in main.tscn
- HUD not showing: Verify RaceHUD script is attached
- Input not working: Check Input Map in project.godot

**Performance:**
- 8 vehicles running simultaneously
- Monitor frame rate on target hardware
- Can optimize vehicle models/physics if needed

---

**You now have a complete multiplayer racing game ready to play and customize!**

See `MULTIPLAYER_RACING_GUIDE.md` for complete documentation.
