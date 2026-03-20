using Godot;
using System;
using System.Collections.Generic;

public partial class RaceTrack : Node3D
{
    private const string ContentLoaderPath = "res://scripts/reading/content_loader.gd";
    private const string TrackGeneratorPath = "res://scripts/reading/track_generator/TrackGenerator.gd";

    [Export] public string WordGroup { get; set; } = string.Empty;
    [Export] public int MaxWordEntries { get; set; } = 8;
    [Export] public int CheckpointCount { get; set; } = 4;
    [Export] public int StartSlotCount { get; set; } = 8;
    [Export] public float CellWorldLength { get; set; } = 8.0f;
    [Export] public float StartingHeight { get; set; } = 0.0f;
    [Export] public float CheckpointHeight { get; set; } = 1.0f;
    [Export] public float StartingLaneSpacing { get; set; } = 2.2f;
    [Export] public float StartingRowSpacing { get; set; } = 4.5f;

    public List<Transform3D> StartingPositions = new();

    public List<Node3D> Checkpoints = new();
    private GameManager gameManager;
    private Godot.Collections.Dictionary generatedLayout = new();

    public override void _Ready()
    {
        gameManager = GetNodeOrNull<GameManager>("../GameManager");
        BuildGeneratedTrackData();
        if (StartingPositions.Count == 0)
            StartingPositions = CreateDefaultStartingPositions();
        if (Checkpoints.Count == 0)
            CreateDefaultCheckpoints();
    }

    private void BuildGeneratedTrackData()
    {
        generatedLayout = GenerateLoopLayout();
        if (generatedLayout.Count == 0)
            return;

        StartingPositions = BuildStartingPositions(generatedLayout);
        RebuildCheckpoints(generatedLayout);
    }

    private Godot.Collections.Dictionary GenerateLoopLayout()
    {
        var loaderScript = GD.Load<Script>(ContentLoaderPath);
        var generatorScript = GD.Load<Script>(TrackGeneratorPath);
        if (loaderScript == null || generatorScript == null)
            return new Godot.Collections.Dictionary();

        var loader = loaderScript.Call("new") as GodotObject;
        var generator = generatorScript.Call("new") as GodotObject;
        if (loader == null || generator == null)
            return new Godot.Collections.Dictionary();

        var selectedGroup = ResolveWordGroup(loader);
        if (string.IsNullOrEmpty(selectedGroup))
            return new Godot.Collections.Dictionary();

        var entries = loader.Call("load_word_entries", selectedGroup).AsGodotArray();
        if (entries.Count == 0)
            return new Godot.Collections.Dictionary();

        var limitedEntries = new Godot.Collections.Array();
        var entryLimit = Mathf.Min(entries.Count, Mathf.Max(1, MaxWordEntries));
        for (int i = 0; i < entryLimit; i++)
            limitedEntries.Add(entries[i]);

        var config = new Godot.Collections.Dictionary
        {
            { "checkpoint_count", Mathf.Max(1, CheckpointCount) },
            { "start_slots", Mathf.Max(1, StartSlotCount) },
            { "cell_world_length", CellWorldLength }
        };

        var layout = generator.Call("generate_loop_layout", limitedEntries, config) as GodotObject;
        if (layout == null || !layout.HasMethod("to_dictionary"))
            return new Godot.Collections.Dictionary();

        return layout.Call("to_dictionary").AsGodotDictionary();
    }

    private string ResolveWordGroup(GodotObject loader)
    {
        if (!string.IsNullOrEmpty(WordGroup))
            return WordGroup;

        var groups = loader.Call("list_word_groups").AsGodotArray();
        if (groups.Count == 0)
            return string.Empty;

        return groups[0].AsString();
    }

    private List<Transform3D> BuildStartingPositions(Godot.Collections.Dictionary layout)
    {
        var startPositions = new List<Transform3D>();
        var layoutSize = layout["size"].AsVector3I();
        var startEntries = layout["start_positions"].AsGodotArray();
        for (int i = 0; i < startEntries.Count; i++)
        {
            var startEntry = startEntries[i].AsGodotDictionary();
            var cell = startEntry["cell"].AsVector3I();
            var rotationY = startEntry["rotation_y"].AsSingle();
            var basePosition = CellToWorldCenter(cell, layoutSize) + Vector3.Up * StartingHeight;
            var basis = Basis.FromEuler(new Vector3(0.0f, Mathf.DegToRad(rotationY), 0.0f));
            var right = basis.X.Normalized();
            var forward = basis.Z.Normalized();
            var laneOffset = ((i % 4) - 1.5f) * StartingLaneSpacing;
            var rowOffset = (i / 4) * StartingRowSpacing;
            var worldPosition = basePosition + right * laneOffset - forward * rowOffset;
            startPositions.Add(new Transform3D(basis, worldPosition));
        }

        return startPositions;
    }

    private void RebuildCheckpoints(Godot.Collections.Dictionary layout)
    {
        foreach (var checkpoint in Checkpoints)
        {
            if (IsInstanceValid(checkpoint))
                checkpoint.QueueFree();
        }

        Checkpoints.Clear();

        var layoutSize = layout["size"].AsVector3I();
        var checkpointEntries = layout["checkpoints"].AsGodotArray();
        for (int i = 0; i < checkpointEntries.Count; i++)
        {
            var checkpointEntry = checkpointEntries[i].AsGodotDictionary();
            var cell = checkpointEntry["cell"].AsVector3I();
            var rotationY = checkpointEntry["rotation_y"].AsSingle();
            var checkpoint = CreateCheckpointArea(i, CellToWorldCenter(cell, layoutSize), rotationY);
            AddChild(checkpoint);
            Checkpoints.Add(checkpoint);
        }
    }

    private Area3D CreateCheckpointArea(int checkpointIndex, Vector3 worldPosition, float rotationY)
    {
        var checkpoint = new Area3D();
        checkpoint.Name = $"Checkpoint_{checkpointIndex}";
        checkpoint.Position = worldPosition + Vector3.Up * CheckpointHeight;
        checkpoint.Rotation = new Vector3(0.0f, Mathf.DegToRad(rotationY), 0.0f);

        var shape = new CollisionShape3D();
        shape.Shape = new BoxShape3D
        {
            Size = new Vector3(CellWorldLength * 1.4f, 2.0f, CellWorldLength * 0.8f)
        };
        checkpoint.AddChild(shape);
        checkpoint.BodyEntered += (body) => OnCheckpointTriggered(body as Node3D, checkpointIndex);
        return checkpoint;
    }

    private Vector3 CellToWorldCenter(Vector3I cell, Vector3I layoutSize)
    {
        var origin = new Vector3(
            -layoutSize.X * CellWorldLength * 0.5f,
            0.0f,
            -layoutSize.Z * CellWorldLength * 0.5f
        );

        return origin + new Vector3(
            (cell.X + 0.5f) * CellWorldLength,
            0.0f,
            (cell.Z + 0.5f) * CellWorldLength
        );
    }

    private List<Transform3D> CreateDefaultStartingPositions()
    {
        return new List<Transform3D>
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
        for (int i = 0; i < positions.Count; i++)
        {
            var checkpoint = CreateCheckpointArea(i, positions[i], 0.0f);
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
