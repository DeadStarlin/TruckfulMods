$ErrorActionPreference = 'Stop'
$stubs = @'
namespace BepInEx { public class BepInPlugin : System.Attribute { public BepInPlugin(string a,string b,string c) {} } }
namespace BepInEx.Configuration {
 public class ConfigEntry<T> { public T Value; }
 public class ConfigDescription { public ConfigDescription(string s,object o) {} }
 public class AcceptableValueRange<T> { public AcceptableValueRange(T a,T b) {} }
 public class ConfigFile { public ConfigEntry<T> Bind<T>(string s,string k,T v,object d) { return new ConfigEntry<T>{Value=v}; } }
}
namespace BepInEx.Unity.IL2CPP {
 public class BasePlugin { public BepInEx.Configuration.ConfigFile Config=new BepInEx.Configuration.ConfigFile(); public Logger Log=new Logger(); public virtual void Load() {} }
 public class Logger { public void LogInfo(string s) {} }
}
namespace HarmonyLib { public class HarmonyPatch:System.Attribute { public HarmonyPatch(System.Type t,string s) {} } public class Harmony { public Harmony(string s) {} public void PatchAll(System.Reflection.Assembly a) {} } }
namespace UnityEngine {
 public class Object { public bool Destroyed; public static void Destroy(Object o) {o.Destroyed=true;} }
 public enum PhysicsMaterialCombine {Average, Maximum}
 public class PhysicsMaterial:Object { public float staticFriction=0.5f,dynamicFriction=0.5f; public PhysicsMaterialCombine frictionCombine; }
 public class Collider { public bool isTrigger; public PhysicsMaterial material=new PhysicsMaterial(); public PhysicsMaterial sharedMaterial; }
}
public class PackageIdentifier { public System.IntPtr Pointer; public UnityEngine.Collider[] Colliders; public UnityEngine.Collider[] GetComponentsInChildren<T>(bool b) {return Colliders;} }
public class StickyCargoSkill {public System.IntPtr Pointer; public int Count; public void StartHiddenStickyCargo(){Count++;} public void EndHiddenStickyCargo(){Count--;} }
public static class CargoTests {
 static void Check(bool b){if(!b)throw new System.Exception("Cargo test failed");}
 public static void Run(){
  new CargoStickinessPlugin().Load();
  var solid=new UnityEngine.Collider(); var trigger=new UnityEngine.Collider{isTrigger=true};
  var p=new PackageIdentifier{Pointer=new System.IntPtr(1),Colliders=new[]{solid,trigger}};
  CargoFrictionPatch.Postfix(p); Check(solid.material.staticFriction==1.5f && solid.material.dynamicFriction==1.5f && trigger.material.staticFriction==0.5f);
  Check(solid.material.frictionCombine==UnityEngine.PhysicsMaterialCombine.Maximum);
  CargoMaterialCleanupPatch.Postfix(p); Check(solid.material.Destroyed && !trigger.material.Destroyed && CargoStickinessPlugin.Materials.Count==0);
  CargoStickinessPlugin.Friction.Value=1; solid=new UnityEngine.Collider(); p.Colliders=new[]{solid}; CargoFrictionPatch.Postfix(p); Check(solid.sharedMaterial==null && CargoStickinessPlugin.Materials.Count==0);
  var skill=new StickyCargoSkill{Pointer=new System.IntPtr(2)}; EnableGluePatch.Postfix(skill); Check(skill.Count==0);
  CargoStickinessPlugin.AlwaysGlue.Value=true; EnableGluePatch.Postfix(skill); EnableGluePatch.Postfix(skill); Check(skill.Count==1);
  skill.Count++; DisableGluePatch.Prefix(skill); DisableGluePatch.Prefix(skill); Check(skill.Count==1 && CargoStickinessPlugin.Glued.Count==0);
  EnableGluePatch.Postfix(skill); Check(skill.Count==2); DisableGluePatch.Prefix(skill);
 }
}
'@
Add-Type -TypeDefinition ((Get-Content (Join-Path $PSScriptRoot 'Plugin.cs') -Raw) + $stubs)
[CargoTests]::Run()
'Passed: friction scaling/bounds, trigger exclusion, material cleanup, vanilla mode, optional glue, duplicate callbacks, re-enable and preservation of other glue users.'
