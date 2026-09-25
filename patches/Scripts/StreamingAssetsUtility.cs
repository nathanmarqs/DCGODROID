using System;
using System.IO;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.Networking;
using WebP;

public class StreamingAssetsUtility
{
    private static bool _seededBundledTextures = false;

    private static readonly string[] BundledTextureRelativePaths = new string[]
    {
        "Textures/Background_battle.png",
        "Textures/Background_home.png",
        "Textures/CurrentPhaseBar_Opponent.png",
        "Textures/CurrentPhaseBar_You.png",
        "Textures/PlayMat_Opponent.png",
        "Textures/PlayMat_You.png",
        "Textures/SecurityIcon_Opponent.png",
        "Textures/SecurityIcon_You.png",
        "Textures/card_back_main.png",
        "Textures/card_back_sub.png"
    };

    public static async Task EnsureBundledTexturesSeeded()
    {
        if (_seededBundledTextures) return;

#if UNITY_ANDROID && !UNITY_EDITOR
        try
        {
            string markerPath = Path.Combine(Application.persistentDataPath, "Textures/.seeded_ui_v1").Replace("\\", "/");
            bool allFilesExist = true;
            foreach (var rel in BundledTextureRelativePaths)
            {
                string destPath = Path.Combine(Application.persistentDataPath, rel).Replace("\\", "/");
                if (!File.Exists(destPath))
                {
                    allFilesExist = false;
                    break;
                }
            }

            if (File.Exists(markerPath) && allFilesExist)
            {
                _seededBundledTextures = true;
                return;
            }

            int count = 0;
            foreach (var rel in BundledTextureRelativePaths)
            {
                string destPath = Path.Combine(Application.persistentDataPath, rel).Replace("\\", "/");
                EnsureParentDirectory(destPath);
                string saPath = Path.Combine(Application.streamingAssetsPath, rel).Replace("\\", "/");

                byte[] data = await ReadBytesFlexible(saPath);
                if (data != null && data.Length > 0)
                {
                    File.WriteAllBytes(destPath, data);
                    count++;
                }
            }

            EnsureParentDirectory(markerPath);
            File.WriteAllText(markerPath, DateTime.UtcNow.ToString("o"));
            Debug.Log($"[StreamingAssetsUtility] Seeded {count} files from APK StreamingAssets");
        }
        catch (Exception ex)
        {
            Debug.LogWarning($"[StreamingAssetsUtility] Seeding textures warning: {ex.Message}");
        }
#endif
        _seededBundledTextures = true;
    }

    public static async Task<byte[]> ReadBytesFlexible(string urlOrPath)
    {
        if (string.IsNullOrEmpty(urlOrPath)) return null;

        if (urlOrPath.Contains("://") || !File.Exists(urlOrPath))
        {
            return await ReadStreamingAssetsBytes(urlOrPath);
        }

        return await ReadFile(urlOrPath);
    }

    public static async Task<byte[]> ReadStreamingAssetsBytes(string path)
    {
        string url = path;
        if (!url.Contains("://"))
        {
            url = "file://" + url;
        }

        using (UnityWebRequest req = UnityWebRequest.Get(url))
        {
            var op = req.SendWebRequest();
            while (!op.isDone)
            {
                await Task.Yield();
            }

            if (req.result == UnityWebRequest.Result.Success && req.downloadHandler != null)
            {
                return req.downloadHandler.data;
            }
            else
            {
                Debug.LogWarning($"[StreamingAssetsUtility] Failed to read {url}: {req.error}");
                return null;
            }
        }
    }

    public static async Task<byte[]> ReadFile(string path)
    {
        if (!File.Exists(path))
        {
            return await ReadBytesFlexible(path);
        }

        using (FileStream fileStream = new FileStream(
            path, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, true))
        {
            var resultBytes = new byte[fileStream.Length];
            await fileStream.ReadAsync(resultBytes, 0, (int)fileStream.Length);
            return resultBytes;
        }
    }

    #region Texture loading
    public static Texture2D BinaryToTexture(byte[] bytes)
    {
        Texture2D texture = new Texture2D(1, 1);
        texture.LoadImage(bytes);
        return texture;
    }

