using UnityEngine;
using UnityEngine.UI;
using UnityEngine.SceneManagement;

public class MobileScrollFixer : MonoBehaviour
{
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init()
    {
#if UNITY_ANDROID
        SceneManager.sceneLoaded += OnSceneLoaded;
        FixAllScrollRects();
#endif
    }

    static void OnSceneLoaded(Scene scene, LoadSceneMode mode)
    {
        FixAllScrollRects();
    }

    static void FixAllScrollRects()
    {
        ScrollRect[] scrollRects = Resources.FindObjectsOfTypeAll<ScrollRect>();
        foreach (var sr in scrollRects)
        {
            // Skip prefabs that are not in the scene
            if (sr.gameObject.scene.buildIndex == -1) continue;

            if (sr.gameObject.GetComponent<ScrollRectDragEnabler>() == null)
            {
                sr.gameObject.AddComponent<ScrollRectDragEnabler>();
            }
        }
    }
}

public class ScrollRectDragEnabler : MonoBehaviour
{
    private ScrollRect _sr;
    private float _checkTimer = 0f;
    private bool _initializedRaycast = false;

    void Awake()
    {
        _sr = GetComponent<ScrollRect>();
    }

    void Update()
    {
        if (_sr == null) return;

        // Automatically enable axes if content is larger than viewport
        // We check periodically in case content changes dynamically (e.g., cards are loaded)
        _checkTimer -= Time.unscaledDeltaTime;
        if (_checkTimer <= 0)
        {
            _checkTimer = 1.0f; // Check every 1 second to save performance

            if (_sr.content != null && _sr.viewport != null)
            {
                // Enable vertical drag if content is taller
                if (_sr.content.rect.height > _sr.viewport.rect.height + 2f)
                {
                    _sr.vertical = true;
                }
                
                // Enable horizontal drag if content is wider
                if (_sr.content.rect.width > _sr.viewport.rect.width + 2f)
                {
                    _sr.horizontal = true;
                }

                if (!_initializedRaycast)
                {
                    // Ensure the viewport catches touch drags even if tapping empty space
                    Image viewportImg = _sr.viewport.GetComponent<Image>();
                    if (viewportImg == null)
                    {
                        viewportImg = _sr.viewport.gameObject.AddComponent<Image>();
                        viewportImg.color = new Color(0, 0, 0, 0); // Transparent
                    }
                    viewportImg.raycastTarget = true;
                    _initializedRaycast = true;
                }
            }
        }
    }
}
