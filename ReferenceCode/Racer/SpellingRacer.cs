using Assets.ArtificersVaultCommon.Language;
using Assets.LevelControllers;
using Assets.Levels.SpawnPatterns;
using Assets.Movements;
using Assets.Scripts;
using Assets.UIElements;
using CartoonFX;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;
using Unity.VisualScripting;
using Unity.VisualScripting.Antlr3.Runtime;
using UnityEngine;
using UnityEngine.AI;
using UnityEngine.Experimental.Playables;
using static CartoonFX.CFXR_ParticleTextFontAsset;



[LevelControllerAttribute(typeof(SpellingRacerConfig))]
public class SpellingRacer : RacerController
{
    protected SpellingRacerConfig SpellingTypedConfig;

    int NumberOfTilesWide = 10; // Number of road slices wide

    public WordEntry ChosenWord;
    public StraitLineRacer PlayerRacer;

    private LanguageHandler _LanguageHandler;
    public LanguageHandler LanguageHandler
    {
        get
        {
            if (_LanguageHandler == null)
            {
                _LanguageHandler = FindFirstObjectByType<LanguageHandler>();
                if (_LanguageHandler == null)
                {
                    Debug.LogError("LanguageHandler not found in scene, please add it to the scene.");
                    return null;
                }
            }
            return _LanguageHandler;
        }
    }
    private CharacterTo3DMap CharacterToModelMap;
    public CharacterTo3DMap CharacterToModel
    {
        get
        {
            if (CharacterToModelMap == null)
            {
                CharacterToModelMap = FindFirstObjectByType<CharacterTo3DMap>();
                if (CharacterToModelMap == null)
                {
                    Debug.LogError("CharacterTo3DMap not found in scene, please add it to the scene.");
                    return null;
                }
            }
            return CharacterToModelMap;
        }
    }
    private AudioClip ExhaustAudioClipToPlay = null;
    private string ExhaustText = "";
    private float DelayBetweenExhaustSounds = 0.5f;
    //private TapIcon TapIcon;
    public override void Start()
    {
        StartCoroutine(GenerateExhaust());
    }

    private GridFiller _GridFiller;
    public override void LoadLevel(LevelConfig levelConfig)
    {
        base.LoadLevel(levelConfig);
        if (levelConfig.GetType().IsAssignableFrom(typeof(SpellingRacerConfig)) && SpellingTypedConfig == null)
        {
            SpellingTypedConfig = (SpellingRacerConfig)levelConfig;
        }
        else
        {
            if (SpellingTypedConfig != null)
                Debug.Log("Config Already set: " + SpellingTypedConfig.GetType());
            else
                Debug.LogError("Config is not of type SpellingRacerConfig, cannot load level");
        }

        // Reset per-word spawning state for repeated rounds
        PhenomesToPlayAtPoint.Clear();

        if (Map != null)
        {
            Map.TileSpawned -= Map_TileSpawned;
            Map.TileChanged -= VerticalSegmentReached;

            // Destroy previous tile objects to avoid persistence across reloads
            for (int i = Map.transform.childCount - 1; i >= 0; i--)
            {
                Destroy(Map.transform.GetChild(i).gameObject);
            }

            Map.ChunkedGrid = new Chunked3DGrid();
        }

        Map = this.LevelGeometry.GetComponent<StraitLineRacerMap>();
        if (Map == null)
        {
            Map = this.LevelGeometry.AddComponent<StraitLineRacerMap>();
        }

        ChosenWord = SpellingTypedConfig.GetRandomWord();

        int totalTilesForWord = (ChosenWord.Word.Length + 2) * SpellingTypedConfig.TilesPerLetter;
        totalTilesForWord = Mathf.Max(totalTilesForWord, (ChosenWord.Word.Length * SpellingTypedConfig.TilesPerLetter) + 5);
        NumberOfTilesWide = totalTilesForWord;

        Map.MapInitialize(SpellingTypedConfig.VerticalRoadSlicePrefabs, 
            SpellingTypedConfig.StartPrefabs,
            SpellingTypedConfig.EndPrefabs,
            zMax: totalTilesForWord);
        Map.zLimits = (0, totalTilesForWord); // Keep map limits consistent
        Map.TileSpawned += Map_TileSpawned;



        RacerLevelUI.DesiredText = ChosenWord.Word;


        this.LevelCamera = Map.LevelCamera;

        SpawnRacers();
        //Has to happen after SpawnRacers, since that calculates the number of lanes
        _GridFiller = new GridFiller(NumberOfTilesWide, Map.totalLanes, .4f, PlayerRacer.currentLane);
        Map.PlayerRacer = PlayerRacer.gameObject;
        Map.TileChanged += VerticalSegmentReached;


        WorldController.SetLevelCamera(LevelCamera);
        //DecideWhereLettersAreGoing();


        if (levelConfig.InstructionsModal != null)
        {
            var instance = this.WorldController.ShowModal(levelConfig.InstructionsModal.gameObject);
            instance.GetComponent<LevelInstructions>().PlayInstructions();
            instance.GetComponent<LevelInstructions>().InstructionsCompleted += (sender, e) => StartCountDown();
        }

        LanguageHandler.PlaySoundsInSequence(ChosenWord.Word, 0f);

        RacerLevelUI.gameObject.SetActive(true);

    }

