
using Assets.LevelControllers;
using Assets.Levels.SpawnPatterns;
using Assets.Scripts.Levels;
using Assets.World;
using NUnit;
using NUnit.Framework;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Serialization;
using Unity.VisualScripting;
using Unity.VisualScripting.FullSerializer;
using UnityEngine;
using UnityEngine.Analytics;


public class StraitLineRacerMap: MonoBehaviour
{
    [Header("Values That Need To Be Set")]
    public float RoadTileLength = 5;
    public float RoadTileWidth = 5;
    public float RoadTileHeight = 5;

    public (int, int, int) CurrentPlayerPosition;

    public (int, int) xOffsetTiles = (0, 1);
    public (int, int) yOffsetTiles = (0, 1);
    public (int, int) zOffsetTiles = (3, 11);

    public (int, int) xLimits = (0, 1);
    public (int, int) yLimits = (0, 1);
    public (int, int) zLimits = (0, 5);

    public int totalLanes = 3;
    public float[] LaneCenters;

    public SpawnMarker[] SpawnMarkers;
    public GameObject[] StartingTiles;
    public GameObject[] EndingTiles;

    public Chunked3DGrid ChunkedGrid = new Chunked3DGrid();
    public GameObject[] TilePrefabs;

    public Camera LevelCamera;
    public int HolidayItemPercentChance = 10;

    public Vector3 RacerStartPosition;
    private GameObject _PlayerRacer;
    List<HolidayItem> HolidayItems = null;
    public GameObject PlayerRacer
    {
        get { return _PlayerRacer; }
        set
        {
            _PlayerRacer = value;
            if (_PlayerRacer != null)
            {
                RacerStartPosition = _PlayerRacer.transform.position;
            }
        }
    }
    private WorldController _WorldController;
    public WorldController WorldController
    {
        get
        {
            if (_WorldController == null || !_WorldController.IsDestroyed())
            {
                _WorldController = FindFirstObjectByType<WorldController>();
            }
            return _WorldController;
        }
        set
        {
            _WorldController = value;
        }
    }
    private HolidayHandler _HolidayHandler = null;
    protected HolidayHandler HolidayHandler
    {
        get
        {
            if (_HolidayHandler == null)
            {
                _HolidayHandler = GameObject.FindFirstObjectByType<HolidayHandler>();
                if (_HolidayHandler == null)
                {
                    Debug.LogError("HolidayHandler not found in scene, please add it to the scene.");
                    return null;
                }
            }
            return _HolidayHandler;
        }
    }
    public Assets.Scripts.Levels.HolidayPack pack = null;
    public void MapInitialize(GameObject[] TilePrefabs, 
        GameObject[] StartingTiles,
        GameObject[] EndingTiles,
        int xMin = 0,
        int xMax = 1,
        int yMin = 0,
        int yMax = 1,
        int zMin = 1,
        int zMax = 5)
    {
        xLimits = (xMin, xMax);
        yLimits = (yMin, yMax);
        zLimits = (zMin, zMax);

        this.TilePrefabs = TilePrefabs;
        this.StartingTiles = StartingTiles;
        this.EndingTiles = EndingTiles;
        /*
        GameObject StartingTile = null;
        var StarterIndex = UnityEngine.Random.Range(0, StartingTiles.Length);
        StartingTile = StartingTiles[StarterIndex];
        ChunkedGrid.SetObject(new Vector3Int(0, 0, 0),
            GameObject.Instantiate(StartingTile, this.transform));*/
        BuildHolidayItemList();
        SpawnStartAndEnd();

        LevelCamera = this.gameObject.GetComponentInChildren<Camera>();
        WorldController.SetLevelCamera(LevelCamera);

        SpawnMarkers = this.GetComponentsInChildren<SpawnMarker>();
        totalLanes = SpawnMarkers.Length;

        LaneCenters = new float[totalLanes];
        for (int i = 0; i < SpawnMarkers.Count(); i++)
        {
            LaneCenters[i] = SpawnMarkers[i].transform.position.x;
        }
    }
    private void BuildHolidayItemList()
    {
        pack = HolidayHandler.GetHolidayPack();
        HolidayItems = new List<HolidayItem>();

        if (pack == null)
        {
            //If we didn't find a pack, it should mean there is no active Holiday.
            return;
        }
        if (this.pack.SmallHolidayItem != null && this.pack.SmallHolidayItem.Count > 0)
        {
            HolidayItems.AddRange(this.pack.SmallHolidayItem);
        }
        if (this.pack.MediumHolidayItem != null && this.pack.MediumHolidayItem.Count > 0)
        {
            HolidayItems.AddRange(this.pack.MediumHolidayItem);
        }
    }


