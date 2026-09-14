using System;
using System.IO;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.Networking;
using WebP;

public class StreamingAssetsUtility
{
    public static async Task<byte[]> ReadFile(string path)
    {
#if UNITY_ANDROID && !UNITY_EDITOR
        if (path.Contains("://") || path.Contains("jar:file") || !File.Exists(path))
        {
            using (UnityWebRequest uwr = UnityWebRequest.Get(path))
            {
                var op = uwr.SendWebRequest();
                while (!op.isDone)
                {
                    await Task.Yield();
                }

                if (uwr.result == UnityWebRequest.Result.Success)
                {
                    return uwr.downloadHandler.data;
                }
                return null;
            }
        }
#endif
        if (File.Exists(path))
        {
            using (FileStream fileStream = new FileStream(
                path, FileMode.Open, FileAccess.Read))
            {
                var resultBytes = new byte[fileStream.Length];
                await fileStream.ReadAsync(resultBytes, 0, (int)fileStream.Length);
                return resultBytes;
            }
        }
        return null;
    }

    #region BinaryToTexture
    public static Texture2D BinaryToTexture(byte[] bytes)
    {
        Texture2D texture = new Texture2D(1, 1);
        texture.LoadImage(bytes);
        return texture;
    }

    public static async Task<Sprite> GetSprite(string fileName, bool isCard = false, bool isLauncher = false)
    {
        if (isCard)
        {
            if (fileName.Contains("-token"))
            {
#if UNITY_ANDROID && !UNITY_EDITOR
                string persistentToken = Path.Combine(Application.persistentDataPath, $"Textures/Card/{fileName}.png").Replace("\\", "/");
                if (File.Exists(persistentToken))
                {
                    return await GetTokenImageData(persistentToken);
                }
                string streamToken = Path.Combine(GetStreamingAssetPath("Textures", isLauncher), $"Card/{fileName}.png").Replace("\\", "/");
                return await GetTokenImageData(streamToken);
#else
                return await GetTokenImageData(Path.Combine(GetStreamingAssetPath("Textures", isLauncher), $"Card/{fileName}.png").Replace("\\", "/"));
#endif
            }
            else
            {
#if UNITY_ANDROID && !UNITY_EDITOR
                string persistentCard = Path.Combine(Application.persistentDataPath, $"Textures/Card/{fileName}.webp").Replace("\\", "/");
                if (File.Exists(persistentCard))
                {
                    return await GetCardImageDataLocal(persistentCard);
                }

                string streamCard = Path.Combine(GetStreamingAssetPath("Textures", isLauncher), $"Card/{fileName}.webp").Replace("\\", "/");
                byte[] streamBytes = await ReadFile(streamCard);
                if (streamBytes != null && streamBytes.Length > 0)
                {
                    Texture2D tex = Texture2DExt.CreateTexture2DFromWebP(streamBytes, lMipmaps: true, lLinear: false, lError: out WebP.Error lError);
                    if (lError == WebP.Error.Success)
                    {
                        return Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), Vector2.zero);
                    }
                }

                return await GetCardImageData(fileName, persistentCard);
#else
                string path = Path.Combine(GetStreamingAssetPath("Textures", isLauncher), $"Card/{fileName}.webp").Replace("\\", "/");

                if (!File.Exists(path))
                {
                    return await GetCardImageData(fileName, path);
                }
                else
                {
                    return await GetCardImageDataLocal(path);
                }
#endif
            }
        }
        else
        {
            return await GetSpriteImage(fileName, isLauncher);
        }
    }

    public static async Task<Sprite> GetSpriteImage(string fileName, bool isLauncher = false)
    {
#if UNITY_ANDROID && !UNITY_EDITOR
        string basePath = GetStreamingAssetPath("Textures", isLauncher);
        string pathPng = Path.Combine(basePath, $"{fileName}.png").Replace("\\", "/");
        byte[] imageBuff = await ReadFile(pathPng);
        if (imageBuff == null || imageBuff.Length == 0)
        {
            string pathJpg = Path.Combine(basePath, $"{fileName}.jpg").Replace("\\", "/");
            imageBuff = await ReadFile(pathJpg);
        }

        if (imageBuff != null && imageBuff.Length > 0)
        {
            Texture2D tex = BinaryToTexture(imageBuff);
            Sprite sprite = Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), Vector2.zero);
            return sprite;
        }

        return null;
