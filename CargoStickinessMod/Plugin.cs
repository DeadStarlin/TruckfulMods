using System;
using System.Collections.Generic;
using BepInEx;
using BepInEx.Configuration;
using BepInEx.Unity.IL2CPP;
using HarmonyLib;
using UnityEngine;

[BepInPlugin("local.truckful.cargostickiness", "Truckful Cargo Stickiness", "1.0.0")]
public sealed class CargoStickinessPlugin : BasePlugin
{
    internal static ConfigEntry<float> Friction;
    internal static ConfigEntry<bool> AlwaysGlue;
    internal static readonly HashSet<IntPtr> Glued = new HashSet<IntPtr>();
    internal static readonly Dictionary<IntPtr, List<PhysicsMaterial>> Materials = new Dictionary<IntPtr, List<PhysicsMaterial>>();

    public override void Load()
    {
        Friction = Config.Bind("Cargo", "FrictionMultiplier", 3f,
            new ConfigDescription("1 = original friction; 3 = more grip; 0 = slippery. Restart after editing. Friction reduces sliding, but cannot prevent bouncing or tipping.", new AcceptableValueRange<float>(0f, 10f)));
        AlwaysGlue = Config.Bind("Cargo", "AlwaysGlue", false,
            "Keep the game's hidden sticky cargo ability active. Stronger retention than friction; no ability charge required. Restart after editing.");
        if (Scale(0.5f, 3f) != 1.5f || Scale(0.5f, 1f) != 0.5f ||
            Scale(0.5f, 0f) != 0f || Scale(0.5f, float.NaN) != 0.5f ||
            Scale(0.5f, float.PositiveInfinity) != 0.5f || Scale(0.5f, -1f) != 0f ||
            Scale(0.5f, 20f) != 5f)
            throw new InvalidOperationException("Cargo friction self-check failed.");
        new Harmony("local.truckful.cargostickiness").PatchAll(typeof(CargoStickinessPlugin).Assembly);
        Log.LogInfo($"Cargo stickiness loaded: friction x{Friction.Value}, permanent glue {AlwaysGlue.Value}.");
    }

    internal static float Scale(float value, float multiplier)
        => value * (float.IsNaN(multiplier) || float.IsInfinity(multiplier) ? 1f : Math.Max(0f, Math.Min(10f, multiplier)));
}

[HarmonyPatch(typeof(PackageIdentifier), "Awake")]
internal static class CargoFrictionPatch
{
    internal static void Postfix(PackageIdentifier __instance)
    {
        if (CargoStickinessPlugin.Friction.Value == 1f) return;
        var owned = new List<PhysicsMaterial>();
        CargoStickinessPlugin.Materials[__instance.Pointer] = owned;
        foreach (var collider in __instance.GetComponentsInChildren<Collider>(true))
        {
            if (collider == null || collider.isTrigger) continue;
            // Unity's material getter clones the shared asset for this collider.
            var material = collider.material;
            if (material == null) continue;
            owned.Add(material);
            material.staticFriction = CargoStickinessPlugin.Scale(material.staticFriction, CargoStickinessPlugin.Friction.Value);
            material.dynamicFriction = CargoStickinessPlugin.Scale(material.dynamicFriction, CargoStickinessPlugin.Friction.Value);
            if (CargoStickinessPlugin.Friction.Value > 1f) material.frictionCombine = PhysicsMaterialCombine.Maximum;
            collider.sharedMaterial = material;
        }
    }
}

[HarmonyPatch(typeof(PackageIdentifier), "OnDestroy")]
internal static class CargoMaterialCleanupPatch
{
    internal static void Postfix(PackageIdentifier __instance)
    {
        if (!CargoStickinessPlugin.Materials.TryGetValue(__instance.Pointer, out var materials)) return;
        foreach (var material in materials)
            if (material != null) UnityEngine.Object.Destroy(material);
        CargoStickinessPlugin.Materials.Remove(__instance.Pointer);
    }
}

[HarmonyPatch(typeof(StickyCargoSkill), "OnEnable")]
internal static class EnableGluePatch
{
    internal static void Postfix(StickyCargoSkill __instance)
    {
        if (!CargoStickinessPlugin.AlwaysGlue.Value || CargoStickinessPlugin.Glued.Contains(__instance.Pointer)) return;
        __instance.StartHiddenStickyCargo();
        CargoStickinessPlugin.Glued.Add(__instance.Pointer);
    }
}

[HarmonyPatch(typeof(StickyCargoSkill), "OnDisable")]
internal static class DisableGluePatch
{
    internal static void Prefix(StickyCargoSkill __instance)
    {
        if (CargoStickinessPlugin.Glued.Remove(__instance.Pointer)) __instance.EndHiddenStickyCargo();
    }
}