    IEnumerator GenerateExhaust()
    {
        while (true)
        {

            if (ExhaustAudioClipToPlay != null)
            {
                Source.PlayOneShot(ExhaustAudioClipToPlay);
                if (PlayerRacer.Stopped == true)
                {
                    break;
                }

            }
            if (WorldController != null && WorldController.TextEffectPrefabs != null && WorldController.TextEffectPrefabs.Count() > 0)
            {
                var ChosenEffect = WorldController.TextEffectPrefabs[UnityEngine.Random.Range(0, WorldController.TextEffectPrefabs.Length)];
                Vector3 EffectPostion = PlayerRacer.gameObject.transform.position;
                if (this.GetLevelConfig().EffectOffset != null)
                {
                    var offset = this.GetLevelConfig().EffectOffset;
                    EffectPostion = new Vector3(EffectPostion.x + offset.x, EffectPostion.y + offset.y, EffectPostion.z + offset.z);
                }
                var InstancedEffect = Instantiate(ChosenEffect, EffectPostion, Quaternion.identity);
                var text = InstancedEffect.GetComponent<CFXR_ParticleText>();
                text.UpdateText(ExhaustText);
                text.gameObject.transform.localScale = new Vector3(3, 3, 3);
                Destroy(InstancedEffect, 2f);
            }
            yield return new WaitForSeconds(DelayBetweenExhaustSounds);
        }
    }

    private void StartCountDown()
    {
        var CountDown = this.WorldController.ShowCountDownModal(3);
        if (CountDown != null)
        {
            CountDown.ModalClosed += (sender, e) => SpawnRacers();
        }
    }
    private void SpawnRacers()
    {
        var PlayerStartIndex = Random.Range(0, Map.SpawnMarkers.Length);
        var SpawnMarker = Map.SpawnMarkers[PlayerStartIndex];
        var Racer = SpawnAtMarker(SpawnMarker);
        AddRacerComponentsAndSettings(Racer);

        PlayerRacer.currentLane = PlayerStartIndex;
        PlayerRacer.RacerStartPostion = SpawnMarker.transform.position;

        if (Racer == null)
        {
            Debug.LogError("Failed to spawn racer at marker: " + SpawnMarker.name);
            return;
        }

        AddPlayerRacerValues(Racer);
        LevelCamera.transform.parent = this.transform;
    }

    protected override void AddRacerComponentsAndSettings(GameObject Racer)
    {
        base.AddRacerComponentsAndSettings(Racer);
        PlayerRacer = Racer.GetComponent<StraitLineRacer>();

    }





    private void Display_CloseEvent()
    {
        WorldController.CloseModal();
        this.ClearLevelAndStartAnew();
    }
    /*
    private Dictionary<int ,int > letterPositions = new Dictionary<int, int>();

    private void DecideWhereLettersAreGoing()
    {
        for(int i = 0; i < ChosenWord.Word.Length; i++)
        {
            int letterLane = Random.Range(0, Map.totalLanes);
            int zPos = i * SpellingTypedConfig.TilesPerLetter;
            letterPositions[letterLane] = zPos;
        }
    }*/

