using Assets.LevelControllers;
using Assets.Levels.SpawnPatterns;
using Assets.Movements;
using Assets.UIElements;
using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.AI;

public class RacerController : LevelController
{
    public float playerSpeed = 5f; // Player speed when tapping the screen
    public float aiSpeed = 3f;     // AI racer speed
    protected RacerConfig TypedConfig;

    protected List<GameObject> Racers = new List<GameObject>();
    protected List<Vector3> RacerStartPostions = new List<Vector3>();

    public float moveDuration = 1f;
    protected int PlayerIndex = 3;

    protected Camera LevelCamera;
    protected StraitLineRacerMap Map;

    public bool PlayInstructions = false;

    private AudioSource _AudioSource;
    protected AudioSource Source
    {
        get
        {
            if (_AudioSource == null)
            {
                _AudioSource = this.GetComponent<AudioSource>();
                if (_AudioSource == null)
                {
                    _AudioSource = this.gameObject.AddComponent<AudioSource>();
                    _AudioSource.spatialBlend = 1f;
                    _AudioSource.rolloffMode = AudioRolloffMode.Linear;
                }
            }
            return _AudioSource;
        }
    }


    private MenuItemManager _Manager;
    public MenuItemManager Manager
    {
        get
        {
            if (_Manager == null)
            {
                _Manager = FindFirstObjectByType<MenuItemManager>();
            }
            return _Manager;
        }
        set
        {
            _Manager = value;
        }

    }

    private SpellingRacerLevelUI _RacerLevelUI = null;
    protected SpellingRacerLevelUI RacerLevelUI
    {
        get
        {
            if (_RacerLevelUI == null)
            {
                _RacerLevelUI = GameObject.FindAnyObjectByType<SpellingRacerLevelUI>(FindObjectsInactive.Include);
                if (_RacerLevelUI == null)
                {
                    Debug.LogError("RacerLevelUI not found in scene, please add it to the scene.");
                    return null;
                }
            }
            return _RacerLevelUI;
        }
    }



    public bool ClickAnyWhere = false; // If true, player can click anywhere to move racer


    //private TapIcon TapIcon;
    public virtual void Start()
    {

    }
    public override void LoadLevel(LevelConfig levelConfig)
    {
        base.LoadLevel(levelConfig);
        if (typeof(RacerConfig).IsAssignableFrom(levelConfig.GetType()) && TypedConfig == null)
        {
            TypedConfig = (RacerConfig)levelConfig;
        }
        else
        {
            if (TypedConfig != null)
                Debug.Log("Config Already set: " + TypedConfig.GetType());
            else
                Debug.LogError($"Config: {levelConfig.GetType()} is not of type RacerConfig, cannot load level");
        }
        if (TypedConfig.UIGameObject != null)
        {
            var UI = WorldController.AddToLevelCanvas(TypedConfig.UIGameObject);
        }

        if (levelConfig.InstructionsModal != null && PlayInstructions)
        {
            this.RacerLevelUI.enabled = false; //We're going to disable it while we run instructions
            //_levelConfig.InstructionsModal.gameObject.SetActive(true);
            var instance = this.WorldController.ShowModal(levelConfig.InstructionsModal.gameObject);
            instance.GetComponent<LevelInstructions>().PlayInstructions();
            instance.GetComponent<LevelInstructions>().InstructionsCompleted += (sender, e) => StartCountDown();
            //instance.SetActive(false);
        }
    }
    private void StartCountDown()
    {
        var CountDown = this.WorldController.ShowCountDownModal(3);
        if (CountDown != null)
        {
            CountDown.ModalClosed += (sender, e) => StartRace();
        }
        else
        {
            StartRace();
        }
    }

    protected virtual void StartRace()
    {
        this.RacerLevelUI.enabled = true; //Make sure the UI is enabled. May have been turned off

    }

    protected virtual void AddRacerComponentsAndSettings(GameObject racer)
    {
        //Debug.Log("Creating Racer");
        var interactive = racer.GetComponent<InteractiveItem>();
        if (interactive != null)
        {
            interactive.enabled = false; // Disable interaction for AI racers
        }
        interactive.gameObject.tag = "Untagged";
        var rigidbody = racer.GetComponent<Rigidbody>();
        if (rigidbody == null)
        {
            rigidbody = racer.AddComponent<Rigidbody>();
            rigidbody.isKinematic = true; // Set to kinematic for controlled movement
        }
        else
        {
            rigidbody.isKinematic = true; // Ensure it's kinematic
        }
        Racers.Add(racer);
        var racer_drive = racer.AddComponent<StraitLineRacer>();
        racer_drive.transform.parent = this.transform;
                racer_drive.map = this.Map;

        var speed = Random.Range(TypedConfig.MinSpeed, TypedConfig.MaxSpeed);
        if (Racers.Count == PlayerIndex + 1)
        {
            speed = TypedConfig.MinSpeed;
        }
        racer_drive.RacerSpeed = speed;
        racer_drive.StoppedChanged += Racer_drive_StoppedChanged;
    }



    protected bool SuccessModalShowing = false;
    protected RaceResultsDisplay Display;
    protected virtual void Racer_drive_StoppedChanged(RacerMovement racer, bool obj)
    {
        if(obj == false) // Racer is moving
        {
            return;
        }
        if (SuccessModalShowing == false)
        {
            Debug.Log("Show Success Modal");
            RacerLevelUI.gameObject.SetActive(false);
            var success = WorldController.ShowModal(TypedConfig.SuccessModal);
            Display = success.GetComponent<RaceResultsDisplay>();
            SuccessModalShowing = true;
            Display.CloseEvent += Display_CloseEvent;
        }
        if (Racers.Count > 0 && PlayerIndex < Racers.Count)
        {
            Display.AddRacerResult(racer.RacerName, racer.EndTime ?? 0f, racer == Racers[PlayerIndex]);

        }

    }

    private void Display_CloseEvent()
    {
        WorldController.CloseModal();
        this.ClearLevelAndStartAnew();
    }

    private int NumberOfTilesIn = -1;

    protected void AddPlayerRacerValues(GameObject Racer)
    {
        var Movement = Racer.GetComponent<RacerMovement>();
        Movement.RacerName = Manager.GetCurrentProfile().ProfileName;
        Movement.LevelCamera = LevelCamera;
        Movement.SoundsToPlayOnAccelerateClick = TypedConfig.SoundsToPlayOnAccelerateClick;
        Movement.SoundsToPlayOnFailedAccelerateClick = TypedConfig.SoundsToPlayOnFailedAccelerateClick;

    }
   
    public virtual void VerticalSegmentReached(int Segment)
    {
        //Do nothing on Base Class, subclasses may override this method  
    }


    public override void Update()
    {
        base.Update();
    }

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