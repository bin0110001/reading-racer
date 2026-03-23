using Godot;
using System;

public partial class Vehicle : Node3D
{
    [Export] public int player_id { get; set; } = 0;
    private GameManager gameManager;
    private RaceTrack raceTrack;

    // Nodes
    private RigidBody3D sphere;
    private RayCast3D raycast;

    // Vehicle elements
    private Node3D vehicleModel;
    private Node3D vehicleBody;

    private Node3D wheelFL;
    private Node3D wheelFR;
    private Node3D wheelBL;
    private Node3D wheelBR;

    // Effects
    private GPUParticles3D trailLeft;
    private GPUParticles3D trailRight;

    // Sounds
    private AudioStreamPlayer3D screechSound;
    private AudioStreamPlayer3D engineSound;

    private Vector3 input = Vector3.Zero;
    private Vector3 normal = Vector3.Up;

    private float acceleration;
    private float angularSpeed;
    private float linearSpeed;

    private bool colliding;

    public override void _Ready()
    {
        // register with game manager
        gameManager = GetNodeOrNull<GameManager>("/root/Main/GameManager");
        raceTrack = GetNodeOrNull<RaceTrack>("/root/Main/RaceTrack");
        SetMeta("player_id", player_id);
        if (gameManager != null)
            gameManager.RegisterPlayer(player_id, this);
        SetPhysicsProcess(false);

        sphere = GetNode<RigidBody3D>("Sphere");
        raycast = GetNode<RayCast3D>("Ground");

        vehicleModel = GetNode<Node3D>("Container");
        vehicleBody = GetNode<Node3D>("Container/Model/body");

        wheelFL = GetNode<Node3D>("Container/Model/wheel-front-left");
        wheelFR = GetNode<Node3D>("Container/Model/wheel-front-right");
        wheelBL = GetNode<Node3D>("Container/Model/wheel-back-left");
        wheelBR = GetNode<Node3D>("Container/Model/wheel-back-right");

        trailLeft = GetNode<GPUParticles3D>("Container/TrailLeft");
        trailRight = GetNode<GPUParticles3D>("Container/TrailRight");

        screechSound = GetNode<AudioStreamPlayer3D>("Container/ScreechSound");
        engineSound = GetNode<AudioStreamPlayer3D>("Container/EngineSound");

        // Freeze physics until race starts
        sphere.Disabled = true;
        sphere.GravityScale = 0.0f;
        sphere.LinearVelocity = Vector3.Zero;
        sphere.AngularVelocity = Vector3.Zero;
    }

    public override void _PhysicsProcess(double delta)
    {
        HandleInput((float)delta);

        float direction = Mathf.Sign(linearSpeed);
        if (direction == 0)
        {
            direction = Mathf.Sign(input.Z);
            if (Mathf.Abs(input.Z) <= 0.1f)
                direction = 1;
        }

        float steeringGrip = Mathf.Clamp(Mathf.Abs(linearSpeed), 0.2f, 1.0f);

        float targetAngular = -input.X * steeringGrip * 4f * direction;
        angularSpeed = Mathf.Lerp(angularSpeed, targetAngular, (float)delta * 4f);

        vehicleModel.RotateY(angularSpeed * (float)delta);

        // Ground alignment
        if (raycast.IsColliding())
        {
            if (!colliding)
            {
                vehicleBody.Position = new Vector3(0, 0.1f, 0); // Bounce
                input.Z = 0;
            }

            normal = raycast.GetCollisionNormal();

            // Orient model to colliding normal
            if (normal.Dot(vehicleModel.GlobalBasis.Y) > 0.5f)
            {
                Transform3D xform = AlignWithY(vehicleModel.GlobalTransform, normal);
                vehicleModel.GlobalTransform = vehicleModel.GlobalTransform.InterpolateWith(xform, 0.2f).Orthonormalized();
            }
        }

        colliding = raycast.IsColliding();

        float targetSpeed = input.Z;

        if (targetSpeed < 0 && linearSpeed > 0.01f)
        {
            linearSpeed = Mathf.Lerp(linearSpeed, 0.0f, (float)delta * 8f);
        }
        else
        {
            if (targetSpeed < 0)
            {
                linearSpeed = Mathf.Lerp(linearSpeed, targetSpeed / 2f, (float)delta * 2f);
            }
            else
            {
                linearSpeed = Mathf.Lerp(linearSpeed, targetSpeed, (float)delta * 6f);
            }
        }

        acceleration = Mathf.Lerp(acceleration, linearSpeed + (Mathf.Abs(sphere.AngularVelocity.Length() * linearSpeed) / 100f), (float)delta * 1f);

        // Match vehicle model to physics sphere
        vehicleModel.Position = sphere.Position - new Vector3(0, 0.65f, 0);
        raycast.Position = sphere.Position;

        // Visual and audio effects
        EffectEngine((float)delta);
        EffectBody((float)delta);
        EffectWheels((float)delta);
        EffectTrails();
    }