    private bool InitialLoadCompleted = false;
    public void Update()
    {
        var CalculatedPostion = CalculatePosition();
        if (CalculatedPostion == CurrentPlayerPosition && InitialLoadCompleted)
        {
            return;
        }
        CheckWichTilesShouldBeVisible();
        InitialLoadCompleted = true;
    }
    public (int, int, int) CalculatePosition()
    {
        int CurrentSegmentsForward = 0;
        if (PlayerRacer == null)
        {
            //This will be called when the map is initialized, but the player racer is not set yet.
            return (0, 0, 0);
        }
        CurrentSegmentsForward = (int)((PlayerRacer.transform.position.z - RacerStartPosition.z)
            / RoadTileLength);

        return (0, 0, CurrentSegmentsForward);
    }
    public void CheckWichTilesShouldBeVisible()
    {
        // This method can be used to check which tiles should be visible based on the racer's position
        // For example, you can enable or disable road slices based on the racer's current position

        var CalculatedPostion = CalculatePosition();
        Dictionary<(int, int, int), GameObject> ExistingTilesThatWillNeedToBeRemoved = new Dictionary<(int, int, int), GameObject>();
        //Find all Currently existingTiles.
        int xStart = Mathf.Max(CurrentPlayerPosition.Item1 - xOffsetTiles.Item1, xLimits.Item1);
        int xEnd = Mathf.Min(CurrentPlayerPosition.Item1 + xOffsetTiles.Item2, xLimits.Item2);
        int yStart = Mathf.Max(CurrentPlayerPosition.Item2 - yOffsetTiles.Item1, yLimits.Item1);
        int yEnd = Mathf.Min(CurrentPlayerPosition.Item2 + yOffsetTiles.Item2, yLimits.Item2);
        int zStart = Mathf.Max(CurrentPlayerPosition.Item3 - zOffsetTiles.Item1, zLimits.Item1);
        int zEnd = Mathf.Min(CurrentPlayerPosition.Item3 + zOffsetTiles.Item2, zLimits.Item2);


        for (int i = xStart; i < xEnd; i++)
        {
            for (int j = yStart; j < yEnd; j++)
            {
                for (int k = zStart; k < zEnd; k++)
                {
                    //Make sure this tile is loaded
                    var ExistingObject = ChunkedGrid.GetObject(new Vector3Int(i, j, k));
                    if (ExistingObject != null)
                    {
                        ExistingTilesThatWillNeedToBeRemoved[(i, j, k)] = ExistingObject;
                    }
                }
            }
        }
        xStart = Mathf.Max(CalculatedPostion.Item1 - xOffsetTiles.Item1, xLimits.Item1);
        xEnd = Mathf.Min(CalculatedPostion.Item1 + xOffsetTiles.Item2, xLimits.Item2);
        yStart = Mathf.Max(CalculatedPostion.Item2 - yOffsetTiles.Item1, yLimits.Item1);
        yEnd = Mathf.Min(CalculatedPostion.Item2 + yOffsetTiles.Item2, yLimits.Item2);
        zStart = Mathf.Max(CalculatedPostion.Item3 - zOffsetTiles.Item1, zLimits.Item1);
        zEnd = Mathf.Min(CalculatedPostion.Item3 + zOffsetTiles.Item2, zLimits.Item2);
        //Check for the tiles we want to have.
        for (int i = xStart; i < xEnd; i++)
        {
            for (int j = yStart; j < yEnd; j++)
            {
                for (int k = zStart; k < zEnd; k++)
                {
                    //Debug.Log("Checking Tile at: " + i + ", " + j + ", " + k);

                    if (ExistingTilesThatWillNeedToBeRemoved.ContainsKey((i, j, k)))
                    {
                        //This tile already exists, so we can skip it.
                        ExistingTilesThatWillNeedToBeRemoved.Remove((i, j, k));
                        //Debug.Log("Tile exists.");
                    }


                    if (ChunkedGrid.GetObject(new Vector3Int(i, j, k)) != null)
                    {
                        //This tile already exists, so we can skip it.
                        //Debug.Log("Tile already exists at: " + i + ", " + j + ", " + k);
                        continue;
                    }
                    else
                    {
                        //This tile does not exist, so we need to create it.
                        //Debug.Log("Creating Tile");
                        var VerticalSlice = SpawnTileAtIndex(i, j, k);
                        if(VerticalSlice == null)
                        {
                            continue;
                        }
                        TileSpawned?.Invoke(i, j, k, VerticalSlice);
                        ChunkedGrid.SetObject(new Vector3Int(i, j, k), VerticalSlice);
                    }

                }
            }
        }
        foreach(var key in ExistingTilesThatWillNeedToBeRemoved.Keys)
        {
            //Debug.Log(SpawnTileAtIndex(key.Item1, key.Item2, key.Item3));
            var tile = ExistingTilesThatWillNeedToBeRemoved[key];
            //ChunkedGrid.RemoveObject(new Vector3Int(key.Item1, key.Item2, key.Item3));
            Destroy(tile);
        }

        //Once everything is done, we can update the current player position
        CurrentPlayerPosition = CalculatedPostion;
        //Once we have added/removed tiles, call any external methods depending on this. 
        TileChanged?.Invoke(CurrentPlayerPosition.Item1, CurrentPlayerPosition.Item2, CurrentPlayerPosition.Item3);

    }
    public virtual GameObject SpawnTileAtIndex(int x, int y, int z)
    {
        //Debug.Log("SpawnTileAtIndex - x: " + x + ", y: " + y + ", z: " + z);
        if (TilePrefabs == null || TilePrefabs.Length == 0)
            return null;
        int VerticalSlabPrefix = UnityEngine.Random.Range(0, TilePrefabs.Length);
        float xOffset = x * RoadTileWidth;
        float yOffset = y * RoadTileHeight;
        float zOffset = z * RoadTileLength;

        GameObject RoadSegment = GameObject.Instantiate(TilePrefabs[VerticalSlabPrefix],
            this.transform);
        AddHolidayItems(RoadSegment);

        RoadSegment.transform.position = new Vector3(xOffset, yOffset, zOffset);
        return RoadSegment;
    }

