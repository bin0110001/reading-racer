
using Assets.LevelControllers;
using Assets.Levels.SpawnPatterns;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Unity.VisualScripting;
using UnityEngine;


public class MapTile : MonoBehaviour
{
    Vector3 dimensions;

    void Start()
    {
        // Calculate dimensions on Start
        Vector3 size = GetObjectDimensions(gameObject);
        dimensions = size;
    }

    public Vector3 GetObjectDimensions(GameObject obj)
    {
        // Check for a Renderer (MeshRenderer or SkinnedMeshRenderer)
        Renderer rend = obj.GetComponent<Renderer>();
        if (rend != null)
        {
            return rend.bounds.size; // x = width, y = height, z = length
        }

        // Fallback: Check for a Collider
        Collider col = obj.GetComponent<Collider>();
        if (col != null)
        {
            return col.bounds.size;
        }

        // No renderer or collider found
        Debug.LogWarning($"No Renderer or Collider found on {obj.name}.");
        return Vector3.zero;
    }
}