#else
        string path = Path.Combine(GetStreamingAssetPath("Textures", isLauncher), $"{fileName}.jpg").Replace("\\", "/");

        if (!File.Exists(path))
            path = Path.Combine(GetStreamingAssetPath("Textures", isLauncher), $"{fileName}.png").Replace("\\", "/");

        if (File.Exists(path))
        {
            byte[] imageBuff = await ReadFile(path);
            Texture2D tex = BinaryToTexture(imageBuff);

            Sprite sprite = Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), Vector2.zero);

            return sprite;
        }

        return null;
#endif
    }

    public static async Task<Sprite> GetTokenImageData(string path)
    {
        byte[] imageBuff = await ReadFile(path);
        if (imageBuff != null && imageBuff.Length > 0)
        {
            Texture2D tex = BinaryToTexture(imageBuff);
            Sprite sprite = Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), Vector2.zero);
            return sprite;
        }

        return null;
    }

    public static async Task<Sprite> GetCardImageDataLocal(string path)
    {
        byte[] imageBuff = await ReadFile(path);
        if (imageBuff != null && imageBuff.Length > 0)
        {
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

        Debug.Log($"WebRequest isDone: {fileName}");
        if (webReq_CardImage.result == UnityWebRequest.Result.ConnectionError)
            return null;
        else if (webReq_CardImage.result == UnityWebRequest.Result.ProtocolError)
            return null;
        else
        {
            try
            {
                string dir = Path.GetDirectoryName(filePath);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                {
                    Directory.CreateDirectory(dir);
                }
                if (!File.Exists(filePath))
                {
                    File.WriteAllBytes(filePath, webReq_CardImage.downloadHandler.data);
                }
            }
            catch (Exception ex)
            {
                Debug.LogWarning($"Failed to save card image locally: {ex.Message}");
            }

            Texture2D texture = Texture2DExt.CreateTexture2DFromWebP(webReq_CardImage.downloadHandler.data, lMipmaps: true, lLinear: false, lError: out WebP.Error lError);

            if (lError == WebP.Error.Success)
            {
                Sprite sprite = Sprite.Create(texture, new Rect(0, 0, texture.width, texture.height), Vector2.zero);
                return sprite;
            }
            else Debug.Log($"Failed to convert: {lError.ToString()}");
            return null;
        }
    }

    #endregion

    public static bool IsCardExists(CEntity_Base cEntity_Base)
    {
#if UNITY_ANDROID && !UNITY_EDITOR
        string path = Path.Combine(Application.persistentDataPath, $"Textures/Card/{cEntity_Base.CardSpriteName}.webp").Replace("\\", "/");
        if (File.Exists(path)) return true;
        return true;
#else
        string path = Path.Combine(GetStreamingAssetPath("Textures", false), $"Card/{cEntity_Base.CardSpriteName}.webp").Replace("\\", "/");

        if (cEntity_Base.CardSpriteName.Contains("token"))
            path = Path.Combine(GetStreamingAssetPath("Textures", false), $"Card/{cEntity_Base.CardSpriteName}.png").Replace("\\", "/");

        return File.Exists(path);
#endif
    }

    #region GetText
    public static string GetText(string fileName)
    {
        string path = Path.Combine(GetStreamingAssetPath("", false), $"{fileName}.txt").Replace("\\", "/");

#if UNITY_ANDROID && !UNITY_EDITOR
        byte[] bytes = ReadFile(path).GetAwaiter().GetResult();
        if (bytes != null && bytes.Length > 0)
        {
            return System.Text.Encoding.UTF8.GetString(bytes);
        }
        return "";
#else
        if (File.Exists(path))
        {
            return File.ReadAllText(path);
        }

        return "";
#endif
    }
    #endregion

    public static string GetDecksPath()
    {
#if UNITY_ANDROID && !UNITY_EDITOR
        string path = Path.Combine(Application.persistentDataPath, "Decks").Replace("\\", "/");
#else
        string path = GetStreamingAssetPath("Decks", false);
#endif
        if (!Directory.Exists(path))
        {
            Directory.CreateDirectory(path);
        }
        return path;
    }

    public static string GetStreamingAssetPath(string subPath, bool isLauncher)
    {
#if UNITY_ANDROID && !UNITY_EDITOR
        if (subPath == "Decks" || subPath.StartsWith("Decks/") || subPath.StartsWith("Decks\\"))
        {
            return GetDecksPath();
        }

        string path = Application.streamingAssetsPath;
        if (!string.IsNullOrEmpty(subPath))
        {
            path = Path.Combine(path, subPath).Replace("\\", "/");
        }
        return path;
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