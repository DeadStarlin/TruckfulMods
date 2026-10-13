using System;
using System.Collections.Generic;
using BepInEx;
using BepInEx.Configuration;
using BepInEx.Unity.IL2CPP;
using HarmonyLib;

[BepInPlugin("local.truckful.enemytuning", "Truckful Enemy Tuning", "1.0.0")]
public sealed class EnemyTuningPlugin : BasePlugin
{
    internal static ConfigEntry<float> TruckSpeed, TrainSpeed, TruckChance, TrainChance;
    internal static readonly HashSet<IntPtr> TrainFollowers = new HashSet<IntPtr>();

    public override void Load()
    {
        TruckSpeed = Bind("Speed", "TruckMultiplier", 0.5f, "Enemy truck target speed. 0.5 = half speed; 1 = normal.");
        TrainSpeed = Bind("Speed", "TrainMultiplier", 0.5f, "Zombie train travel speed. Attack animation timing is unchanged.");
        TruckChance = Bind("Encounters", "TruckChanceMultiplier", 1f, "Multiply normal truck encounter probability. 0 = none; 0.5 = half; 1 = normal. Scripted spawns are unchanged.");
        TrainChance = Bind("Encounters", "TrainChanceMultiplier", 1f, "Multiply normal train encounter probability. 0 = none; 0.5 = half; 1 = normal. Scripted spawns are unchanged.");
        new Harmony("local.truckful.enemytuning").PatchAll(typeof(EnemyTuningPlugin).Assembly);
        Log.LogInfo("Enemy tuning loaded: configurable truck/train speed and encounter chance.");
    }

    private ConfigEntry<float> Bind(string section, string key, float value, string description)
        => Config.Bind(section, key, value, new ConfigDescription(description, new AcceptableValueRange<float>(0f, 1f)));

    internal static float Scale(float value, float multiplier)
        => value * (float.IsNaN(multiplier) || float.IsInfinity(multiplier) ? 1f : Math.Max(0f, Math.Min(1f, multiplier)));
}

[HarmonyPatch(typeof(AICarController), "get_EffectiveDesiredSpeedKMH")]
internal static class TruckSpeedPatch
{
    internal static void Postfix(ref float __result)
        => __result = EnemyTuningPlugin.Scale(__result, EnemyTuningPlugin.TruckSpeed.Value);
}

[HarmonyPatch(typeof(AITrainController), "Start")]
internal static class RegisterTrainPatch
{
    internal static void Postfix(AITrainController __instance)
    {
        if (__instance.ChassisSplineFollowers == null) return;
        foreach (var follower in __instance.ChassisSplineFollowers)
            if (follower != null) EnemyTuningPlugin.TrainFollowers.Add(follower.Pointer);
    }
}

[HarmonyPatch(typeof(AITrainController), "SetFollowerSplines")]
internal static class RegisterSpawnedTrainPatch
{
    internal static void Postfix(AITrainController __instance) => RegisterTrainPatch.Postfix(__instance);
}

[HarmonyPatch(typeof(AITrainController), "OnDestroy")]
internal static class UnregisterTrainPatch
{
    internal static void Prefix(AITrainController __instance)
    {
        if (__instance.ChassisSplineFollowers == null) return;
        foreach (var follower in __instance.ChassisSplineFollowers)
            if (follower != null) EnemyTuningPlugin.TrainFollowers.Remove(follower.Pointer);
    }
}

[HarmonyPatch(typeof(SplineFollower), "UpdateForTime")]
internal static class TrainSpeedPatch
{
    internal static void Prefix(SplineFollower __instance, ref float __0)
    {
        if (EnemyTuningPlugin.TrainFollowers.Contains(__instance.Pointer))
            __0 = EnemyTuningPlugin.Scale(__0, EnemyTuningPlugin.TrainSpeed.Value);
    }
}

[HarmonyPatch(typeof(BossSpawner), "OnTriggerEnter")]
internal static class EncounterChancePatch
{
    internal static void Prefix(BossSpawner __instance, out float __state)
    {
        __state = __instance.BossSpawnPercentage;
        var setting = __instance.BossType == BossSpawner.BasicBossType.Train
            ? EnemyTuningPlugin.TrainChance : EnemyTuningPlugin.TruckChance;
        __instance.BossSpawnPercentage = EnemyTuningPlugin.Scale(__state, setting.Value);
    }

    // Restore even if the game's trigger handler throws; repeated entries must not compound.
    internal static Exception Finalizer(BossSpawner __instance, float __state, Exception __exception)
    {
        __instance.BossSpawnPercentage = __state;
        return __exception;
    }
}
