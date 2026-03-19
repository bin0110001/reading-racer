using System.Collections.Generic;
using UnityEngine;

public class Chunked3DGrid : MonoBehaviour
{
    public int chunkSize = 16;

    private Dictionary<Vector3Int, GameObject[,,]> Chunks = new Dictionary<Vector3Int, GameObject[,,]>();

    // Get or create a chunk at chunk coordinates
    private GameObject[,,] GetOrCreateChunk(Vector3Int chunkCoord)
    {
        if (!Chunks.TryGetValue(chunkCoord, out var chunk))
        {
            chunk = new GameObject[chunkSize, chunkSize, chunkSize];
            Chunks[chunkCoord] = chunk;
        }
        return chunk;
    }

    // Convert world coordinates to chunk/local coordinates
    private void WorldToChunkCoords(Vector3Int worldPos, out Vector3Int chunkCoord, out Vector3Int localPos)
    {
        chunkCoord = new Vector3Int(
            Mathf.FloorToInt((float)worldPos.x / chunkSize),
            Mathf.FloorToInt((float)worldPos.y / chunkSize),
            Mathf.FloorToInt((float)worldPos.z / chunkSize)
        );

        localPos = new Vector3Int(
            ((worldPos.x % chunkSize) + chunkSize) % chunkSize,
            ((worldPos.y % chunkSize) + chunkSize) % chunkSize,
            ((worldPos.z % chunkSize) + chunkSize) % chunkSize
        );
    }

    // Set a GameObject at a given position
    public void SetObject(Vector3Int worldPos, GameObject obj)
    {
        WorldToChunkCoords(worldPos, out Vector3Int chunkCoord, out Vector3Int localPos);
        var chunk = GetOrCreateChunk(chunkCoord);
        chunk[localPos.x, localPos.y, localPos.z] = obj;
    }

    // Get a GameObject at a given position
    public GameObject GetObject(Vector3Int worldPos)
    {
        WorldToChunkCoords(worldPos, out Vector3Int chunkCoord, out Vector3Int localPos);
        if (Chunks.TryGetValue(chunkCoord, out var chunk))
        {
            return chunk[localPos.x, localPos.y, localPos.z];
        }
        return null;
    }

    // Remove a GameObject at a given position
    public void RemoveObject(Vector3Int worldPos)
    {
        WorldToChunkCoords(worldPos, out Vector3Int chunkCoord, out Vector3Int localPos);
        if (Chunks.TryGetValue(chunkCoord, out var chunk))
        {
            chunk[localPos.x, localPos.y, localPos.z] = null;
        }
    }
}