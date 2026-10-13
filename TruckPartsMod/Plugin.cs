using BepInEx;
using BepInEx.Configuration;
using BepInEx.Unity.IL2CPP;
using HarmonyLib;

[BepInPlugin("local.truckful.truckparts", "Truckful Truck Parts", "1.1.0")]
public sealed class TruckPartsPlugin : BasePlugin
{
    internal static ConfigEntry<bool> UnlockAllParts;
    internal static ConfigEntry<bool> AllPartsPurchased;
    internal static ConfigEntry<bool> RamAlwaysActive;
    internal static ConfigEntry<bool> SnorkelAlwaysActive;

    public override void Load()
    {
        UnlockAllParts = Config.Bind("Parts", "UnlockAllParts", true,
            "Make all truck parts available to buy. Restart the game after editing.");
        AllPartsPurchased = Config.Bind("Parts", "AllPartsPurchased", false,
            "Treat all truck parts as purchased and ready to equip without payment. Also unlocks them. Runtime only; equipping still saves your truck configuration. Restart after editing.");
        RamAlwaysActive = Config.Bind("Skills", "RamAlwaysActive", false,
            "Use normal ram collision behavior without equipping a ram. Restart after editing.");
        SnorkelAlwaysActive = Config.Bind("Skills", "SnorkelAlwaysActive", false,
            "Use the truck's normal snorkel intake without equipping a snorkel. Does not prevent drowning above snorkel height. Restart after editing.");
        new Harmony("local.truckful.truckparts").PatchAll(typeof(TruckPartsPlugin).Assembly);
        Log.LogInfo($"Truck parts loaded: unlock all {UnlockAllParts.Value}, purchased {AllPartsPurchased.Value}, ram {RamAlwaysActive.Value}, snorkel {SnorkelAlwaysActive.Value}.");
    }
}

[HarmonyPatch(typeof(SkillsController), "OnSkillsChanged")]
internal static class AlwaysRamPatch
{
    internal static void Postfix()
    {
        // The game's setup refresh resets this flag from the equipped skill slots.
        if (TruckPartsPlugin.RamAlwaysActive.Value) DestructableEnviro.IsUsingRam = true;
    }
}

[HarmonyPatch(typeof(SnorkelSkill), "SetActiveInSetup")]
internal static class AlwaysSnorkelPatch
{
    internal static void Prefix(ref bool __0)
    {
        if (TruckPartsPlugin.SnorkelAlwaysActive.Value) __0 = true;
    }
}

[HarmonyPatch(typeof(SnorkelSkill), "Start")]
internal static class InitializeSnorkelPatch
{
    internal static void Postfix(SnorkelSkill __instance)
    {
        if (TruckPartsPlugin.SnorkelAlwaysActive.Value && !SnorkelSkill.SnorkelIsActive)
            __instance.SetActiveInSetup(true, null, null);
    }
}

[HarmonyPatch(typeof(CarPart), "get_IsUnlocked")]
internal static class UnlockPartsPatch
{
    internal static bool Prefix(ref bool __result)
    {
        if (!TruckPartsPlugin.UnlockAllParts.Value && !TruckPartsPlugin.AllPartsPurchased.Value) return true;
        __result = true;
        return false;
    }
}

[HarmonyPatch(typeof(CarPart), "get_IsAvailableInShop")]
internal static class AvailablePartsPatch
{
    internal static bool Prefix(ref bool __result)
        => UnlockPartsPatch.Prefix(ref __result);
}

[HarmonyPatch(typeof(CarPart), "get_IsBought")]
internal static class PurchasedPartsPatch
{
    internal static bool Prefix(ref bool __result)
    {
        if (!TruckPartsPlugin.AllPartsPurchased.Value) return true;
        __result = true;
        return false;
    }
}
