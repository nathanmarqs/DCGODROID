using UnityEngine;

public class OptionPanel : OffAnimation
{
    private static readonly int CloseHash = Animator.StringToHash("Close");
    private static readonly int OpenHash = Animator.StringToHash("Open");
    [SerializeField] VolumePanel _volumePanel;
    [SerializeField] ResizeWindow _resizeWindowPanel;
    [SerializeField] GameplayOption _gameplayOption;
    [SerializeField] GraphicsOptionPanel _graphicsOptionPanel;
    [SerializeField] ServerRegionPanel _serverRegionPanel;
    [SerializeField] LanguagePanel _languagePanel;
    [SerializeField] Animator _anim;
    bool _isOpen = false;

    public void OnClickOpenOptionPanelButton()
    {
        if (_isOpen)
        {
            CloseOptionPanel();
        }

        else
        {
            if (Opening.instance != null)
            {
                Opening.instance.PlayDecisionSE();
            }

            else if (GManager.instance != null)
            {
                GManager.instance.PlayDecisionSE();
            }

            Open();
        }
    }

    public void Open()
    {
        _isOpen = true;
        gameObject.SetActive(true);
        _anim.SetInteger(OpenHash, 1);
        _anim.SetInteger(CloseHash, 0);

        if (_volumePanel != null)
        {
            _volumePanel.Off();
        }

        if (_resizeWindowPanel != null)
        {
            _resizeWindowPanel.Off();
        }

        if (_gameplayOption != null)
        {
            _gameplayOption.Off();
        }

        if (_graphicsOptionPanel != null)
        {
            _graphicsOptionPanel.Off();
        }

        if (_serverRegionPanel != null)
        {
            _serverRegionPanel.Off();
        }

        if (_languagePanel != null)
        {
            _languagePanel.Off();
        }
    }

    public void Close()
    {
        Close_(true);
    }

    public void CloseOptionPanel()
    {
        _isOpen = false;
        bool playSE = false;

        if (gameObject.activeSelf)
        {
            playSE = true;
        }

        if (_resizeWindowPanel != null)
        {
            if (_resizeWindowPanel.gameObject.activeSelf)
            {
                playSE = true;
            }
        }

        if (_volumePanel != null)
        {
            if (_volumePanel.gameObject.activeSelf)
            {
                playSE = true;
            }
        }

        if (_gameplayOption != null)
        {
            if (_gameplayOption.gameObject.activeSelf)
            {
                playSE = true;
            }
        }

        if (_graphicsOptionPanel != null)
        {
            if (_graphicsOptionPanel.gameObject.activeSelf)
            {
                playSE = true;
            }
        }

        if (_serverRegionPanel != null)
        {
            if (_serverRegionPanel.gameObject.activeSelf)
            {
                playSE = true;
            }
        }

        if (_languagePanel != null)
        {
            if (_languagePanel.gameObject.activeSelf)
            {
                playSE = true;
            }
        }

        Close_(playSE);

        if (_resizeWindowPanel != null)
        {
            _resizeWindowPanel.Close_(false);
        }

        if (_volumePanel != null)
        {
            _volumePanel.Close_(false);
        }

        if (_gameplayOption != null)
        {
            _gameplayOption.Close_(false);
        }

        if (_graphicsOptionPanel != null)
        {
            _graphicsOptionPanel.Close_(false);
        }

        if (_serverRegionPanel != null)
        {
            _serverRegionPanel.Close_(false);
        }

        if (_languagePanel != null)
        {
            _languagePanel.Close_(false);
        }
    }

    public void Close_(bool playSE)
    {
        if (playSE)
        {
            if (Opening.instance != null)
            {
                Opening.instance.PlayCancelSE();
            }

            else if (GManager.instance != null)
            {
                GManager.instance.PlayCancelSE();
            }
        }

        _anim.SafeSetInt(OpenHash, 0);
        _anim.SafeSetInt(CloseHash, 1);
    }

    public void Init()
    {
        Off();

        if (_volumePanel != null)
        {
            _volumePanel.Init();
        }

        if (_resizeWindowPanel != null)
        {
            _resizeWindowPanel.Init();
        }

        if (_gameplayOption != null)
        {
            _gameplayOption.Init();
        }

        if (_graphicsOptionPanel != null)
        {
            _graphicsOptionPanel.Init();
        }

        if (_serverRegionPanel != null)
        {
            _serverRegionPanel.Init();
        }

        if (_languagePanel != null)
        {
            _languagePanel.Init();
        }
    }

    public void OnClickExitGameButton()
    {
#if UNITY_STANDALONE
        Application.Quit();
#endif
    }

    private string _syncMessage = "";
    void OnGUI()
    {
        if (_isOpen)
        {
            float scaleX = Screen.width / 1920f;
            float scaleY = Screen.height / 1080f;
            GUI.matrix = Matrix4x4.TRS(Vector3.zero, Quaternion.identity, new Vector3(scaleX, scaleY, 1));
            
            GUIStyle btnStyle = new GUIStyle(GUI.skin.button);
            btnStyle.fontSize = 40;
            
            if (GUI.Button(new Rect(50, 50, 450, 120), "Sincronizar Decks\n(Downloads/DCGO/Decks)", btnStyle))
            {
                SyncDecksFromDownloads();
            }
            
            if (!string.IsNullOrEmpty(_syncMessage))
            {
                GUIStyle labelStyle = new GUIStyle(GUI.skin.label);
                labelStyle.fontSize = 40;
                labelStyle.normal.textColor = Color.green;
                GUI.Label(new Rect(50, 190, 800, 100), _syncMessage, labelStyle);
            }
        }
    }

    public void SyncDecksFromDownloads()
    {
        string publicPath = "/storage/emulated/0/Download/DCGO/Decks";
        string internalPath = System.IO.Path.Combine(Application.persistentDataPath, "Decks").Replace("\\", "/");
        
        if (!System.IO.Directory.Exists(publicPath))
        {
            try { System.IO.Directory.CreateDirectory(publicPath); } catch {}
            _syncMessage = "Pasta criada! Coloque os .txt nela.";
            return;
        }
        
        if (!System.IO.Directory.Exists(internalPath))
        {
            System.IO.Directory.CreateDirectory(internalPath);
        }
        
        try
        {
            string[] files = System.IO.Directory.GetFiles(publicPath, "*.txt");
            int count = 0;
            foreach (var f in files)
            {
                string dest = System.IO.Path.Combine(internalPath, System.IO.Path.GetFileName(f));
                System.IO.File.Copy(f, dest, true);
                count++;
            }
            _syncMessage = $"Sucesso! {count} decks copiados.";
        }
        catch (System.Exception ex)
        {
            _syncMessage = "Erro: " + ex.Message;
        }
    }
}
