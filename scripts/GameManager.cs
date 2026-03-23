using Godot;
using System;
using System.Collections.Generic;

public partial class GameManager : Node
{
    public enum RaceState { WAITING, COUNTDOWN, RACING, FINISHED }

    public const int RACE_LAPS = 3;
    public const int COUNTDOWN_SECONDS = 3;
    public const int MAX_PLAYERS = 8;

    [Signal] public delegate void RaceStateChangedEventHandler(RaceState newState);
    [Signal] public delegate void PlayerLapCompletedEventHandler(int playerId, int lap, float time);
    [Signal] public delegate void RaceFinishedEventHandler();

    private RaceState currentState = RaceState.WAITING;
    private float countdownTimer = 0.0f;
    private float raceStartTime = 0.0f;

    // player_id -> data
    private Dictionary<int, Dictionary<string, object>> players = new();
    private List<int> playerCompletionOrder = new();

    private Node3D raceTrack;
    private Node raceHud;

    public override void _Ready()
    {
        raceTrack = GetNodeOrNull<Node3D>("../RaceTrack");
        raceHud = GetNodeOrNull<Node>("../RaceHUD");
        SetRaceState(RaceState.WAITING);
    }

    public override void _PhysicsProcess(double delta)
    {
        switch (currentState)
        {
            case RaceState.COUNTDOWN:
                UpdateCountdown((float)delta);
                break;
            case RaceState.RACING:
                UpdateRacing((float)delta);
                break;
        }
    }

    public void RegisterPlayer(int playerId, Node3D vehicle)
    {
        if (!players.ContainsKey(playerId))
        {
            players[playerId] = new Dictionary<string, object>
            {
                { "vehicle", vehicle },
                { "lap", 0 },
                { "sector", 0 },
                { "lap_times", new List<float>() },
                { "race_time", 0.0f },
                { "finished", false },
                { "finish_time", 0.0f }
            };
            GD.Print($"Player {playerId} registered");
            if (raceHud is RaceHUD hud)
                hud.AddPlayer(playerId, vehicle);
        }
    }

    public void UnregisterPlayer(int playerId)
    {
        if (players.ContainsKey(playerId))
        {
            players.Remove(playerId);
            if (raceHud is RaceHUD hud)
                hud.RemovePlayer(playerId);
        }
    }

    public void SetRaceState(RaceState newState)
    {
        if (newState == currentState)
            return;
        currentState = newState;
        switch (newState)
        {
            case RaceState.WAITING:
                OnWaitingStart();
                break;
            case RaceState.COUNTDOWN:
                OnCountdownStart();
                break;
            case RaceState.RACING:
                OnRacingStart();
                break;
            case RaceState.FINISHED:
                OnRaceFinished();
                break;
        }
        EmitSignal(nameof(RaceStateChangedEventHandler), newState);
    }

    public void StartCountdown()
    {
        if (currentState == RaceState.WAITING)
            SetRaceState(RaceState.COUNTDOWN);
    }

    private void OnWaitingStart()
    {
        countdownTimer = 0.0f;
        foreach (var data in players.Values)
        {
            if (data["vehicle"] is Vehicle v)
                v.StopRacing();
        }
        if (raceHud is RaceHUD hud)
            hud.ShowWaiting();
    }

    private void OnCountdownStart()
    {
        countdownTimer = COUNTDOWN_SECONDS;
        if (raceHud is RaceHUD hud)
            hud.ShowCountdown((int)countdownTimer);
    }

    private void UpdateCountdown(float delta)
    {
        countdownTimer -= delta;
        if (raceHud is RaceHUD hud)
            hud.UpdateCountdown((int)countdownTimer + 1);
        if (countdownTimer <= 0.0f)
            SetRaceState(RaceState.RACING);
    }

    private void OnRacingStart()
    {
        raceStartTime = OS.GetTicksMsec() / 1000.0f;
        foreach (var data in players.Values)
        {
            if (data["vehicle"] is Vehicle v)
                v.StartRacing();
        }
        if (raceHud is RaceHUD hud)
            hud.ShowRaceHud();
    }

    private void UpdateRacing(float delta)
    {
        float currentTime = OS.GetTicksMsec() / 1000.0f;
        foreach (var kv in players)
        {
            var data = kv.Value;
            if (!(bool)data["finished"])
                data["race_time"] = currentTime - raceStartTime;
        }
    }

    public void PlayerTriggeredCheckpoint(int playerId, int checkpointId)
    {
        if (!players.ContainsKey(playerId) || currentState != RaceState.RACING)
            return;
        var playerData = players[playerId];
        if (checkpointId == 0 && (int)playerData["sector"] > 0)
        {
            playerData["lap"] = (int)playerData["lap"] + 1;
            float lapTime = OS.GetTicksMsec() / 1000.0f - raceStartTime;
            var lapTimes = playerData["lap_times"] as List<float>;
            if (lapTimes.Count > 0)
                lapTime -= lapTimes[lapTimes.Count - 1];
            lapTimes.Add(lapTime);
            EmitSignal(nameof(PlayerLapCompletedEventHandler), playerId, (int)playerData["lap"], lapTime);
            if (raceHud is RaceHUD hud)
                hud.UpdatePlayerLap(playerId, (int)playerData["lap"]);
            if ((int)playerData["lap"] >= RACE_LAPS)
                FinishPlayer(playerId);
        }
        playerData["sector"] = checkpointId + 1;
    }

    private void FinishPlayer(int playerId)
    {
        var playerData = players[playerId];
        playerData["finished"] = true;
        playerData["finish_time"] = playerData["race_time"];
        playerCompletionOrder.Add(playerId);
        if (raceHud is RaceHud hud)
            hud.UpdatePlayerFinished(playerId, playerCompletionOrder.Count);
        bool allFinished = true;
        foreach (var data in players.Values)
            if (!(bool)data["finished"])
            {
                allFinished = false;
                break;
            }
        if (allFinished)
            SetRaceState(RaceState.FINISHED);
    }

    private void OnRaceFinished()
    {
        foreach (var data in players.Values)
        {
            if (data["vehicle"] is Vehicle v)
                v.StopRacing();
        }
        if (raceHud is RaceHUD hud)
            hud.ShowResults(playerCompletionOrder, players);
        EmitSignal(nameof(RaceFinishedEventHandler));
    }

    public Dictionary<string, object> GetPlayerData(int playerId)
    {
        return players.ContainsKey(playerId) ? players[playerId] : new Dictionary<string, object>();
    }

    /// <summary>Get the current race state as an integer.</summary>
    /// <returns>0=WAITING, 1=COUNTDOWN, 2=RACING, 3=FINISHED</returns>
    public int GetRaceState()
    {
        return (int)currentState;
    }

    public int GetPlayersCount()
    {
        return players.Count;
    }
}
