$ErrorActionPreference = 'Stop'
# Compile the actual patch against small stand-ins; no game or native runtime is needed.
$stubs = @'
namespace BepInEx {
    public class BepInPlugin : System.Attribute { public BepInPlugin(string id, string name, string version) {} }
}
namespace BepInEx.Unity.IL2CPP {
    public class BasePlugin { public TestLogger Log = new TestLogger(); public virtual void Load() {} }
    public class TestLogger { public void LogInfo(string value) {} }
}
namespace HarmonyLib {
    public class HarmonyPatch : System.Attribute { public HarmonyPatch(System.Type type, string name) {} }
    public class Harmony { public Harmony(string id) {} public void PatchAll(System.Reflection.Assembly assembly) {} }
}
public enum MissionKeeperState { Hidden, RevealedInJournal, Active, Complete, CompleteAndReplayed }
public class MissionGoal { public System.IntPtr Pointer; }
public class MissionConfig { public MissionGoal MedalGoal, BasicGoal; }
public class MissionKeeper { public MissionConfig Config; }
public class MissionLog { public bool GoalIsMet() { return false; } }
public class ProgressionLogic { public MissionKeeper Mission; public MissionKeeper GetMission(string id) { return id == "test" ? Mission : null; } }
public static class ContentManager { public static ProgressionLogic ProgressionLogic; }
public static class PatchTests {
    static void Check(MissionGoal goal, string id, MissionKeeperState state, bool original, bool expected) {
        bool result = original;
        MedalGoalPatch.Postfix(goal, id, state, ref result);
        if (result != expected) throw new System.Exception("Patch regression: " + id + "/" + state);
    }
    public static void Run() {
        var basic = new MissionGoal { Pointer = new System.IntPtr(1) };
        var medal = new MissionGoal { Pointer = new System.IntPtr(2) };
        var config = new MissionConfig { BasicGoal = basic, MedalGoal = medal };
        ContentManager.ProgressionLogic = new ProgressionLogic { Mission = new MissionKeeper { Config = config } };
        foreach (MissionKeeperState state in System.Enum.GetValues(typeof(MissionKeeperState))) {
            bool eligible = state == MissionKeeperState.Active || state == MissionKeeperState.Complete || state == MissionKeeperState.CompleteAndReplayed;
            Check(medal, "test", state, false, eligible);
            Check(basic, "test", state, false, false);
            Check(medal, "test", state, true, true);
        }
        Check(new MissionGoal { Pointer = medal.Pointer }, "test", MissionKeeperState.Active, false, true);
        Check(basic, "test", MissionKeeperState.Active, true, true);
        Check(null, "test", MissionKeeperState.Active, false, false);
        Check(medal, null, MissionKeeperState.Active, false, false);
        Check(medal, "missing", MissionKeeperState.Active, false, false);
        config.BasicGoal = medal;
        Check(medal, "test", MissionKeeperState.Active, false, false);
        config.MedalGoal = null;
        Check(medal, "test", MissionKeeperState.Active, false, false);
        ContentManager.ProgressionLogic = null;
        Check(medal, "test", MissionKeeperState.Active, false, false);
    }
}
'@
Add-Type -TypeDefinition ((Get-Content (Join-Path $PSScriptRoot 'Plugin.cs') -Raw) + $stubs)
[PatchTests]::Run()
Write-Output 'Passed: medal failure override, basic goals, mission states, native identity, and missing-data guards.'
