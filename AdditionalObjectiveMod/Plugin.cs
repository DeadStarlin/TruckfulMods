using BepInEx;
using BepInEx.Unity.IL2CPP;
using HarmonyLib;

[BepInPlugin("local.truckful.additionalobjective", "Truckful Additional Objective", "1.0.0")]
public sealed class AdditionalObjectivePlugin : BasePlugin
{
    public override void Load()
    {
        new Harmony("local.truckful.additionalobjective").PatchAll(typeof(AdditionalObjectivePlugin).Assembly);
        Log.LogInfo("Additional objective patch loaded: medal goals pass even when their requirements fail.");
    }
}

[HarmonyPatch(typeof(MissionLog), nameof(MissionLog.GoalIsMet))]
internal static class MedalGoalPatch
{
    internal static void Postfix(MissionGoal __0, string __1, MissionKeeperState __2, ref bool __result)
    {
        if (__result || __0 == null || string.IsNullOrEmpty(__1)) return;
        if (__2 != MissionKeeperState.Active && __2 != MissionKeeperState.Complete
            && __2 != MissionKeeperState.CompleteAndReplayed) return;

        var config = ContentManager.ProgressionLogic?.GetMission(__1)?.Config;
        if (config == null || config.MedalGoal == null) return;

        // IL2CPP can wrap the same native goal in different managed objects.
        if (__0.Pointer == config.MedalGoal.Pointer
            && (config.BasicGoal == null || __0.Pointer != config.BasicGoal.Pointer))
            __result = true;
    }
}
