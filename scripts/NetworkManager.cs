using Godot;
using System;
using System.Collections.Generic;

public partial class NetworkManager : Node
{
    private MultiplayerAPI multiplayerAPI;

    [Signal] public delegate void PeerConnectedEventHandler(int peerId);
    [Signal] public delegate void PeerDisconnectedEventHandler(int peerId);
    [Signal] public delegate void ServerConnectedEventHandler();
    [Signal] public delegate void ServerDisconnectedEventHandler();

    public override void _Ready()
    {
        multiplayerAPI = GetMultiplayer();
        if (multiplayerAPI != null)
        {
            multiplayerAPI.ConnectedToServer += OnConnectedToServer;
            multiplayerAPI.PeerConnected += OnPeerConnected;
            multiplayerAPI.PeerDisconnected += OnPeerDisconnected;
            multiplayerAPI.ServerDisconnected += OnServerDisconnected;
        }
    }

    public bool StartServer(int port = 9999)
    {
        if (multiplayerAPI == null)
            return false;
        var peer = new ENetMultiplayerPeer();
        var err = peer.CreateServer(port, 8);
        if (err != Error.Ok)
        {
            GD.PushError($"Failed to create server: {err}");
            return false;
        }
        multiplayerAPI.MultiplayerPeer = peer;
        GD.Print($"Server started on port {port}");
        return true;
    }

    public bool StartClient(string address, int port = 9999)
    {
        if (multiplayerAPI == null)
            return false;
        var peer = new ENetMultiplayerPeer();
        var err = peer.CreateClient(address, port);
        if (err != Error.Ok)
        {
            GD.PushError($"Failed to connect to server: {err}");
            return false;
        }
        multiplayerAPI.MultiplayerPeer = peer;
        GD.Print($"Connecting to server at {address}:{port}");
        return true;
    }

    public bool IsServer() => multiplayerAPI != null && multiplayerAPI.IsServer();
    public bool IsClient() => multiplayerAPI != null && multiplayerAPI.IsClient();
    public int GetLocalPeerId() => multiplayerAPI != null ? multiplayerAPI.GetUniqueId() : -1;
    public Array<int> GetConnectedPeers() => multiplayerAPI != null ? multiplayerAPI.GetPeers() : new Array<int>();

    [RpcAnyPeer(Unreliable = true)]
    public void BroadcastInput(int playerId, Dictionary inputData) { }

    public void SyncPlayerInput(int playerId, Dictionary inputData)
    {
        if (multiplayerAPI == null || !IsServer())
            return;
        RpcId(MultiplayerPeer.TargetsRemote, nameof(BroadcastInput), playerId, inputData);
    }

    [RpcAnyPeer(Unreliable = true)]
    public void SyncVehicleTransform(int playerId, Vector3 position, Vector3 velocity, Quaternion rotation) { }

    public void SyncVehicleState(int playerId, Vector3 position, Vector3 velocity, Quaternion rotation)
    {
        if (multiplayerAPI == null)
            return;
        RpcId(MultiplayerPeer.TargetsRemote, nameof(SyncVehicleTransform), playerId, position, velocity, rotation);
    }

    [RpcAuthority(CallLocal = true)]
    public void UpdateRaceState(int newState)
    {
        var gm = GetNodeOrNull<GameManager>("/root/Main/GameManager");
        if (gm != null)
            gm.SetRaceState((GameManager.RaceState)newState);
    }

    private void OnConnectedToServer()
    {
        GD.Print("Connected to server");
        EmitSignal(nameof(ServerConnectedEventHandler));
    }

    private void OnPeerConnected(int peerId)
    {
        GD.Print($"Peer joined: {peerId}");
        EmitSignal(nameof(PeerConnectedEventHandler), peerId);
    }

    private void OnPeerDisconnected(int peerId)
    {
        GD.Print($"Peer left: {peerId}");
        EmitSignal(nameof(PeerDisconnectedEventHandler), peerId);
    }

    private void OnServerDisconnected()
    {
        GD.Print("Disconnected from server");
        EmitSignal(nameof(ServerDisconnectedEventHandler));
    }

    public void DisconnectPeer()
    {
        if (multiplayerAPI != null && multiplayerAPI.MultiplayerPeer != null)
        {
            multiplayerAPI.MultiplayerPeer.Close();
            multiplayerAPI.MultiplayerPeer = null;
        }
    }
}
