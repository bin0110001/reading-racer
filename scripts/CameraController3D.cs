using Godot;
using System;

namespace BlackjackAndHookers.MapEditor;

/// <summary>
/// Shared 3D camera controller with Unity-style controls.
/// Provides orbit, pan, zoom, and focus functionality.
/// 
/// Controls:
/// - Right-click + drag: Orbit around target
/// - Middle-click + drag (or Alt + Left-click): Pan the view
/// - Scroll wheel: Zoom in/out
/// - Shift + scroll: Fast zoom
/// - F key: Focus on target/reset view
/// </summary>
public class CameraController3D
{
    #region Constants
    
    // Distance limits
    public const float MinDistance = 2.0f;
    public const float MaxDistance = 200.0f;
    public const float DefaultDistance = 20.0f;
    
    // Angle limits
    public const float MinVerticalAngle = -89.0f;
    public const float MaxVerticalAngle = -5.0f;
    
    // Sensitivity settings
    public const float OrbitSensitivity = 0.3f;
    public const float PanSensitivity = 0.05f;
    public const float ZoomSensitivity = 2.0f;
    public const float FastZoomMultiplier = 3.0f;
    
    #endregion
    
    #region State
    
    private Camera3D? _camera;
    
    // Smoothing (0 = instant, higher = slower)
    private float _smoothingFactor = 0.0f;
    
    /// <summary>
    /// Smoothing factor for camera movement. 0 = instant, higher = slower.
    /// </summary>
    public float SmoothingFactor
    {
        get => _smoothingFactor;
        set => _smoothingFactor = Mathf.Max(0, value);
    }
    
    // Current camera state
    private Vector3 _target = Vector3.Zero;
    private float _distance = DefaultDistance;
    private float _horizontalAngle = 45.0f;  // Degrees, around Y axis
    private float _verticalAngle = -45.0f;   // Degrees, up/down from horizontal
    
    // Target state for smoothing (if enabled)
    private Vector3 _targetGoal = Vector3.Zero;
    private float _distanceGoal = DefaultDistance;
    private float _horizontalAngleGoal = 45.0f;
    private float _verticalAngleGoal = -45.0f;
    
    // Input state
    private bool _isOrbiting = false;
    private bool _isPanning = false;
    private Vector2 _lastMousePosition = Vector2.Zero;
    private bool _shiftHeld = false;
    private bool _altHeld = false;
    private bool _enabled = true;
    
    #endregion
    
    #region Properties
    
    /// <summary>Whether the controller is enabled.</summary>
    public bool Enabled
    {
        get => _enabled;
        set => _enabled = value;
    }
    
    /// <summary>The point the camera orbits around.</summary>
    public Vector3 Target
    {
        get => _targetGoal;
        set
        {
            _targetGoal = value;
            if (SmoothingFactor <= 0) _target = value;
        }
    }
    
    /// <summary>Distance from camera to target.</summary>
    public float Distance
    {
        get => _distanceGoal;
        set
        {
            _distanceGoal = Mathf.Clamp(value, MinDistance, MaxDistance);
            if (SmoothingFactor <= 0) _distance = _distanceGoal;
        }
    }
    
    /// <summary>Horizontal orbit angle in degrees.</summary>
    public float HorizontalAngle
    {
        get => _horizontalAngleGoal;
        set
        {
            _horizontalAngleGoal = value % 360f;
            if (SmoothingFactor <= 0) _horizontalAngle = _horizontalAngleGoal;
        }
    }
    
    /// <summary>Vertical orbit angle in degrees (negative = looking down).</summary>
    public float VerticalAngle
    {
        get => _verticalAngleGoal;
        set
        {
            _verticalAngleGoal = Mathf.Clamp(value, MinVerticalAngle, MaxVerticalAngle);
            if (SmoothingFactor <= 0) _verticalAngle = _verticalAngleGoal;
        }
    }
    
    /// <summary>Whether the camera is currently being manipulated.</summary>
    public bool IsActive => _isOrbiting || _isPanning;
    
    /// <summary>The camera being controlled.</summary>
    public Camera3D? Camera => _camera;
    
    #endregion
    
    #region Initialization
    
    /// <summary>
    /// Attaches this controller to a camera.
    /// </summary>
    public void AttachCamera(Camera3D camera)
    {
        _camera = camera;
        UpdateCameraPosition();
        BLLogger.Print("[CameraController3D] Camera attached");
    }
    
    /// <summary>
    /// Resets the camera to default view.
    /// </summary>
    public void Reset()
    {
        _target = Vector3.Zero;
        _targetGoal = Vector3.Zero;
        _distance = DefaultDistance;
        _distanceGoal = DefaultDistance;
        _horizontalAngle = 45.0f;
        _horizontalAngleGoal = 45.0f;
        _verticalAngle = -45.0f;
        _verticalAngleGoal = -45.0f;
        
        UpdateCameraPosition();
    }
    
