using Assets.ArtificersVaultCommon.Language;
using Assets.LevelControllers;
using Assets.Levels.SpawnPatterns;
using Assets.Movements;
using Assets.UIElements;
using Assets.World;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Threading.Tasks;
using TMPro;
using UnityEngine;
using UnityEngine.UI;


public class LevelInstructions : MonoBehaviour
{
    private WorldController _WorldController;
    public WorldController WorldController
    {
        get
        {
            if (_WorldController == null)
            {
                _WorldController = FindFirstObjectByType<WorldController>();
            }
            return _WorldController;
        }
    }

    public virtual void PlayInstructions()
    {
    }

    public event EventHandler InstructionsCompleted;
    protected void InstructionsDone()
    {
        this.InstructionsCompleted?.Invoke(this, new EventArgs());
    }
}

public class RaceInstructions : LevelInstructions
{

    [Language(SingularOrPluralIndicator = SingularOrPlural.Singular)]
    public static String GreenAudio = "Press the button when it's green for a speed boost.";

    [Language(SingularOrPluralIndicator = SingularOrPlural.Singular)]
    public static String RedAudio = "Don't touch the button when it's red or you'll slow down.";

    public TextMeshProUGUI GreenText;
    public TextMeshProUGUI RedText;


    public Sprite GreenButtonSprite;
    public Sprite RedButtonSprite;

    public GameObject ButtonSprite;

    public void Start()
    {
        if (GreenText != null)
        {
            GreenText.text = GreenAudio;
        }
        if (RedText != null)
        {
            RedText.text = RedAudio;
        }
        /*
        var GreenResult = WorldController.LanguageHandler.PlaySoundsInSequence(GreenAudio);
        var RedResult = WorldController.LanguageHandler.PlaySoundsInSequence(RedAudio);
        WorldController.CloseModal();

        CallInstructionsCompleted();*/
    }
    public override void PlayInstructions()
    {
        base.PlayInstructions();
        StartCoroutine(WaitForAudioToComplete());
    }
    private System.Collections.IEnumerator WaitForAudioToComplete()
    {
        Debug.Log("Waiting for audio to complete...");
        if(ButtonSprite != null)
        {
            ButtonSprite.GetComponent<Image>().sprite = GreenButtonSprite;
        }
        var GreenResult = WorldController.LanguageHandler.PlaySoundsInSequence(GreenAudio);
        yield return new WaitForSeconds(GreenResult.Item1);
        if(ButtonSprite != null)
        {
            ButtonSprite.GetComponent<Image>().sprite = RedButtonSprite;
        }
        var RedResult = WorldController.LanguageHandler.PlaySoundsInSequence(RedAudio);
        yield return new WaitForSeconds(RedResult.Item1);
        //WorldController.CloseModal();
        InstructionsDone();
    }
}