    public static async Task<Sprite> GetSprite(string fileName, bool isCard = false, bool isLauncher = false)
    {
        string path = "";

        if (isCard)
        {
            if (fileName.Contains("-token"))
            {
                return await GetTokenImageData(Path.Combine(GetStreamingAssetPath("Textures", isLauncher), $"Card/{fileName}.png").Replace("\\", "/"));
            }
            else
            {
                path = Path.Combine(GetStreamingAssetPath("Textures", isLauncher), $"Card/{fileName}.webp").Replace("\\", "/");

                if (!File.Exists(path))
                {
                    return await GetCardImageData(fileName, path);
                }
                else
                {
                    return await GetCardImageDataLocal(path);
                }
            }
        }
        else
        {
            return await GetSpriteImage(fileName, isLauncher);
        }
    }

    public static async Task<Sprite> GetSpriteImage(string fileName, bool isLauncher = false)
    {
        await EnsureBundledTexturesSeeded();

        string basePath = GetStreamingAssetPath("Textures", isLauncher);
        string path = Path.Combine(basePath, $"{fileName}.jpg").Replace("\\", "/");

        if (!File.Exists(path))
            path = Path.Combine(basePath, $"{fileName}.png").Replace("\\", "/");

        byte[] imageBuff = null;
        if (File.Exists(path))
        {
            imageBuff = await ReadFile(path);
        }
        else
        {
            // Direct fallback to StreamingAssets in APK
            string saPath = Path.Combine(Application.streamingAssetsPath, $"Textures/{fileName}.png").Replace("\\", "/");
            imageBuff = await ReadBytesFlexible(saPath);
            if (imageBuff != null && imageBuff.Length > 0)
            {
                try
                {
                    EnsureParentDirectory(path);
                    File.WriteAllBytes(path, imageBuff);
                }
                catch {}
            }
        }

        if (imageBuff != null && imageBuff.Length > 0)
        {
            Texture2D tex = BinaryToTexture(imageBuff);
            Sprite sprite = Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), Vector2.zero);
            return sprite;
        }

        return null;
    }

    public static async Task<Sprite> GetTokenImageData(string path)
    {
        if (File.Exists(path))
        {
            byte[] imageBuff = await ReadFile(path);
            Texture2D tex = BinaryToTexture(imageBuff);

            Sprite sprite = Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), Vector2.zero);
            return sprite;
        }

        return null;
    }

    public static async Task<Sprite> GetCardImageDataLocal(string path)
    {
        if (File.Exists(path))
        {
            byte[] imageBuff = await ReadFile(path);
            Texture2D texture = Texture2DExt.CreateTexture2DFromWebP(imageBuff, lMipmaps: true, lLinear: false, lError: out WebP.Error lError);
            if (lError == WebP.Error.Success)
            {
                Sprite sprite = Sprite.Create(texture, new Rect(0, 0, texture.width, texture.height), Vector2.zero);
                return sprite;
            }
            else
            {
                Debug.Log(lError.ToString());
            }
        }

        return null;
    }

    public static async Task<Sprite> GetCardImageData(string fileName, string filePath)
    {
        Sprite sprite;

        // Attempt to get the card image from repo
        sprite = await HandleCardImage(fileName, filePath);

        if (sprite != null) return sprite;
        else
        {
            // Attempt to get the card image from repo, this time with the sample suffix
            sprite = await HandleCardImage(fileName, filePath, isSample: true);

            if (sprite != null) return sprite;
            return null;
        }
    }

    public static async Task<Sprite> HandleCardImage(string fileName, string filePath, bool isSample = false)
    {
        string urlPath = $"https://raw.githubusercontent.com/TakaOtaku/Digimon-Card-App/main/src/assets/images/cards/{fileName}";
        if (isSample) urlPath += $"-Sample.webp";
        else urlPath += $".webp";

        UnityWebRequest webReq_CardImage = UnityWebRequest.Get(urlPath);
        UnityWebRequestAsyncOperation operation = webReq_CardImage.SendWebRequest();

        while (!operation.isDone)
        {
            await Task.Yield();
        }

        if (webReq_CardImage.result == UnityWebRequest.Result.ConnectionError)
            return null;
        else if (webReq_CardImage.result == UnityWebRequest.Result.ProtocolError)
            return null;
        else
        {
            if (!File.Exists(filePath))
            {
                EnsureParentDirectory(filePath);
                File.WriteAllBytes(filePath, webReq_CardImage.downloadHandler.data);
            }

            Texture2D texture = Texture2DExt.CreateTexture2DFromWebP(webReq_CardImage.downloadHandler.data, lMipmaps: true, lLinear: false, lError: out WebP.Error lError);

            if (lError == WebP.Error.Success)
            {
                Sprite sprite = Sprite.Create(texture, new Rect(0, 0, texture.width, texture.height), Vector2.zero);
                return sprite;
            }
            else
            {
                Debug.Log($"Failed to convert: {lError.ToString()}");
            }
            return null;
        }
    }
    #endregion

    public static bool IsCardExists(CEntity_Base cEntity_Base)
    {
        string path = Path.Combine(GetStreamingAssetPath("Textures", false), $"Card/{cEntity_Base.CardSpriteName}.webp").Replace("\\", "/");

        if (cEntity_Base.CardSpriteName.Contains("token"))
            path = Path.Combine(GetStreamingAssetPath("Textures", false), $"Card/{cEntity_Base.CardSpriteName}.png").Replace("\\", "/");

        return File.Exists(path);
    }

    #region Text files
    public static string GetText(string fileName)
    {
        string path = Path.Combine(GetStreamingAssetPath("", false), $"{fileName}.txt").Replace("\\", "/");

        if (File.Exists(path))
        {
            return File.ReadAllText(path);
        }

        return "";
    }

    public static string GetDecksPath()
    {
#if UNITY_ANDROID && !UNITY_EDITOR
        string path = Path.Combine(Application.persistentDataPath, "Decks").Replace("\\", "/");
        if (!Directory.Exists(path)) Directory.CreateDirectory(path);
        return path;
#else
        return Path.Combine(Application.streamingAssetsPath, "Decks").Replace("\\", "/");
#endif
    }
    #endregion

    public static string GetStreamingAssetPath(string subPath, bool isLauncher)
    {
#if UNITY_ANDROID && !UNITY_EDITOR
        string basePath = Application.persistentDataPath;
        if (!string.IsNullOrEmpty(subPath))
        {
            basePath = Path.Combine(basePath, subPath).Replace("\\", "/");
        }
        if (!Directory.Exists(basePath))
        {
            Directory.CreateDirectory(basePath);
        }
        if (subPath == "Textures")
        {
            string cardDir = Path.Combine(basePath, "Card").Replace("\\", "/");
            if (!Directory.Exists(cardDir))
            {
                Directory.CreateDirectory(cardDir);
            }
        }
        return basePath;
#else
        if (isLauncher)
        {
            string path = Application.streamingAssetsPath;
            path = GetOneUpperDirectoryPath(path);
            path = Path.Combine(path, $"Assets/{subPath}").Replace("\\", "/");
            return path;
        }
        else
        {
            string path = Application.streamingAssetsPath;
            path = GetOneUpperDirectoryPath(path);
            path = GetOneUpperDirectoryPath(path);
            path = Path.Combine(path, $"Assets/{subPath}").Replace("\\", "/");
            return path;
        }
#endif
    }

    private static void EnsureParentDirectory(string path)
    {
        string dir = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
        {
            Directory.CreateDirectory(dir);
        }
    }

    static string GetOneUpperDirectoryPath(string path)
    {
        if (String.IsNullOrEmpty(path)) return "";
        path = path.Replace("\\", "/");
        if (!path.Contains("/")) return path;

        path = path.Substring(0, path.LastIndexOf("/") + 1);

        if (path.Length >= 1)
        {
            if (path[path.Length - 1] == '/')
            {
                path = path.Substring(0, path.LastIndexOf("/"));
            }
        }

        return path.Substring(0, path.LastIndexOf("/") + 1);
    }
}
