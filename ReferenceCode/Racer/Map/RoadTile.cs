using TMPro;
using UnityEngine;

public class RoadTile : MonoBehaviour
{
    public GameObject[] TextObjects;
    private string _TextValue;
    public string TextValue
    {
        get
        {
            return _TextValue;
        }
        set
        {
            _TextValue = value;
            foreach (var textObject in TextObjects)
            {
                textObject.GetComponent<TextMeshPro>().text = value;
                if(value == null || value == "")
                {
                    textObject.SetActive(false);
                }
                else
                {
                    textObject.SetActive(true);
                }
            }
        }
    }
    public void Start()
    {
        if(_TextValue == null || _TextValue == "")
        {
            TextValue = "";
        }
        
    }
}