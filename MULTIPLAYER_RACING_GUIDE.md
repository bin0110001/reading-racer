# Multiplayer Racing Game - Complete Development Guide

## Overview

This is a fully-fledged multiplayer racing game built on Godot 4.5 with support for:
- **8 concurrent racers** with predefined starting positions
- **Race countdown** with visual countdown timer
- **Individual player timers** tracking completion times
- **Lap tracking system** with checkpoint-based lap detection
- **Results screen** showing final standings and times
- **Network synchronization** framework for online multiplayer
- **Game state management** with clear race state transitions

## Architecture Overview

### Core Systems

#### 1. **GameManager** (`scripts/GameManager.gd`)
Central controller for race state and player management.

**Key Features:**
- Race state machine (WAITING → COUNTDOWN → RACING → FINISHED)
- Player registration and tracking
- Lap counting and time tracking
- Checkpoint triggering coordination
- Signals for race state changes and events

**Key Methods:**
```gdscript
register_player(player_id, vehicle)          # Register a new racer
player_triggered_checkpoint(player_id, cp_id) # Track lap progress
start_countdown()                             # Begin race countdown
get_player_data(player_id)                    # Retrieve player stats
```

#### 2. **RaceTrack** (`scripts/RaceTrack.gd`)
Manages track layout, checkpoints, and starting positions.

**Key Features:**
- 8 predefined starting positions (can be customized)
- Checkpoint system for lap tracking (Area3D-based)
- Starting position management

**Starting Positions:**
Default positions are arranged in a 2×4 grid:
```
[0] [1]  [4] [5]
[2] [3]  [6] [7]
```
Customize these in the `starting_positions` array.

**Checkpoints:**
- Auto-creates invisible checkpoints around track
- Detects vehicle entry via physics collision
- Reports back to GameManager
- Lap completion detected when vehicle crosses checkpoint 0 after other checkpoints

#### 3. **Vehicle** (`scripts/vehicle.gd`)
Individual vehicle controller with physics and input handling.

**Key Features:**
- Full 3D vehicle physics with acceleration, braking, steering
- Ground alignment for terrain following
- Particle effects for skids
- Audio feedback (engine, screech sounds)
- Player ID tracking for network identification
- Integration with GameManager

**Vehicle Physics Parameters (customizable):**
```gdscript
max_speed = 40.0
acceleration_rate = 15.0
deceleration_rate = 8.0
friction_rate = 5.0
```

#### 4. **RaceHUD** (`scripts/RaceHUD.gd`)
UI system for race display and results.

**Key Features:**
- Countdown display (3-2-1-GO!)
- Real-time race HUD showing all players' status
- Lap counters for each racer
- Elapsed time display
- Final results screen with podium positions
- Time formatting (MM:SS.ms)

**Display Modes:**
1. **WAITING** - "Waiting for players"
2. **COUNTDOWN** - Numeric countdown
3. **RACING** - Live race statistics
4. **FINISHED** - Results and standings

#### 5. **VehicleSpawner** (`scripts/VehicleSpawner.gd`)
Handles instantiation and setup of all 8 vehicles.

**Key Features:**
- Spawns all 8 vehicles at startup
- Assigns vehicle models (4 colors × 2 copies)
- Registers vehicles with GameManager
- Resets vehicles for new races

**Vehicle Models Used:**
- `vehicle-truck-yellow.glb`
- `vehicle-truck-green.glb`
- `vehicle-truck-purple.glb`
- `vehicle-truck-red.glb`

#### 6. **RaceController** (`scripts/RaceController.gd`)
Game flow manager handling state transitions and input.

**Key Features:**
- Initializes race at startup
- Listens for player input to start countdown
- Handles race restart on completion
- Coordinates between GameManager and VehicleSpawner

**Input Handling:**
- **SPACE** - Start countdown when waiting
- **SPACE** - Restart race after completion

#### 7. **NetworkManager** (`scripts/NetworkManager.gd`) [Optional]
Framework for online multiplayer support.

**Features:**
- Server/Client architecture using ENetMultiplayerPeer
- RPC-based state synchronization
- Peer connection management
- Vehicle state and input synchronization

**Usage:**
```gdscript
# Start server
network_manager.start_server(9999)

# Connect as client
network_manager.start_client("192.168.1.100", 9999)

# Check network role
if network_manager.is_server():
    # Server logic
```

## Game Flow

### Race Lifecycle

```
[WAITING] → [COUNTDOWN] → [RACING] → [FINISHED]
   ↓           ↓            ↓          ↓
 Show       Show 3-2-1   Display    Show results
 "Waiting"  countdown   live HUD    Press SPACE
 Press SPACE once 0      Track      to restart
```

### Lap Detection

1. Vehicle enters checkpoint Area3D
2. RaceTrack detects collision and calls GameManager
3. GameManager checks sequence:
   - If checkpoint is 0 AND vehicle was on other section → lap complete
   - Otherwise → update current sector
4. On lap completion:
   - Increment lap counter
   - Record lap time
   - Check if race complete (3 laps default)
   - If last lap → mark player as finished
5. On all finishes → show results screen

## Configuration & Customization

### Adjust Race Laps
Edit `GameManager.gd`:
```gdscript
const RACE_LAPS = 3  # Change to desired number
```

### Adjust Countdown Time
Edit `GameManager.gd`:
```gdscript
const COUNTDOWN_SECONDS = 3  # Change to desired duration
```

