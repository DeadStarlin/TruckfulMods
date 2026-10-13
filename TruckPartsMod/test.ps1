$ErrorActionPreference = 'Stop'
$stubs = @"
namespace BepInEx { public class BepInPlugin:System.Attribute { public BepInPlugin(string a,string b,string c){} } }
namespace BepInEx.Configuration {
 public class ConfigEntry<T> { public T Value; }
 public class ConfigFile { public ConfigEntry<T> Bind<T>(string s,string k,T v,string d) => new ConfigEntry<T>{Value=v}; }
}
namespace BepInEx.Unity.IL2CPP {
 public class BasePlugin { public BepInEx.Configuration.ConfigFile Config=new BepInEx.Configuration.ConfigFile(); public Logger Log=new Logger(); public virtual void Load(){} }
 public class Logger { public void LogInfo(string s){} }
}
namespace HarmonyLib {
 public class HarmonyPatch:System.Attribute { public HarmonyPatch(System.Type t,string s){} }
 public class Harmony { public Harmony(string s){} public void PatchAll(System.Reflection.Assembly a){} }
}
public class CarPart {}
public class SkillsController {}
public class DestructableEnviro { public static bool IsUsingRam; }
public class SnorkelSkill {
 public static bool SnorkelIsActive;
 public int Activations;
 public void SetActiveInSetup(bool active, object setting, object instance) { SnorkelIsActive=active; Activations++; }
}
public static class PartsTests {
 public static void Run() {
  new TruckPartsPlugin().Load();
  foreach(bool unlock in new[]{false,true}) foreach(bool bought in new[]{false,true}) foreach(bool original in new[]{false,true}) {
   TruckPartsPlugin.UnlockAllParts.Value=unlock; TruckPartsPlugin.AllPartsPurchased.Value=bought;
   bool result=original; bool run=UnlockPartsPatch.Prefix(ref result);
   Check(run==!(unlock||bought) && result==(original||unlock||bought));
   result=original; run=AvailablePartsPatch.Prefix(ref result);
   Check(run==!(unlock||bought) && result==(original||unlock||bought));
   result=original; run=PurchasedPartsPatch.Prefix(ref result);
   Check(run==!bought && result==(original||bought));
  }
  foreach(bool enabled in new[]{false,true}) foreach(bool original in new[]{false,true}) {
   TruckPartsPlugin.RamAlwaysActive.Value=enabled;
   DestructableEnviro.IsUsingRam=original; AlwaysRamPatch.Postfix();
   Check(DestructableEnviro.IsUsingRam==(enabled||original));
   TruckPartsPlugin.SnorkelAlwaysActive.Value=enabled;
   bool active=original; AlwaysSnorkelPatch.Prefix(ref active);
   Check(active==(enabled||original));
   SnorkelSkill.SnorkelIsActive=original;
   var snorkel=new SnorkelSkill(); InitializeSnorkelPatch.Postfix(snorkel);
   Check(SnorkelSkill.SnorkelIsActive==(enabled||original));
   Check(snorkel.Activations==((enabled&&!original)?1:0));
   InitializeSnorkelPatch.Postfix(snorkel);
   Check(snorkel.Activations==((enabled&&!original)?1:0));
  }
 }
 static void Check(bool value) { if(!value) throw new System.Exception("Parts config test failed"); }
}
"@
Add-Type -TypeDefinition ((Get-Content (Join-Path $PSScriptRoot 'Plugin.cs') -Raw) + $stubs)
[PartsTests]::Run()
'Passed: part config combinations, ram/snorkel enabled and disabled, equipped and unequipped states, repeated snorkel initialization preserves active equipment.'
