---
trigger: model_decision
description: Mobile Forces class hierarchy, compiling packages with UCC (EditPackages, rebuild steps) and the coding style of mature mods. Read before creating a package, changing the build, or writing or reviewing UnrealScript.
---

# Mobile Forces architecture & build

> Part of the Mobile Forces agent guide. Section numbers are shared across `.agents/rules/`; the index is in the root `AGENTS.md`.

---

## 1. Engine Heritage & Architecture

Mobile Forces (Rage Software, 2002) is built on an extensively modified **Unreal Engine 1 (build 436)** codebase, often referred to as UE 1.5:
- **Core Hierarchy**:
  - `Object` -> `Actor` -> `Pawn` -> `PlayerPawn` -> `RPlayer` -> `RagePlayer` -> `RagePlayerX` -> Mod Players (`ZombiePlayer`, `CoopPlayer`, etc.).
  - `Inventory` -> `Weapon` -> `RageWeapon` -> Mod Weapons (`TripBombs`, `PredatorMissileWeapon`, `ZombieKnife`, `Totem`, `SeekerMines`, etc.).
  - `GameInfo` -> `RageGameInfo` -> `RageDeathMatch` -> `RageTeamGame` -> Mod GameModes (`ZombieGame`, `TugGame`, `KOH`, etc.).
  - `HUD` -> `RageHUD` -> `RageTeamHUD` -> Mod HUDs (`ZombieHUD`, etc.).
- **Vehicle System**: Custom physics integration (`PHYS_Physical`, `Vehicle`, `Car`, `Armadillo`, `Buggy`, `Humvee`). Vehicles are `Pawn` subclasses (`Pawn` → `EnginePhysical` → `Physical` → `Vehicle`) but live in `Level.VehicleList`, not `Level.PawnList` (see 7J).
- **Particle System**: Native particle engine accessed via `Level.Particles.AddOne(...)` and static helpers in `RageEffects.RageEffect`.
- **Ammo System**: `RageWeapon` does **NOT** use vanilla UT `AmmoType` inventory classes. It manages ammo directly using `ClipAmmo`, `TotalAmmo`, `MaxClipAmmo`, and `MaxClips` on the weapon actor. Native UT code expecting `AmmoType` will fail or return `None`.
- **Package Compilation**: Engine uses `ucc make`. Every recompile gives a package a new GUID, so client and server must have the identical `.u`. A mismatch fails the connection unless the client can download the server's version (the community uses `MF-updater` / fast download).

---

## 8. Modding Setup & Build Workflow

### A. `MobileForces.ini` Package Dependency Hierarchy
Packages in `System/MobileForces.ini` compile sequentially under `[Editor.EditorEngine]`. A package can only access classes in packages listed **above** it:
```ini
EditPackages=Core
EditPackages=Engine
EditPackages=Editor
EditPackages=UWindow
EditPackages=Fire
EditPackages=IpDrv
EditPackages=IpServer
EditPackages=UBrowser
EditPackages=RageGfx
EditPackages=RageEffects
EditPackages=RageWeapons
EditPackages=Rage
EditPackages=RageGame
EditPackages=RageMenu
EditPackages=RageBrowser
...
EditPackages=MyCustomMod
```
- Never reorder the core packages.
- Always add new mods at the bottom of the `EditPackages` list.

### B. Standard Mod Directory Structure
Every package folder in the root must follow the Unreal package convention:
```text
MyMod/
├── Classes/
│   ├── MyModGame.uc
│   └── MyModWeapon.uc
├── Textures/           # .bmp / .pcx files imported via #exec
└── Models/             # 3D meshes / skins imported via #exec
```

### C. Reliable Compilation Commands
UCC only compiles a package if `System/<PackageName>.u` does not already exist.

- **Linux / Wine**:
  ```bash
  rm -f System/<PackageName>.u && wine System/UCC.exe make -nobind
  ```