### Customize Starting Positions
Edit `RaceTrack.gd`:
```gdscript
var starting_positions: Array[Transform3D] = [
    Transform3D(Basis.identity, Vector3(3.5, 0, 5)),    # Player 0
    Transform3D(Basis.identity, Vector3(5.0, 0, 5)),    # Player 1
    # ... adjust X, Z coordinates as needed
]
```

### Modify Vehicle Physics
Edit `vehicle.gd`:
```gdscript
var max_speed: float = 40.0           # Top speed
var acceleration_rate: float = 15.0   # Acceleration factor
var deceleration_rate: float = 8.0    # Deceleration factor
```

### Adjust Checkpoint Layout
Edit `RaceTrack.gd`:
```gdscript
func _create_default_checkpoints() -> void:
    var checkpoint_positions = [
        Vector3(3.5, 1, 5),      # Start/Finish
        Vector3(15, 1, 5),       # Checkpoint 1
        Vector3(15, 1, -15),     # Checkpoint 2
        Vector3(-15, 1, -15),    # Checkpoint 3
        # Add more positions as needed
    ]
```

## Input Controls

### Player Controls (In-Race)
- **W / Right Trigger** - Accelerate
- **S / Left Trigger** - Brake/Reverse
- **A / Left Stick Left** - Steer Left
- **D / Right Stick Right** - Steer Right

### Race Controls
- **SPACE** - Start countdown (before race)
- **SPACE** - Restart race (after results)

## Running the Game

### Local Multiplayer (Single Machine)
1. Open the scene in Godot Editor
2. Run the main scene (`scenes/main.tscn`)
3. Use multiple controllers connected to the same machine
4. Each player will have their own vehicle

### Network Multiplayer (Online)
*Note: This is a framework. To enable:*

1. Modify RaceController to initialize NetworkManager:
```gdscript
var network_manager: Node

func _ready():
    # ... existing code ...
    network_manager = get_node_or_null("../NetworkManager")
    
    # Option 1: Host a game
    if is_host:
        network_manager.start_server(9999)
    else:
        # Option 2: Join a game
        network_manager.start_client("server_ip", 9999)
```

2. Synchronize player inputs and vehicle state using NetworkManager RPCs

3. Ensure consistent game state across all clients

## Extending the System

### Add Custom Vehicles
1. Create new vehicle models/colors
2. Add to vehicle_colors array in VehicleSpawner
3. Update _get_vehicle_model_path() method

### Add Track Variations
1. Create different checkpoint layouts in RaceTrack
2. Swap GridMap data for different terrain
3. Adjust starting positions per track

### Enhanced UI Features
1. **Mini-map** - Show player positions
2. **Speed indicator** - Display current speed for each vehicle
3. **Split-screen** - Render 4 cameras for local 4-player mode
4. **Particle effects** - Add explosion effects on collision
5. **Sound effects** - Lap completion sounds, finish line fanfare

### Advanced Multiplayer
1. **Matchmaking** - Server browser for finding games
2. **Chat system** - In-game communication
3. **Leaderboards** - Track best times globally
4. **Custom tracks** - Level editor for user-created courses

## Troubleshooting

### Vehicles Not Spawning
- Check VehicleSpawner script is attached to scene
- Verify GameManager exists and is ready
- Check console for errors in _setup_vehicle_structure()

### Checkpoints Not Detecting
- Ensure RaceTrack node exists in scene
- Verify vehicles have player_id metadata set
- Check checkpoint Area3D nodes are created
- Ensure checkpoint collision layers are configured

### Physics Issues
- Adjust gravity_scale in vehicle physics (default 1.5)
- Modify friction in PhysicsMaterial
- Check that spheres have proper collision shapes

### Network Not Syncing
- Verify ENet plugin is available in Godot
- Check firewall isn't blocking network port (9999)
- Ensure all clients have same script versions
- Monitor RPC call order for consistency

## File Structure
```
scripts/
├── GameManager.gd          # Core race state machine
├── RaceTrack.gd            # Track and checkpoint management
├── RaceHUD.gd              # UI display system
├── RaceController.gd       # Game flow controller
├── VehicleSpawner.gd       # Vehicle instantiation
├── vehicle.gd              # Individual vehicle physics
├── view.gd                 # Camera following (legacy)
├── NetworkManager.gd       # Multiplayer framework

scenes/
├── main.tscn               # Main race scene
└── main-environment.tres   # World environment settings

models/
├── vehicle-truck-*.glb     # Vehicle models (4 colors)
├── Library/
│   └── mesh-library.tres   # Track visuals
└── Textures/
    └── colormap.png        # Texture atlas

audio/
├── engine.ogg              # Engine sound
└── skid.ogg                # Skid/screech sound
```

## Performance Notes

- 8 vehicles with physics = ~1000+ collision checks per frame
- Test on target hardware
- Consider LOD for vehicle models if performance drops
- Disable shadows on particle effects for better performance
- Use single drawcall materials where possible

## Future Enhancements

1. **AI Drivers** - Computer-controlled opponents
2. **Weather System** - Rain affects grip, visibility
3. **Track Editor** - Create custom courses
4. **Replay System** - Playback race recordings
5. **Damage System** - Vehicle degradation
6. **Power-ups** - Speed boost, shield, etc.
7. **Mobile Support** - Touch controls for mobile devices
8. **VR Support** - Immersive first-person racing

---

**Status:** Ready for local multiplayer! Network synchronization framework is in place and can be enabled per your needs.
