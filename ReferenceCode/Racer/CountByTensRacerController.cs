using Assets.LevelControllers;
using Assets.Levels.SpawnPatterns;
using Assets.Movements;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using Assets.ArtificersVaultCommon.Language;
using Unity.VisualScripting;
using System.Threading.Tasks;


[LevelControllerAttribute(typeof(CountByTensRacerConfig))]
public class CountByTensRacerController : RacerController
{
	[Language(SingularOrPluralIndicator = SingularOrPlural.Singular)]
	public string ten = "ten";
	[Language(SingularOrPluralIndicator = SingularOrPlural.Singular)]
	public string twenty = "twenty";
	[Language(SingularOrPluralIndicator = SingularOrPlural.Singular)]
	public string thirty = "thirty";
	[Language(SingularOrPluralIndicator = SingularOrPlural.Singular)]
	public string forty = "forty";
	[Language(SingularOrPluralIndicator = SingularOrPlural.Singular)]
	public string fifty = "fifty";
	[Language(SingularOrPluralIndicator = SingularOrPlural.Singular)]
	public string sixty = "sixty";
	[Language(SingularOrPluralIndicator = SingularOrPlural.Singular)]
	public string seventy = "seventy";
	[Language(SingularOrPluralIndicator = SingularOrPlural.Singular)]
	public string eighty = "eighty";
	[Language(SingularOrPluralIndicator = SingularOrPlural.Singular)]
	public string ninety = "ninety";
	[Language(SingularOrPluralIndicator = SingularOrPlural.Singular)]
	public string OneHundred = "one hundred";

	public override void Start()
	{
		PlayInstructions = false;

	}
	public override void LoadLevel(LevelConfig config)
	{
		if(config == null)
		{
			//Debug.LogError("Config is null, cannot load level");
			return;
		}
		if (config.GetType() == typeof(CountByTensRacerConfig))
		{
			//Debug.Log("Setting Config:" + config.GetType());
			this.TypedConfig = (CountByTensRacerConfig)config;
		}
		base.LoadLevel(config);
		this.RacerLevelUI.State = Assets.UIElements.RacerUIState.AccelerateOnly;


		this.Map = this.LevelGeometry.GetComponent<CountByTensMap>();
		
		if (Map == null)
		{
			Map = this.LevelGeometry.AddComponent<CountByTensMap>();
		}
		Map.MapInitialize(TypedConfig.VerticalRoadSlicePrefabs,
			TypedConfig.StartPrefabs,
			TypedConfig.EndPrefabs,
			zMax: 100);
		Map.TileChanged += Map_TileChanged;

		this.LevelCamera = Map.LevelCamera;
		StartRace();
	}

	private void Map_TileChanged(int arg1, int arg2, int arg3)
	{
		VerticalSegmentReached(arg3);
	}

	public override void VerticalSegmentReached(int Segment)
	{
		base.VerticalSegmentReached(Segment);
		Segment = Segment - 1;
		if (Segment % 10 == 0 && Segment != 0)
		{
			WorldController.LanguageHandler.PlaySoundsInSequence(new string[] { Segment.ToString() });
		}

		//Need a victory screen or something before we call that
		//StartCoroutine(EndLevelAt(.1f));
	}
	protected override void StartRace()
	{
		base.StartRace();
		var SpawnMarkers = this.Map.SpawnMarkers;
		Debug.Log("Found " + SpawnMarkers.Length + " spawn markers");
		foreach (var SpawnMarker in SpawnMarkers)
		{
			RacerStartPostions.Add(SpawnMarker.transform.position);
			var racer = SpawnAtMarker(SpawnMarker);
			AddRacerComponentsAndSettings(racer);
		}
		AddPlayerRacerValues(this.Racers[PlayerIndex]);
		Map.PlayerRacer = this.Racers[PlayerIndex];
		LevelCamera.transform.parent = this.transform;

	}



}
