using Godot;
using System;
using System.Collections.Generic;

public partial class RaceHUD : CanvasLayer
{
    private Label countdownLabel;
    private Label raceHudLabel;
    private Dictionary<int, Label> playerLabels = new();
    private Dictionary<int, Node3D> activePlayers = new();
    private GameManager gameManager;

    public override void _Ready()
    {
        gameManager = GetNodeOrNull<GameManager>("../GameManager");
        countdownLabel = new Label { Name = "CountdownLabel" };
        countdownLabel.AnchorLeft = 0.5f;
        countdownLabel.AnchorTop = 0.5f;
        countdownLabel.OffsetLeft = -120;
        countdownLabel.OffsetTop = -60;
        countdownLabel.CustomMinimumSize = new Vector2(240, 120);
        countdownLabel.Text = "GET READY!";
        countdownLabel.AddThemeFontSizeOverride("font_sizes", 80);
        AddChild(countdownLabel);

        raceHudLabel = new Label { Name = "RaceHUDLabel" };
        raceHudLabel.AnchorLeft = 0.02f;
        raceHudLabel.AnchorTop = 0.02f;
        raceHudLabel.Text = "";
        raceHudLabel.AddThemeFontSizeOverride("font_sizes", 20);
        raceHudLabel.Visible = false;
        AddChild(raceHudLabel);

        if (gameManager != null)
            gameManager.RaceStateChanged += OnRaceStateChanged;
    }

    public override void _PhysicsProcess(double _delta)
    {
        if (gameManager != null && gameManager.GetRaceState() == GameManager.RaceState.RACING)
            UpdateRaceHudDisplay();
    }

    public void AddPlayer(int playerId, Node3D vehicle)
    {
        activePlayers[playerId] = vehicle;
    }

    public void RemovePlayer(int playerId)
    {
        if (activePlayers.ContainsKey(playerId))
            activePlayers.Remove(playerId);
        if (playerLabels.ContainsKey(playerId))
        {
            playerLabels[playerId].QueueFree();
            playerLabels.Remove(playerId);
        }
    }

    public void ShowWaiting()
    {
        countdownLabel.Text = "WAITING FOR PLAYERS";
        countdownLabel.Visible = true;
        raceHudLabel.Visible = false;
    }

    public void ShowCountdown(int remainingSeconds)
    {
        countdownLabel.Text = remainingSeconds > 0 ? remainingSeconds.ToString() : "GO!";
        countdownLabel.Visible = true;
        raceHudLabel.Visible = false;
    }

    public void UpdateCountdown(int remainingSeconds)
    {
        countdownLabel.Text = remainingSeconds > 0 ? remainingSeconds.ToString() : "GO!";
    }

    public void ShowRaceHud()
    {
        countdownLabel.Visible = false;
        raceHudLabel.Visible = true;
    }

    private void UpdateRaceHudDisplay()
    {
        string hudText = "=== RACE HUD ===\n";
        var playerIds = new List<int>(activePlayers.Keys);
        playerIds.Sort();
        foreach (var playerId in playerIds)
        {
            var playerData = gameManager.GetPlayerData(playerId);
            if (playerData.Count == 0)
                continue;
            int lap = (int)playerData.GetValueOrDefault("lap", 0);
            float raceTime = Convert.ToSingle(playerData.GetValueOrDefault("race_time", 0.0f));
            bool finished = Convert.ToBoolean(playerData.GetValueOrDefault("finished", false));
            string timeStr = FormatTime(raceTime);
            string status = $"Lap {lap + 1}";
            if (finished)
                status = $"FINISHED ({timeStr})";
            hudText += $"P{playerId + 1}: {status} [{timeStr}]\n";
        }
        raceHudLabel.Text = hudText;
    }

    public void UpdatePlayerLap(int playerId, int lap)
    {
        GD.Print($"Player {playerId} completed lap {lap}");
    }

    public void UpdatePlayerFinished(int playerId, int position)
    {
        GD.Print($"Player {playerId} finished in position {position}");
    }

    public void ShowResults(List<int> completionOrder, Dictionary<int, Dictionary<string, object>> allPlayers)
    {
        countdownLabel.Visible = false;
        raceHudLabel.Visible = true;
        raceHudLabel.AnchorLeft = 0.5f;
        raceHudLabel.AnchorTop = 0.5f;
        raceHudLabel.OffsetLeft = -300;
        raceHudLabel.OffsetTop = -200;
        raceHudLabel.CustomMinimumSize = new Vector2(600, 400);
        string resultsText = "=== RACE RESULTS ===\n\n";
        for (int i = 0; i < completionOrder.Count; i++)
        {
            int playerId = completionOrder[i];
            var playerData = allPlayers.GetValueOrDefault(playerId, new Dictionary<string, object>());
            string timeStr = FormatTime(Convert.ToSingle(playerData.GetValueOrDefault("finish_time", 0.0f)));
            string medal = "";
            switch (i)
            {
                case 0: medal = "🥇"; break;
                case 1: medal = "🥈"; break;
                case 2: medal = "🥉"; break;
            }
            resultsText += $"{i+1}. Player {playerId+1} - {timeStr} {medal}\n";
        }
        resultsText += "\n\nPress SPACE to return to menu";
        raceHudLabel.Text = resultsText;
    }

    private string FormatTime(float seconds)
    {
        int minutes = (int)seconds / 60;
        int secs = (int)seconds % 60;
        int ms = (int)((seconds - (int)seconds) * 100);
        return string.Format("{0:00}:{1:00}.{2:00}", minutes, secs, ms);
    }

    private void OnRaceStateChanged(GameManager.RaceState newState)
    {
        // can handle other logic if needed
    }
}