    protected void AddHolidayItems(GameObject RoadSegment)
    {
        Debug.Log("Adding Holiday Item");
        var PlacementMarkers = RoadSegment.GetComponentsInChildren<PlacementMarker>();
        if (HolidayItems == null || HolidayItems.Count == 0)
        {
            Debug.Log("No Holiday Items found.");
            return;
        }
        if (PlacementMarkers == null)
        {
            return;
        }
        foreach (var PlacementMarker in PlacementMarkers)
        {
            if (UnityEngine.Random.Range(0, 100) > HolidayItemPercentChance)
            {
                continue;
            }
            Debug.Log("Holiday Items Count: " + HolidayItems.Count);
            var item = HolidayItems[UnityEngine.Random.Range(0, HolidayItems.Count)];
            var HolidayInstance = GameObject.Instantiate(item.Item, PlacementMarker.transform);
            HolidayInstance.transform.localPosition = item.HolidayItemOffset;
            HolidayInstance.transform.localScale = pack.DefaultScale * Vector3.one;
        }
    }
    public void SpawnStartAndEnd()
    {
        if(this.StartingTiles == null || this.StartingTiles.Length == 0)
        {
            Debug.LogError("StartingTiles is null or empty, cannot spawn start tile");
            return;
        }
        if(this.EndingTiles == null || this.EndingTiles.Length == 0)
        {
            Debug.LogError("EndingTiles is null or empty, cannot spawn end tile");
            return;
        }


        int StartIndex = UnityEngine.Random.Range(0, this.StartingTiles.Length);
        GameObject start = GameObject.Instantiate(this.StartingTiles[StartIndex], this.transform);


        int EndIndex = UnityEngine.Random.Range(0, this.EndingTiles.Length);
        GameObject end = GameObject.Instantiate(this.EndingTiles[EndIndex], this.transform);
        float offset = zLimits.Item2 * RoadTileWidth;
        //Debug.Log("Spawning End at offset: " + offset);
        end.transform.position = new Vector3(0, 0, offset);
    }
    public event Action<int, int, int> TileChanged;

    public event Action<int, int, int, GameObject> TileSpawned;


}