    private void Map_TileSpawned(int x, int y, int index, GameObject VerticalObject)
    {
        int NumberOfThingsToSpawnAtIndex = Random.Range(1, Map.totalLanes - 1);
        var Slice = _GridFiller.GetSlice(index);

        for(int i =0; i< Slice.Count(); i++)
        {
            var cell = Slice[i];
            switch (cell)
            {
                // Do nothing, this cell is empty
                case GridFiller.CellType.Empty:
                case GridFiller.CellType.Path:

                    SpawnLetterAtVerticalAndHorizontalIndexes(index, i, VerticalObject);
                    
                    break;
                case GridFiller.CellType.Filled:
                        SpawnObsticleAtVerticalAndHorizontalIndexes(index, i, VerticalObject);
                    break;
            }
        }
    }
    private void SpawnObsticleAtVerticalAndHorizontalIndexes(int verticalIndex, int horizontalIndex, GameObject VerticalObject)
    {
        // This method can be used to spawn articles at specific vertical and horizontal indexes
        if (SpellingTypedConfig.Obsticles == null || SpellingTypedConfig.Obsticles.Count() == 0) return;
        var RandomObstaclePrefab = SpellingTypedConfig.Obsticles[Random.Range(0, SpellingTypedConfig.Obsticles.Length)];
        float xPos = Map.LaneCenters[horizontalIndex];
        Vector3 spawnPos = new Vector3(xPos, 0, verticalIndex * SpellingTypedConfig.VerticalRoadSliceThickness);
        Instantiate(RandomObstaclePrefab, spawnPos, Quaternion.identity, VerticalObject.transform);
        //Debug.Log("Adding Obsticle");
    }
    private void SpawnLetterAtVerticalAndHorizontalIndexes(int verticalIndex, int horizontalIndex, GameObject VerticalObject)
    {
        // This method can be used to spawn a letter at specific vertical and horizontal indexes
        if (verticalIndex <= 0 || verticalIndex % SpellingTypedConfig.TilesPerLetter != 0) return;

        int LetterIndex = (verticalIndex / SpellingTypedConfig.TilesPerLetter) - 1;

        if (LetterIndex < 0 || LetterIndex >= ChosenWord.PhoneticList.Count)
        {
            return;
        }
        var ChosenLetterOrLetters = ChosenWord.PhoneticList[LetterIndex].Item1;
        PhenomesToPlayAtPoint[verticalIndex] = ChosenWord.PhoneticList[LetterIndex]; // Clear the audio clip after using it


        //Debug.Log("Adding Letter: " + ChosenLetterOrLetters + " at index: " + verticalIndex + ", horizontalIndex: " + horizontalIndex);
        List<GameObject> LettersToSpawn = new List<GameObject>();
        foreach (var character in ChosenLetterOrLetters.ToCharArray())
        {
            var letter = character.ToString();
            var LettersFound = CharacterToModel.map.Where(x => x.Text == letter.ToUpper());
            if (LettersFound.Count() == 0)
            {
                Debug.LogWarning("No letter found for: " + letter);
                return;
            }
            var LetterPrefab = LettersFound.First().Object;
            LettersToSpawn.Add(LetterPrefab);
        }
        //Debug.Log("LettersToSpawn: " + LettersToSpawn.Count);
        float LetterSpacing = 3f;
        for (int i  = 0; i < LettersToSpawn.Count; i++)
        {
            var LetterPrefab = LettersToSpawn[i];
            float xPos = Map.LaneCenters[horizontalIndex];
            var StartingPosition = verticalIndex * SpellingTypedConfig.VerticalRoadSliceThickness;
            var OffsetPosition = (StartingPosition - (LettersToSpawn.Count * LetterSpacing)/2) + (i * LetterSpacing);
            Vector3 spawnPos = new Vector3(xPos, 0, OffsetPosition);

            var InstiantiatedObject = Instantiate(LetterPrefab, spawnPos, Quaternion.identity, VerticalObject.transform);
            InstiantiatedObject.transform.localScale = new Vector3(10, 10, 10);
            InstiantiatedObject.transform.localRotation = Quaternion.Euler(-90, 90, 0);
            //Debug.Log("Adding letter");
        }
    }
    private Dictionary<int, (string, AudioClip)> PhenomesToPlayAtPoint = new Dictionary<int, (string, AudioClip)>();


    public virtual void VerticalSegmentReached(int x, int y, int Segment)
    {
        if (PhenomesToPlayAtPoint.ContainsKey(Segment))
        {
            var clip = PhenomesToPlayAtPoint[Segment];
            ExhaustText = clip.Item1;
            if (Source == null)
            {
                Debug.LogWarning("Source is null, cannot play audio clip for segment: " + Segment);
                return;
            }
            if (clip.Item2 != null || Source != null)
            {
                Source.PlayOneShot(clip.Item2);
                ExhaustAudioClipToPlay = clip.Item2;
                DelayBetweenExhaustSounds = clip.Item2.length;
            }
            else
            {
                Debug.LogWarning("No audio clip found for segment: " + Segment);
            }

        }
    }
    protected override void Racer_drive_StoppedChanged(RacerMovement racer, bool obj)
    {
        base.Racer_drive_StoppedChanged(racer, obj);
        if (Display != null)
        {
            Display.ShowRaceResults = false;
            if(Display.TitleText != null)
                Display.TitleText.text = ChosenWord.Word;
        }
        if (obj == false)
        {
            RacerLevelUI.gameObject.SetActive(true);
        }
        if(obj == true && racer == PlayerRacer)
        {
            RacerLevelUI.gameObject.SetActive(false);
        }
        //RacerLevelUI.DesiredText = ChosenWord.Word;
        LanguageHandler.PlaySoundsInSequence(ChosenWord.Word, 0f);
    }


    public override void Update()
    {
        base.Update();

    }
    private bool isMoving = false;

    public override void ClearLevel()
    {
        if (WorldController.RandomLevelMode)
        {
            WorldController.LoadNextLevel();
        }
        else
        {
            WorldController.LoadLevelFromConfig(this.GetLevelConfig());
        }
    }
    int SegmentsForward = 0;
}