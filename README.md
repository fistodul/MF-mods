# Mobile Forces Mod Repository (MF-mods)

Comprehensive modding repository, custom gamemodes, weapons, mutators, and decompiled engine reference for **Mobile Forces** (Rage Software, 2002 — Unreal Engine 1.5 hybrid). [![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/fistodul/MF-mods)

---

## 1. Installation & Repository Setup

To build mods, run tests, and allow AI coding agents to reference the engine accurately, **this repository must be cloned directly into your root Mobile Forces game directory**:

```text
<SteamLibrary>/steamapps/common/Mobile Forces/
│   Tracked in this repo:
├── AGENTS.md  <- Always-on AI agent rules (Quick Rules)
├── .agents/rules/  <- Detailed engine guide split by topic + caveman response style
├── .agents/tools/maptool/  <- Scripted map building in Python: T3D export/survey, editor macro runner (maps 10)
├── CoopMode/ KOH/ TugGame/ ZombieGame/  <- Custom gamemodes
├── Molotov/ PredatorMissile/ SeekerMines/ SentryGun/ Totem/ TripLasers/  <- Custom weapons & items
├── ArmedAPC/  <- Custom vehicles
├── README.md, LICENSE, .gitignore
│
│   Local only (not tracked):
├── Core/ Engine/ Rage/ RageWeapons/ RageGame/ ...  <- Decompiled base game classes (section 2B)
├── arenaMode/ battleRoyale/ mutPack/ ...  <- Decompiled third-party packages (section 2D)
├── MF-updater/  <- Separate repository (section 2A)
├── Maps/ Textures/ Sounds/ Music/  <- Game assets
└── System/  <- UCC compiler, game binaries, configs (.ini) and compiled packages (.u)
```

### Why clone into the game root?
1. **UCC Make Requirements**: The UnrealScript compiler (`System/UCC.exe make`) requires package source directories (`<PackageName>/Classes/*.uc`) to exist directly in the game root.
2. **Engine Reference for Developers & AI Agents**: Having the decompiled core packages (`Core`, `Engine`, `Rage`, `RageWeapons`, `RageGame`, etc.) in the root enables human coders and AI agents (Antigravity, Cursor, Claude, Copilot) to inspect exact engine variables, replication rules, and native functions without guessing.
3. **Integrated Tooling**: Gives immediate access to `MF-updater` and `System/` binaries.

### Linux / Wine Setup Tip (Symlink)
Steam installs the game into a directory with a space: `'Mobile Forces'`. To prevent path-escaping issues in shells or tools:
```bash
cd "<SteamLibrary>/steamapps/common"
ln -s "Mobile Forces" MobileForces
```

---

## 2. Companion Repositories & Engine References

### A. Companion Repository: `MF-updater`
**`MF-updater`** is a **separate, independent repository** ([github.com/fistodul/MF-updater](https://github.com/fistodul/MF-updater)) that is listed in `.gitignore` and not committed into `MF-mods`.
- It is a Python/Bash tool used to download and synchronize official and community fast-download assets (maps, textures, sounds, and server binaries) directly into your game folder.
- To set it up in your game root:
  ```bash
  git clone https://github.com/fistodul/MF-updater.git
  ```
  See `MF-updater/README.md` for standalone updater usage and fast-download server configuration.

---

### B. Decompiling Base Game Classes (Reference Sources for Agents & Humans)
Decompiling the base game generates hundreds of `.uc` files across the core engine packages (`Core`, `Engine`, `Rage`, `RageWeapons`, etc.). To handle this cleanly, `*.uc` is globally ignored in `.gitignore`:
1. **Prevents Copyright Pollution**: Commercial base game sources are kept local and not committed to git.
2. **Eliminates Git Clutter**: Prevents `git status`, diff viewers, and commit logs from being flooded with thousands of unmodified engine classes while you develop.

To give yourself and your AI coding agents (Antigravity, Cursor, Claude) full visibility into the engine hierarchy, native formulas, vehicle physics, and replication logic, **you should decompile the base game `.u` packages once after installation**:

Open each of these packages from `System/` in the Mobile Forces editor, [UE Explorer](https://eliotvu.com/portfolio/view/21/ue-explorer) or WOTgreal, and export it into `<Package>/Classes/`:

`Core` `Engine` `Editor` `UWindow` `Fire` `IpDrv` `IpServer` `UBrowser` `RageGfx` `RageEffects` `RageWeapons` `Rage` `RageGame` `RageMenu` `RageBrowser`

Every class in these packages has its script, so a full export gives one `.uc` per class (`Rage` has 169, `Engine` 104).

> Don't use `UCC.exe batchexport` for this. It stops on `Core`, `Engine`, `Editor`, `IpDrv` and `Rage` with `Assertion failed: Class->ScriptText` before writing any file, so those five, the most useful ones, come out empty.

Once decompiled, the base game sources are available locally:
- `Core/Classes/`: Low-level Unreal objects, primitives, and math.
- `Engine/Classes/`: `Actor`, `Pawn`, `PlayerPawn`, `EnginePhysical`, `Inventory`, `Weapon`, network replication.
- `Rage/Classes/`: `RagePlayer`, vehicles (`Vehicle`, `Car`, `Buggy`), zones, loadout crates.
- `RageWeapons/Classes/`: `RageWeapon`, `AdrenalineShot`, `Grenades`, `TripBombs`, weapon animations.
- `RageGame/Classes/`: `RageDeathMatch`, `RageTeamGame`, captains, beacons.

---

### C. Custom Mods (Tracked in Git)
Only these packages are developed in this repository; their `.uc` files are whitelisted in `.gitignore`:
- **Gamemodes**
  - `ZombieGame/`: Infection gamemode with custom zombie classes, nemesis mechanics, and melee weapons.
  - `TugGame/`: Tug of war team gamemode.
  - `KOH/`: King of the Hill, multi-point domination.
  - `CoopMode/`: Coop mode built on CTF.
- **Weapons & items**
  - `PredatorMissile/`: Player-guided nuclear missile terminal.
  - `SeekerMines/`: Drone mine with autonomous tracking.
  - `SentryGun/`: Deployable defensive auto-turret.
  - `TripLasers/`: Directional laser tripwire explosives.
  - `Molotov/`: Grenade that leaves a burning fire area.
  - `Totem/`: Tactical restoration stim & passive cheat-death item.
- **Vehicles**
  - `ArmedAPC/`: APC whose roof gunner aims a heavy machine gun (`ArmedAPC`) or rocket launcher (`ArmedAPCRocket`) turret with the camera.

### D. Third-Party Packages (Decompiled, Not Tracked)
Other source folders in the game root, such as `arenaMode/`, `battleRoyale/`, `mutPack/`, `TurboCars/`, `MoBall/`, `jeep/`, `boat/`, `deagle/`, `grenLaunch/` and `vote*/`, are **decompiled community packages**, not part of this repository. They're useful as reference.
- Changes to them are not version-controlled, since `*.uc` is ignored outside the whitelist.
- Recompiling one (e.g. `arenaMode`, which is in `EditPackages`) produces a new package GUID. Every server and client then needs that exact `.u`; clients with the original package get a version mismatch.

---

## 3. How to Build & Compile Mods

### A. Register Your Package
Before compiling a new mod, register it in `System/MobileForces.ini` under `[Editor.EditorEngine]`. 

> **Important**: Packages compile sequentially from top to bottom. Always add new mods at the **bottom** of the `EditPackages` list:

```ini
[Editor.EditorEngine]
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
EditPackages=ZombieGame
EditPackages=Totem
```

### B. Compile Commands
UCC will only compile a package if its compiled `.u` binary does **not** already exist in `System/`. Always remove the old binary before compiling:

**Linux / Wine**:
```bash
rm -f System/<PackageName>.u && wine System/UCC.exe make -nobind
```

**Windows (PowerShell)**:
```powershell
Remove-Item .\System\<PackageName>.u -ErrorAction SilentlyContinue
.\System\UCC.exe make -nobind
```

*(Use `-nobind` to prevent DLL binding issues during automated compilation).*

---

## 4. Rapid In-Game Testing

Run rapid test matches directly through Wine or the terminal:

**Test a custom gamemode**:
```bash
wine System/MobileForces.exe mf-polar?game=ZombieGame.ZombieGame?mutator=mutPack.AddWeaps
```

**Compile and immediately test in one command**:
```bash
rm -f System/ZombieGame.u && wine System/UCC.exe make -nobind && wine System/MobileForces.exe mf-polar?game=ZombieGame.ZombieGame
```

---

## 5. Standard Mod Package Structure

Every mod folder in the root follows the standard Unreal package structure:

```text
MyMod/
├── Classes/               # UnrealScript source files (.uc)
│   ├── MyModGame.uc
│   └── MyModWeapon.uc
├── Textures/              # .bmp / .pcx textures imported via #exec
└── Models/                # 3D meshes / skins imported via #exec
```

### Tracking Your New Mod in Git (`.gitignore` Whitelist)
Because `*.uc` is ignored globally by default to suppress decompiled engine noise, **git will not track your new mod's UnrealScript files automatically**.

To make your mod visible in `git status` and tracked by version control, add a whitelist exception to the bottom of [.gitignore](.gitignore). Only `*.uc` is ignored inside package folders, so a mod's `Textures/` and `Models/` are tracked without extra rules:

```gitignore
# Whitelist your mod in .gitignore:
!MyMod/**/*.uc
```

Once added, running `git status` will cleanly show only your mod's files ready to be committed:
```bash
git status
# Untracked files:
#   MyMod/Classes/MyModWeapon.uc
#   MyMod/Textures/my_icon.bmp
```

---

### Creating Custom Weapon HUD Icons
If your weapon needs a custom HUD icon:
1. Save artwork as a **Windows 3.x 8-bit Paletted BMP** (64×64 pixels, 5,174 bytes).
2. Palette index `0` **must be pure black `RGB(0, 0, 0)`** (used as transparent mask by `Flags=2`).
3. **The 20px Bottom Clearance Rule**: In `RageHUD`, the ammo quantity badge ("1", "2") covers the bottom ~20 pixels of each inventory slot. Position the icon artwork in `y = 4..43` (centered at `y ~ 24`), leaving **20-21 pixels of transparent space at the bottom**.
4. Import in your weapon class:
   ```unrealscript
   #exec TEXTURE IMPORT NAME=MyIcon FILE=Textures\my_icon.bmp GROUP=Icons MIPS=OFF Flags=2

   defaultproperties
   {
       WeaponIcon=(X=0,Y=0,W=64,H=64,t=Texture'MyMod.Icons.MyIcon')
   }
   ```

---

## 6. Architecture & Modding Guide for Agents & Humans

Agent documentation is split so coding assistants only load what they need:
- **[AGENTS.md](AGENTS.md)**: short always-on Quick Rules with an index of the guide files. Each rule points to a guide section.
- **[.agents/rules/](.agents/rules/)**: the full reference, split by topic (`architecture-build`, `networking`, `hud`, `loadout-consumables`, `gotchas`). These use [Antigravity rule](https://antigravity.google/docs/rules/) frontmatter with `trigger: model_decision`, so Antigravity loads one only when the task matches its description. Other agents find them through the index in `AGENTS.md`. Antigravity's rule editor limits a `description` to 250 characters and the content to 12,000; keep `: ` and quotes out of descriptions, since the editor shows them literally.
- **[.agents/rules/caveman.md](.agents/rules/caveman.md)**: the official always-on rule from the [caveman](https://github.com/JuliusBrussee/caveman) plugin for terse chat replies (`trigger: always_on`; code, commits and docs stay normal).

The guide covers:
  - Network replication realities (`ROLE_SimulatedProxy`, `bReplicateInstigator`, `ServerMove`, local-player checks).
  - Player-guided actors with client-to-server function calls (`PredatorMissile` pattern), and debugging through logs.
  - Single-use consumables lifecycle (`bDestroyWhenEmpty`, the human `Finish()` bug).
  - Loadout zone & crate triggers (`RW.Reload()` trap).
  - Engine traps: weapon state `Tick`s shadowing yours, freezing players, server-only `Level.Game`/`Level.PawnList`, vehicles living in `Level.VehicleList`.
  - UnrealScript compiler quirks & optimization (`GiveTo()` canceling timers, cast caching, short-circuiting).
