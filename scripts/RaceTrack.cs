using Godot;
using System;
using System.Collections.Generic;

public partial class RaceTrack : Node3D
{
    public List<Transform3D> StartingPositions = new()
    {
        new Transform3D(Basis.Identity, new Vector3(3.5f, 0, 5)),
        new Transform3D(Basis.Identity, new Vector3(5.0f, 0, 5)),
        new Transform3D(Basis.Identity, new Vector3(2.0f, 0, 5)),
        new Transform3D(Basis.Identity, new Vector3(0.5f, 0, 5)),
        new Transform3D(Basis.Identity, new Vector3(3.5f, 0, 7)),
        new Transform3D(Basis.Identity, new Vector3(5.0f, 0, 7)),
        new Transform3D(Basis.Identity, new Vector3(2.0f, 0, 7)),
        new Transform3D(Basis.Identity, new Vector3(0.5f, 0, 7))
    };

    public List<Node3D> Checkpoints = new();
    private GameManager gameManager;

    public override void _Ready()
    {
        gameManager = GetNodeOrNull<GameManager>("../GameManager");
        if (Checkpoints.Count == 0)
            CreateDefaultCheckpoints();
        for (int i = 0; i < Checkpoints.Count; i++)
        {
            if (Checkpoints[i] is Area3D area)
                area.BodyEntered += (body) => OnCheckpointTriggered(body as Node3D, i);
        }
    }

    private void CreateDefaultCheckpoints()
    {
        var positions = new List<Vector3>
        {
            new Vector3(3.5f, 1, 5),
            new Vector3(15, 1, 5),
            new Vector3(15, 1, -15),
            new Vector3(-15, 1, -15)
        };
        foreach (var pos in positions)
        {
            var checkpoint = new Area3D();
            checkpoint.Name = $"Checkpoint_{Checkpoints.Count}";
            checkpoint.Position = pos;
            var shape = new CollisionShape3D();
            var box = new BoxShape3D { Size = new Vector3(8, 2, 8) };
            shape.Shape = box;
            checkpoint.AddChild(shape);
            AddChild(checkpoint);
            Checkpoints.Add(checkpoint);
        }
    }

    private void OnCheckpointTriggered(Node3D body, int checkpointIndex)
    {
        if (body == null || gameManager == null)
            return;
        if (body.HasMeta("player_id"))
        {
            int playerId = (int)body.GetMeta("player_id");
            gameManager.PlayerTriggeredCheckpoint(playerId, checkpointIndex);
        }
        else if (body.HasMethod("GetPlayerId"))
        {
            var playerId = (int)body.Call("GetPlayerId");
            gameManager.PlayerTriggeredCheckpoint(playerId, checkpointIndex);
        }
    }

    public Transform3D GetStartingPosition(int vehicleIndex)
    {
        if (vehicleIndex < StartingPositions.Count)
            return StartingPositions[vehicleIndex];
        return StartingPositions[0];
    }

    public List<Transform3D> GetAllStartingPositions()
    {
        return StartingPositions;
    }

    public void SetStartingPosition(int index, Transform3D transform)
    {
        if (index < StartingPositions.Count)
            StartingPositions[index] = transform;
    }
}
