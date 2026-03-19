using Godot;
using System;

public partial class RaceController : Node
{
    private GameManager gameManager;
    private VehicleSpawner vehicleSpawner;
    private RaceTrack raceTrack;

    public override void _Ready()
    {
        gameManager = GetNodeOrNull<GameManager>("../GameManager");
        vehicleSpawner = GetNodeOrNull<VehicleSpawner>("../VehicleSpawner");
        raceTrack = GetNodeOrNull<RaceTrack>("../RaceTrack");
        await ToSignal(GetTree(), "process_frame");
        InitializeRace();
    }

    public override void _PhysicsProcess(double _delta)
    {
        if (Input.IsActionJustPressed("bounce"))
        {
            switch (gameManager.GetRaceState())
            {
                case GameManager.RaceState.WAITING:
                    gameManager.StartCountdown();
                    break;
                case GameManager.RaceState.FINISHED:
                    RestartRace();
                    break;
            }
        }
    }

    private void InitializeRace()
    {
        GD.Print($"Race initialized with {gameManager.GetPlayersCount()} players");
    }

    private void RestartRace()
    {
        if (vehicleSpawner != null)
            vehicleSpawner.ResetAllVehicles();
        if (gameManager != null)
            gameManager.SetRaceState(GameManager.RaceState.WAITING);
    }
}