- **Windows / PowerShell**: UCC parses its whole command line, including its own path, and splits it at the space in "Mobile Forces" (`Failed to find object 'Class Any.Forces\System\UCC.exe"'`). Run it from the 8.3 short path:
  ```powershell
  Remove-Item .\System\<PackageName>.u -ErrorAction SilentlyContinue
  $sys = (New-Object -ComObject Scripting.FileSystemObject).GetFolder("$PWD\System").ShortPath
  Start-Process "$sys\UCC.exe" -ArgumentList 'make -nobind' -WorkingDirectory $sys -Wait -NoNewWindow
  ```
- Use `-nobind` to prevent native DLL binding issues during automated compilation.
- Ensure 0 errors and 0 warnings before testing in-game.

---

## 9. Coding Style: The Mature Mod Standard (`ZombieGame`, `TripLasers`)

Mature mods in this repository adhere to these principles:

1. **Minimal & Deduplicated**:
   - Override only what differs and let `Super` do the rest. `ZombieGame` and `TripLasers` guard, wrap or post-process the parent call instead of copying its body:
     ```unrealscript
     function AddDefaultInventory(Pawn P)
     {
         if (IsOnTeam(P, 1))
             GiveMelee(P);
         else
             Super.AddDefaultInventory(P);
     }

     function bool RestartPlayer(Pawn P)
     {
         if (Super.RestartPlayer(P))
         {
             // mod-specific setup only
             return true;
         }
         return false;
     }
     ```
     Copy a parent body only when the part to change sits mid-function with no hook. Keep the copy to that one function and say why in a comment (e.g. `battleRoyale`'s marked edits of `RageDeathmatch.GiveWeapon`).
   - Avoid creating duplicate variables (e.g. `BaseSpeed` vs `Speed`, or duplicate state booleans).
   - Reuse engine variables (`Speed`, `MaxSpeed`, `Damage`, `MomentumTransfer`, `LifeSpan`) before inventing custom ones. For a max lifetime, set `LifeSpan` in `defaultproperties` instead of tracking `SpawnTime`; the engine destroys the actor on time, so put cleanup (beams, tripods) in `Destroyed()` (see `TripLaser`, `SeekerMine`, `SentryGunTurret`).
   - Remove unused locals and variables; UCC doesn't warn about them.
2. **Necessary Checks Only**:
   - Before adding a guard, read the engine path it protects against. Drop it if a called function, the parent class or the engine already covers it (e.g. `IsValidTarget(A)` already tests `A == None`).
   - `bDeleteMe` only matters for a reference held across ticks that might point to a destroyed actor (e.g. a stored target that still has `Health > 0` after its player disconnects, as in `RageTeamGame` and `SentryGunTurret.IsValidTarget`). Don't add it for harmless writes to a dying actor, or when the destroy path already cleans up: `Pawn.Destroyed` destroys all inventory, so a weapon's own `Destroyed()` handles owner disconnects.
   - `IsA('Name')` takes a plain name that the compiler never checks. Confirm `class Name` exists under `*/Classes` first. `IsA('Bot')` compiled fine but matched nothing, because MF has no `Bot` class. MF bots are `EngineBot` > `RBot` > `RageBot`.
   - Never assume `Instigator` exists on clients; fall back to `Owner`.
3. **Clean Weapon Lifecycle**:
   - When a consumable weapon runs out of ammo and is destroyed:
     - On server (`MissileDestroyed` / consumption):
       ```unrealscript
       PawnOwner.DeleteInventory(self);
       PawnOwner.SetSpeedFromInventory(); // see 7H
       PawnOwner.Weapon = None;
       PawnOwner.SwitchToBestWeapon();
       if (PawnOwner.PendingWeapon != None)
           PawnOwner.ChangedWeapon();
       Destroy();
       ```
     - On client (`simulated function Destroyed()`):
       ```unrealscript
       if (PP.Weapon == self)
       {
           PP.Weapon = None;
           PP.SwitchToBestWeapon();
       }
       ```