    /// <summary>
    /// Focuses the camera on a specific position.
    /// </summary>
    public void FocusOn(Vector3 position, float? distance = null)
    {
        Target = position;
        if (distance.HasValue)
        {
            Distance = distance.Value;
        }
        UpdateCameraPosition();
    }
    
    /// <summary>
    /// Focuses the camera on a grid position (for map editors).
    /// </summary>
    public void FocusOnGrid(int gridX, int gridY, float tileSize = 1.0f, float height = 0.0f)
    {
        var worldPos = new Vector3(
            gridX * tileSize + tileSize / 2,
            height,
            gridY * tileSize + tileSize / 2
        );
        FocusOn(worldPos);
    }
    
    /// <summary>
    /// Centers on a map of given dimensions.
    /// </summary>
    public void CenterOnMap(int gridWidth, int gridHeight, float tileSize = 1.0f)
    {
        var center = new Vector3(
            gridWidth * tileSize / 2,
            0,
            gridHeight * tileSize / 2
        );
        
        // Calculate distance to see most of the map
        float mapDiagonal = Mathf.Sqrt(gridWidth * gridWidth + gridHeight * gridHeight) * tileSize;
        float optimalDistance = Mathf.Clamp(mapDiagonal * 0.6f, MinDistance, MaxDistance);
        
        FocusOn(center, optimalDistance);
    }
    
    #endregion
    
    #region Input Handling
    
    /// <summary>
    /// Handles input events for camera control.
    /// Call this from your GuiInput handler.
    /// Returns true if the event was consumed.
    /// </summary>
    public bool HandleInput(InputEvent @event)
    {
        if (!Enabled) return false;
        
        // Track modifier keys
        if (@event is InputEventKey keyEvent)
        {
            HandleKeyInput(keyEvent);
            return false; // Don't consume key events
        }
        
        if (@event is InputEventMouseButton mouseButton)
        {
            return HandleMouseButton(mouseButton);
        }
        
        if (@event is InputEventMouseMotion mouseMotion)
        {
            return HandleMouseMotion(mouseMotion);
        }
        
        return false;
    }
    
    private void HandleKeyInput(InputEventKey keyEvent)
    {
        // Track Shift key
        if (keyEvent.Keycode == Key.Shift)
        {
            _shiftHeld = keyEvent.Pressed;
        }
        
        // Track Alt key
        if (keyEvent.Keycode == Key.Alt)
        {
            _altHeld = keyEvent.Pressed;
        }
        
        // Focus key (F)
        if (keyEvent.Keycode == Key.F && keyEvent.Pressed && !keyEvent.Echo)
        {
            Reset();
        }
    }
    
    private bool HandleMouseButton(InputEventMouseButton @event)
    {
        switch (@event.ButtonIndex)
        {
            case MouseButton.Right:
                if (@event.Pressed)
                {
                    _isOrbiting = true;
                    _lastMousePosition = @event.Position;
                }
                else
                {
                    _isOrbiting = false;
                }
                return true;
                
            case MouseButton.Middle:
                if (@event.Pressed)
                {
                    _isPanning = true;
                    _lastMousePosition = @event.Position;
                }
                else
                {
                    _isPanning = false;
                }
                return true;
                
            case MouseButton.Left when _altHeld:
                // Alt + Left click = Pan (Unity style)
                if (@event.Pressed)
                {
                    _isPanning = true;
                    _lastMousePosition = @event.Position;
                }
                else
                {
                    _isPanning = false;
                }
                return true;
                
            case MouseButton.WheelUp:
                Zoom(-1, _shiftHeld);
                return true;
                
            case MouseButton.WheelDown:
                Zoom(1, _shiftHeld);
                return true;
        }
        
        return false;
    }
    
    private bool HandleMouseMotion(InputEventMouseMotion @event)
    {
        if (!_isOrbiting && !_isPanning)
            return false;
        
        Vector2 delta = @event.Position - _lastMousePosition;
        _lastMousePosition = @event.Position;
        
        if (_isOrbiting)
        {
            Orbit(delta);
            return true;
        }
        
        if (_isPanning)
        {
            Pan(delta);
            return true;
        }
        
        return false;
    }
    
    #endregion
    
    #region Camera Operations
    
    /// <summary>
    /// Orbits the camera around the target.
    /// </summary>
    public void Orbit(Vector2 delta)
    {
        HorizontalAngle += delta.X * OrbitSensitivity;
        VerticalAngle -= delta.Y * OrbitSensitivity;
        
        UpdateCameraPosition();
    }
    
