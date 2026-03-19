
using Assets.LevelControllers;
using Assets.Levels.SpawnPatterns;
using Assets.World;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Serialization;
using TMPro;
using Unity.VisualScripting;
using Unity.VisualScripting.FullSerializer;
using UnityEngine;


public class CountByTensMap: StraitLineRacerMap
{
  
    public override GameObject SpawnTileAtIndex(int x, int y, int Segment)
    {
        if (TilePrefabs.Length == 0)
        {
            Debug.LogError("LabeledVerticalRoadSlicePrefabs is empty, cannot pick next vertical slice");
            return null;
        }

        float xOffset = x * RoadTileWidth;
        float yOffset = y * RoadTileHeight;
        float zOffset = Segment * RoadTileLength;
        GameObject RoadSegment = null;

        int VerticalSlabPrefix = UnityEngine.Random.Range(0, TilePrefabs.Length);
        RoadSegment = GameObject.Instantiate(TilePrefabs[VerticalSlabPrefix], this.transform);
        RoadSegment.transform.position = new Vector3(xOffset, yOffset, zOffset);

        if (Segment % 10 == 0 && Segment != 0)
        {
            var Tile = RoadSegment.GetComponent<RoadTile>();
            if (Tile != null)
            {
                Tile.TextValue = (Segment).ToString();
            }
        }
        else
        {
            AddHolidayItems(RoadSegment);
        }
        return RoadSegment;
    }
  
}