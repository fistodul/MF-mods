# Mobile Forces Mod Repository (MF-mods)

Comprehensive modding repository, custom gamemodes, weapons, mutators, and decompiled engine reference for **Mobile Forces** (Rage Software, 2002 — Unreal Engine 1.5 hybrid).

---

## 1. Installation & Repository Setup

To build mods, run tests, and allow AI coding agents to reference the engine accurately, **this repository must be cloned directly into your root Mobile Forces game directory**:

```text
<SteamLibrary>/steamapps/common/Mobile Forces/   (or MobileForces/)
├── .agents/              <- AI Agent instructions & engine rules (AGENTS.md)
├── MF-updater/           <- Asset & fast-download updater tool
├── Core/                 <- Decompiled Engine 436 Core classes
├── Engine/               <- Decompiled Unreal Engine 1 classes
├── Rage/                 <- Decompiled MF Player, Physical, Vehicle classes
├── RageWeapons/          <- Decompiled MF base weapons & inventory classes
├── RageGame/             <- Decompiled MF game types & team classes
├── ZombieGame/           <- Custom Zombie Infection gamemode
├── Totem/                <- Custom Totem of Undying weapon/item
├── SeekerMines/          <- Custom autonomous drone mine weapon
├── TripLasers/           <- Custom laser tripwire explosive
├── Maps/                 <- Game map files (.umf)
├── Textures/             <- Game texture packages (.utx)
├── Sounds/               <- Game sound packages (.uax)
├── System/               <- UCC compiler, game binaries, and configs (.ini, .u)
└── README.md
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

#### Using `UCC.exe batchexport`:
Run the following from your game root to export all base classes into their respective `<Package>/Classes/` directories:

**Windows (cmd.exe / PowerShell)**:
```cmd
cd System
for %p in (Core Engine Editor UWindow Fire IpDrv IpServer UBrowser RageGfx RageEffects RageWeapons Rage RageGame RageMenu RageBrowser) do (
    mkdir ..\%p\Classes 2>nul
    UCC.exe batchexport %p.u class uc ..\%p\Classes
)
cd ..
```

**Linux / Wine (Bash)**:
```bash
cd System
for pkg in Core Engine Editor UWindow Fire IpDrv IpServer UBrowser RageGfx RageEffects RageWeapons Rage RageGame RageMenu RageBrowser; do
    mkdir -p "../$pkg/Classes"
    wine UCC.exe batchexport "$pkg.u" class uc "../$pkg/Classes"
done
cd ..
```

*(Alternatively, you can open any `.u` file in the Mobile Forces editor, [UE Explorer](https://eliotvu.com/portfolio/view/21/ue-explorer), or WOTgreal and export classes).*

Once decompiled, all native sources will be available locally:
- `Core/Classes/`: Low-level Unreal objects, primitives, and math.
- `Engine/Classes/`: `Actor`, `Pawn`, `PlayerPawn`, `Inventory`, `Weapon`, network replication.
- `Rage/Classes/`: `RagePlayer`, vehicle physics (`PHYS_Physical`, `Car`, `Buggy`), zones, loadout crates.
- `RageWeapons/Classes/`: `RageWeapon`, `AdrenalineShot`, `Grenades`, `TripBombs`, weapon animations.
- `RageGame/Classes/`: `RageDeathMatch`, `RageTeamGame`, captains, beacons.

---

### C. Active Custom Mods (Tracked in Git)
The following custom mods are tracked and developed in this repository:
- `ZombieGame/`: Infection gamemode with custom zombie classes, nemesis mechanics, and melee weapons.
- `Totem/`: Tactical restoration stim & passive cheat-death item.
- `SeekerMines/`: Drone mine with autonomous tracking.
- `TripLasers/`: Directional laser tripwire explosives.
- `SentryGun/`: Deployable defensive auto-turret.
- `TugGame/`, `arenaMode/`, `battleRoyale/`: Additional custom gamemodes.

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

To make your mod visible in `git status` and tracked by version control, add a whitelist exception to the bottom of [.gitignore](.gitignore):

```gitignore
# Whitelist your mod in .gitignore:
!MyMod/**/*.uc
!MyMod/Textures/**
!MyMod/Models/**
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

For deep architectural details, networking rules, and engine traps, consult the guides in `.agents/`:
- **[.agents/AGENTS.md](.agents/AGENTS.md)**: Full reference covering:
  - Network replication realities (`ROLE_SimulatedProxy`, `bReplicateInstigator`, `ServerMove`).
  - Single-use consumables lifecycle (`bDestroyWhenEmpty`, the human `Finish()` bug).
  - Loadout zone & crate triggers (`RW.Reload()` trap).
  - UnrealScript compiler quirks & optimization (state transitions canceling timers, cast caching, short-circuiting).
- **[.agents/rules/mobile_forces_rules.md](.agents/rules/mobile_forces_rules.md)**: Concise engineering rules for coding assistants.
