using Godot;
using System;
using System.Collections.Generic;

public partial class VehicleSpawner : Node3D
{
    [Export] public string VehicleScenePath { get; set; } = "res://scenes/vehicle_template.tscn";
    private string[] vehicleColors = { "yellow", "green", "purple", "red", "yellow", "green", "purple", "red" };
    private List<Node3D> spawnedVehicles = new();
    private GameManager gameManager;
    private RaceTrack raceTrack;

    public override void _Ready()
    {
        gameManager = GetNodeOrNull<GameManager>("../GameManager");
        raceTrack = GetNodeOrNull<RaceTrack>("../RaceTrack");
        SpawnAllVehicles();
    }

    public void SpawnAllVehicles()
    {
        for (int i = 0; i < 8; i++)
        {
            var v = SpawnVehicle(i);
            if (v != null)
                spawnedVehicles.Add(v);
        }
    }

    public Node3D SpawnVehicle(int vehicleIndex)
    {
        Node3D vehicle = new Node3D { Name = $"Vehicle_{vehicleIndex}" };
        vehicle.SetScript(GD.Load<CSharpScript>("res://scripts/Vehicle.cs"));
        var startTransform = raceTrack != null ? raceTrack.GetStartingPosition(vehicleIndex) : Transform3D.Identity;
        vehicle.GlobalTransform = startTransform;
        AddChild(vehicle);
        vehicle.SetDeferred("player_id", vehicleIndex);
        if (gameManager != null)
            gameManager.RegisterPlayer(vehicleIndex, vehicle);

        SetupVehicleStructure(vehicle, vehicleIndex);
        return vehicle;
    }

    private void SetupVehicleStructure(Node3D vehicle, int index)
    {
        var sphere = new RigidBody3D()
        {
            Name = "Sphere",
            CollisionLayer = 8,
            Mass = 1000.0f,
            GravityScale = 1.5f,
            LinearDamp = 0.1f,
            AngularDampMode = RigidBody3D.AngularDampModeEnum.FromAngularDamp,
            AngularDamp = 4.0f,
            ContinuousCd = true,
            ContactMonitor = true,
            MaxContactsReported = 1
        };
        var physicsMat = new PhysicsMaterial { Friction = 5.0f, Rough = true };
        sphere.PhysicsMaterialOverride = physicsMat;
        var colShape = new CollisionShape3D { Shape = new SphereShape3D { Radius = 0.5f } };
        sphere.AddChild(colShape);
        vehicle.AddChild(sphere);

        var raycast = new RayCast3D { Name = "Ground", TargetPosition = new Vector3(0, -0.7f, 0) };
        vehicle.AddChild(raycast);

        var container = new Node3D { Name = "Container" };
        vehicle.AddChild(container);

        var color = vehicleColors[index < vehicleColors.Length ? index : 0];
        var modelPath = GetVehicleModelPath(index);
        if (ResourceLoader.Exists(modelPath))
        {
            var modelScene = (PackedScene)ResourceLoader.Load(modelPath);
            var model = (Node3D)modelScene.Instantiate();
            container.AddChild(model);
        }

        var modelNode = new Node3D { Name = "Model" };
        container.AddChild(modelNode);
        var body = new Node3D { Name = "body" };
        modelNode.AddChild(body);
        modelNode.AddChild(new Node3D { Name = "wheel_front_left" });
        modelNode.AddChild(new Node3D { Name = "wheel_front_right" });
        modelNode.AddChild(new Node3D { Name = "wheel_back_left" });
        modelNode.AddChild(new Node3D { Name = "wheel_back_right" });

        var trailLeft = new GPUParticles3D { Name = "TrailLeft", Position = new Vector3(0.25f, 0.05f, -0.35f) };
        container.AddChild(trailLeft);
        var trailRight = new GPUParticles3D { Name = "TrailRight", Position = new Vector3(-0.25f, 0.05f, -0.35f) };
        container.AddChild(trailRight);

        var screechSound = new AudioStreamPlayer3D { Name = "ScreechSound" };
        if (ResourceLoader.Exists("res://audio/skid.ogg"))
            screechSound.Stream = ResourceLoader.Load<AudioStream>("res://audio/skid.ogg");
        screechSound.Bus = "Master";
        container.AddChild(screechSound);

        var engineSound = new AudioStreamPlayer3D { Name = "EngineSound" };
        if (ResourceLoader.Exists("res://audio/engine.ogg"))
            engineSound.Stream = ResourceLoader.Load<AudioStream>("res://audio/engine.ogg");
        engineSound.Bus = "Master";
        container.AddChild(engineSound);
    }

    private string GetVehicleModelPath(int index)
    {
        string color = vehicleColors[index < vehicleColors.Length ? index : 0];
        return $"res://models/vehicle-truck-{color}.glb";
    }

    public List<Node3D> GetSpawnedVehicles() => spawnedVehicles;

    public void ResetAllVehicles()
    {
        for (int i = 0; i < spawnedVehicles.Count; i++)
        {
            var vehicle = spawnedVehicles[i];
            if (vehicle is Vehicle v)
            {
                var startTransform = raceTrack != null ? raceTrack.GetStartingPosition(i) : Transform3D.Identity;
                v.SetStartingPosition(startTransform);
                v.ResetVehicle();
            }
        }
    }
}