    private void HandleInput(float delta)
    {
        if (raycast.IsColliding())
        {
            // X axis uses left/right, Z axis uses back/forward
            input.X = Input.GetAxis("left", "right");
            input.Z = Input.GetAxis("back", "forward");
        }

        // Use vehicle forward vector from the model's true local forward (-Z in Godot space).
        // Forward to world is -Basis.Z for models oriented with nose pointing to -Z.
        Vector3 forward = -vehicleModel.GlobalTransform.Basis.Z;
        Vector3 torqueAxis = forward.Cross(Vector3.Up).Normalized();

        sphere.AngularVelocity += torqueAxis * (linearSpeed * 100f) * delta;
    }

    private void EffectBody(float delta)
    {
        vehicleBody.Rotation = new Vector3(
            Mathf.LerpAngle(vehicleBody.Rotation.x, -(linearSpeed - acceleration) / 6f, delta * 10f),
            vehicleBody.Rotation.y,
            Mathf.LerpAngle(vehicleBody.Rotation.z, -input.X / 5f * linearSpeed, delta * 5f)
        );

        vehicleBody.Position = vehicleBody.Position.Lerp(new Vector3(0, 0.2f, 0), delta * 5f);
    }

    private void EffectWheels(float delta)
    {
        foreach (var wheel in new[] { wheelFL, wheelFR, wheelBL, wheelBR })
        {
            wheel.Rotation = new Vector3(wheel.Rotation.x + acceleration, wheel.Rotation.y, wheel.Rotation.z);
        }

        wheelFL.Rotation = new Vector3(
            wheelFL.Rotation.x,
            Mathf.LerpAngle(wheelFL.Rotation.y, -input.X / 1.5f, delta * 10f),
            wheelFL.Rotation.z
        );

        wheelFR.Rotation = new Vector3(
            wheelFR.Rotation.x,
            Mathf.LerpAngle(wheelFR.Rotation.y, -input.X / 1.5f, delta * 10f),
            wheelFR.Rotation.z
        );
    }

    private void EffectEngine(float delta)
    {
        float speedFactor = Mathf.Clamp(Mathf.Abs(linearSpeed), 0.0f, 1.0f);
        float throttleFactor = Mathf.Clamp(Mathf.Abs(input.Z), 0.0f, 1.0f);

        float targetVolume = Remap(speedFactor + (throttleFactor * 0.5f), 0.0f, 1.5f, -15.0f, -5.0f);
        engineSound.VolumeDb = Mathf.Lerp(engineSound.VolumeDb, targetVolume, delta * 5.0f);

        float targetPitch = Remap(speedFactor, 0.0f, 1.0f, 0.5f, 3f);
        if (throttleFactor > 0.1f) targetPitch += 0.2f;

        engineSound.PitchScale = Mathf.Lerp(engineSound.PitchScale, targetPitch, delta * 2.0f);
    }

    private void EffectTrails()
    {
        float driftIntensity = Mathf.Abs(linearSpeed - acceleration) + (Mathf.Abs(vehicleBody.Rotation.z) * 2.0f);
        bool shouldEmit = driftIntensity > 0.25f;

        trailLeft.Emitting = shouldEmit;
        trailRight.Emitting = shouldEmit;

        float targetVolume = -80.0f;
        if (shouldEmit)
            targetVolume = Remap(Mathf.Clamp(driftIntensity, 0.25f, 2.0f), 0.25f, 2.0f, -10.0f, 0.0f);

        screechSound.PitchScale = Mathf.Lerp(screechSound.PitchScale, Mathf.Clamp(Mathf.Abs(linearSpeed), 1.0f, 3.0f), 0.1f);
        screechSound.VolumeDb = Mathf.Lerp(screechSound.VolumeDb, targetVolume, 10.0f * (float)GetPhysicsProcessDeltaTime());
    }

    private Transform3D AlignWithY(Transform3D xform, Vector3 newY)
    {
        xform.basis.y = newY;
        xform.basis.x = -xform.basis.z.Cross(newY);
        xform.basis = xform.basis.Orthonormalized();
        return xform;
    }

    private float Remap(float value, float from1, float to1, float from2, float to2)
    {
        return (value - from1) / (to1 - from1) * (to2 - from2) + from2;
    }

    public void StartRacing()
    {
        sphere.Mode = RigidBody3D.ModeEnum.Rigid;
        sphere.Disabled = false;
        sphere.GravityScale = 1.0f;
        SetPhysicsProcess(true);
    }

    public void StopRacing()
    {
        sphere.Disabled = true;
        sphere.GravityScale = 0.0f;
        SetPhysicsProcess(false);
        // Reset velocities
        sphere.LinearVelocity = Vector3.Zero;
        sphere.AngularVelocity = Vector3.Zero;
        input = Vector3.Zero;
        linearSpeed = 0.0f;
        angularSpeed = 0.0f;
        acceleration = 0.0f;
    }

    public void SetStartingPosition(Transform3D transform)
    {
        GlobalTransform = transform;
        sphere.Position = transform.Origin;
        vehicleModel.GlobalTransform = transform;
    }

    public void ResetVehicle()
    {
        StopRacing();
        // Reset to starting position
        if (raceTrack != null)
        {
            var startTransform = raceTrack.GetStartingPosition(player_id);
            SetStartingPosition(startTransform);
        }
    }
}