    /// <summary>
    /// Pans the camera (moves the target).
    /// </summary>
    public void Pan(Vector2 delta)
    {
        if (_camera == null) return;
        
        // Calculate pan in camera's local space
        float panSpeed = PanSensitivity * _distance * 0.1f;
        
        // Get camera's right and up vectors for panning
        var cameraTransform = _camera.GlobalTransform;
        Vector3 right = -cameraTransform.Basis.X;
        Vector3 up = cameraTransform.Basis.Y;
        
        // Move target
        Vector3 panOffset = right * delta.X * panSpeed + up * delta.Y * panSpeed;
        Target += panOffset;
        
        UpdateCameraPosition();
    }
    
    /// <summary>
    /// Zooms the camera in or out.
    /// </summary>
    /// <param name="direction">Positive = zoom out, negative = zoom in</param>
    /// <param name="fast">Use fast zoom speed</param>
    public void Zoom(int direction, bool fast = false)
    {
        float zoomAmount = ZoomSensitivity;
        if (fast) zoomAmount *= FastZoomMultiplier;
        
        // Scale zoom by distance for consistent feel
        zoomAmount *= _distance * 0.1f;
        
        Distance += direction * zoomAmount;
        
        UpdateCameraPosition();
    }
    
    /// <summary>
    /// Sets the zoom level directly (for UI sliders, etc.)
    /// </summary>
    public void SetZoom(float distance)
    {
        Distance = distance;
        UpdateCameraPosition();
    }
    
    #endregion
    
    #region Camera Update
    
    /// <summary>
    /// Call this every frame to update smoothing (if enabled).
    /// </summary>
    public void Update(float delta)
    {
        if (SmoothingFactor <= 0) return;
        
        // Smooth interpolation
        float t = 1.0f - Mathf.Pow(SmoothingFactor, delta);
        
        _target = _target.Lerp(_targetGoal, t);
        _distance = Mathf.Lerp(_distance, _distanceGoal, t);
        _horizontalAngle = Mathf.LerpAngle(_horizontalAngle, _horizontalAngleGoal, t);
        _verticalAngle = Mathf.Lerp(_verticalAngle, _verticalAngleGoal, t);
        
        UpdateCameraPosition();
    }
    
    /// <summary>
    /// Updates the camera's position and orientation based on current state.
    /// </summary>
    public void UpdateCameraPosition()
    {
        if (_camera == null) return;
        
        // Convert angles to radians
        float hRad = Mathf.DegToRad(_horizontalAngle);
        float vRad = Mathf.DegToRad(_verticalAngle);
        
        // Calculate camera position on sphere around target
        // Note: In Godot, Y is up, Z is forward
        float cosV = Mathf.Cos(vRad);
        float sinV = Mathf.Sin(vRad);
        float cosH = Mathf.Cos(hRad);
        float sinH = Mathf.Sin(hRad);
        
        Vector3 offset = new Vector3(
            _distance * cosV * sinH,
            -_distance * sinV,  // Negative because our vertical angle is negative for looking down
            _distance * cosV * cosH
        );
        
        _camera.Position = _target + offset;
        _camera.LookAt(_target, Vector3.Up);
    }
    
    #endregion
    
    #region Utility
    
    /// <summary>
    /// Gets the world position under the mouse cursor.
    /// Useful for picking/selection.
    /// </summary>
    public Vector3? GetWorldPositionUnderMouse(Vector2 mousePos, float planeY = 0)
    {
        if (_camera == null) return null;
        
        // Get ray from camera
        var from = _camera.ProjectRayOrigin(mousePos);
        var direction = _camera.ProjectRayNormal(mousePos);
        
        // Intersect with horizontal plane at planeY
        if (Mathf.Abs(direction.Y) < 0.0001f)
            return null; // Ray is parallel to plane
        
        float t = (planeY - from.Y) / direction.Y;
        if (t < 0)
            return null; // Intersection is behind camera
        
        return from + direction * t;
    }
    
    /// <summary>
    /// Converts a world position to grid coordinates.
    /// </summary>
    public Vector2I WorldToGrid(Vector3 worldPos, float tileSize = 1.0f)
    {
        return new Vector2I(
            (int)Mathf.Floor(worldPos.X / tileSize),
            (int)Mathf.Floor(worldPos.Z / tileSize)
        );
    }
    
    /// <summary>
    /// Gets the grid position under the mouse cursor.
    /// </summary>
    public Vector2I? GetGridPositionUnderMouse(Vector2 mousePos, float tileSize = 1.0f, float planeY = 0)
    {
        var worldPos = GetWorldPositionUnderMouse(mousePos, planeY);
        if (!worldPos.HasValue) return null;
        
        return WorldToGrid(worldPos.Value, tileSize);
    }
    
    #endregion
}
