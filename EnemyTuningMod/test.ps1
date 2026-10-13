$ErrorActionPreference = 'Stop'
# Exercise the actual patch source without starting Unity or native detours.
$stubs = @'
namespace BepInEx {
    public class BepInPlugin : System.Attribute { public BepInPlugin(string id, string name, string version) {} }
}
namespace BepInEx.Configuration {
    public class ConfigEntry<T> { public T Value; }
    public class ConfigDescription { public ConfigDescription(string text, object range) {} }
    public class AcceptableValueRange<T> { public AcceptableValueRange(T min, T max) {} }
    public class ConfigFile { public ConfigEntry<T> Bind<T>(string section, string key, T value, ConfigDescription description) { return new ConfigEntry<T> { Value = value }; } }
}
namespace BepInEx.Unity.IL2CPP {
    public class BasePlugin { public BepInEx.Configuration.ConfigFile Config = new BepInEx.Configuration.ConfigFile(); public TestLogger Log = new TestLogger(); public virtual void Load() {} }
    public class TestLogger { public void LogInfo(string message) {} }
}
namespace HarmonyLib {
    public class HarmonyPatch : System.Attribute { public HarmonyPatch(System.Type type, string method) {} }
    public class Harmony { public Harmony(string id) {} public void PatchAll(System.Reflection.Assembly assembly) {} }
}
public class AICarController {}
public class AITrainController { public SplineFollower[] ChassisSplineFollowers; }
public class SplineFollower { public System.IntPtr Pointer; }
public class BossSpawner { public enum BasicBossType { Car, Train } public BasicBossType BossType; public float BossSpawnPercentage; }
public static class PatchTests {
    static void Equal(float actual, float expected) { if (System.Math.Abs(actual - expected) > 0.0001f || float.IsNaN(actual)) throw new System.Exception(actual + " != " + expected); }
    public static void Run() {
        new EnemyTuningPlugin().Load();
        float speed = 100; TruckSpeedPatch.Postfix(ref speed); Equal(speed, 50);
        Equal(EnemyTuningPlugin.Scale(100, 0), 0);
        Equal(EnemyTuningPlugin.Scale(100, 1), 100);
        Equal(EnemyTuningPlugin.Scale(100, -1), 0);
        Equal(EnemyTuningPlugin.Scale(100, 2), 100);
        Equal(EnemyTuningPlugin.Scale(100, float.NaN), 100);
        Equal(EnemyTuningPlugin.Scale(100, float.PositiveInfinity), 100);
        var follower = new SplineFollower { Pointer = new System.IntPtr(1) };
        var train = new AITrainController { ChassisSplineFollowers = new[] { follower, null } };
        RegisterTrainPatch.Postfix(train); RegisterSpawnedTrainPatch.Postfix(train);
        float dt = 1; TrainSpeedPatch.Prefix(follower, ref dt); Equal(dt, 0.5f);
        dt = 1; TrainSpeedPatch.Prefix(new SplineFollower { Pointer = new System.IntPtr(2) }, ref dt); Equal(dt, 1);
        UnregisterTrainPatch.Prefix(train);
        dt = 1; TrainSpeedPatch.Prefix(follower, ref dt); Equal(dt, 1);
        RegisterTrainPatch.Postfix(new AITrainController());
        EnemyTuningPlugin.TruckChance.Value = 0.5f;
        EnemyTuningPlugin.TrainChance.Value = 0;
        var spawner = new BossSpawner { BossSpawnPercentage = 80 };
        for (int i = 0; i < 3; i++) {
            float original; EncounterChancePatch.Prefix(spawner, out original); Equal(spawner.BossSpawnPercentage, 40);
            var error = new System.Exception("test");
            if (EncounterChancePatch.Finalizer(spawner, original, error) != error) throw new System.Exception("Exception swallowed");
            Equal(spawner.BossSpawnPercentage, 80);
        }
        spawner.BossType = BossSpawner.BasicBossType.Train;
        float state; EncounterChancePatch.Prefix(spawner, out state); Equal(spawner.BossSpawnPercentage, 0);
        EncounterChancePatch.Finalizer(spawner, state, null); Equal(spawner.BossSpawnPercentage, 80);
    }
}
'@
Add-Type -TypeDefinition ((Get-Content (Join-Path $PSScriptRoot 'Plugin.cs') -Raw) + $stubs)
[PatchTests]::Run()
Write-Output 'Passed: speed defaults/bounds, train-only movement, cleanup, separate encounter settings, repeated triggers and exception restoration.'
