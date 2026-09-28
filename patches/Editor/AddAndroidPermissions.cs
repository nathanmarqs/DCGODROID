using System.IO;
using System.Xml;
using UnityEditor.Android;

public class AddAndroidPermissions : IPostGenerateGradleAndroidProject
{
    public int callbackOrder { get { return 1; } }

    public void OnPostGenerateGradleAndroidProject(string path)
    {
        string manifestPath = path + "/src/main/AndroidManifest.xml";
        if (!File.Exists(manifestPath)) return;
        
        XmlDocument manifestDoc = new XmlDocument();
        manifestDoc.Load(manifestPath);
        
        XmlElement manifestNode = manifestDoc.DocumentElement;
        
        // Check if permission already exists to prevent infinite loop
        bool alreadyExists = false;
        foreach (XmlNode child in manifestNode.ChildNodes)
        {
            if (child.Name == "uses-permission")
            {
                foreach (XmlAttribute attr in child.Attributes)
                {
                    if (attr.Value == "android.permission.MANAGE_EXTERNAL_STORAGE")
                    {
                        alreadyExists = true;
                        break;
                    }
                }
            }
        }
        
        if (!alreadyExists)
        {
            // Create MANAGE_EXTERNAL_STORAGE
            XmlElement permissionElement = manifestDoc.CreateElement("uses-permission");
            permissionElement.SetAttribute("name", "http://schemas.android.com/apk/res/android", "android.permission.MANAGE_EXTERNAL_STORAGE");
            manifestNode.AppendChild(permissionElement);
            
            manifestDoc.Save(manifestPath);
            UnityEngine.Debug.Log("Injected MANAGE_EXTERNAL_STORAGE into AndroidManifest.xml successfully!");
        }
    }
}
