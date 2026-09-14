using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

public static class ProductionBuild
{
    public static void Android()
    {
        var production = Directory.GetParent(Directory.GetParent(Application.dataPath).FullName).FullName;
        var output = Path.Combine(production, "builds", "Android", "DCGO-android.apk");
        Directory.CreateDirectory(Path.GetDirectoryName(output));
        if (!EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android))
            throw new Exception("Nao foi possivel selecionar Android. Verifique Android Build Support.");
        UnityEditor.Android.AndroidExternalToolsSettings.sdkRootPath = @"C:\AndroidSDK";
        UnityEditor.Android.AndroidExternalToolsSettings.ndkRootPath = @"C:\AndroidNDK";
        UnityEditor.Android.AndroidExternalToolsSettings.jdkRootPath = @"C:\AndroidJDK";

        PlayerSettings.SetScriptingBackend(BuildTargetGroup.Android, ScriptingImplementation.IL2CPP);
        PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
        PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.Android, false);
        PlayerSettings.SetGraphicsAPIs(BuildTarget.Android, new[] { UnityEngine.Rendering.GraphicsDeviceType.OpenGLES3 });
        EditorUserBuildSettings.buildAppBundle = false;
        PlayerSettings.defaultInterfaceOrientation = UIOrientation.AutoRotation;
        PlayerSettings.allowedAutorotateToLandscapeLeft = true;
        PlayerSettings.allowedAutorotateToLandscapeRight = true;
        PlayerSettings.allowedAutorotateToPortrait = false;
        PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;

        AssetDatabase.SaveAssets();
        var scenes = EditorBuildSettings.scenes.Where(scene => scene.enabled).Select(scene => scene.path).ToArray();
        if (scenes.Length == 0) throw new Exception("Nenhuma cena habilitada no Build Settings.");
        var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
        {
            scenes = scenes,
            locationPathName = output,
            target = BuildTarget.Android,
            options = BuildOptions.None
        });
        Debug.Log($"Build Android: {report.summary.result}; erros: {report.summary.totalErrors}; APK: {output}");
        if (report.summary.result != BuildResult.Succeeded)
            throw new Exception("Build Android falhou. Consulte o log completo.");
    }
}
