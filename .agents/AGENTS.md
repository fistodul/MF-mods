# Mobile Forces (MF) & UnrealScript Engine Guide

> Comprehensive reference for engineering, modding, networking, HUD, loadouts, and physics in Mobile Forces (Rage Engine / UE 1.5 hybrid).

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
- **Package Compilation**: Engine uses `ucc make`. All compiled `.u` files must match **byte-for-byte** between client and dedicated server; any mismatch triggers network disconnection.

---

## 2. Multiplayer Networking & Replication Realities

### A. The `ROLE_SimulatedProxy` Trap (Why Projectiles Stop Moving on Clients)
In Unreal Engine 1 (`Engine.Actor` line 602):
```unrealscript
unreliable if( !bCarriedItem && VehicleIn == none && Physics != PHYS_Physical && (bNetInitial || bSimulatedPawn || RemoteRole<ROLE_SimulatedProxy) && Role==ROLE_Authority )
    Location;
unreliable if( !bCarriedItem && VehicleIn == none && Physics != PHYS_Physical && (DrawType==DT_Mesh || DrawType==DT_Brush) && (bNetInitial || bSimulatedPawn || RemoteRole<ROLE_SimulatedProxy) && Role==ROLE_Authority )
    Rotation;
```
- For actors with `RemoteRole == ROLE_SimulatedProxy` (default for projectiles):
  - `Location` and `Rotation` are **ONLY replicated in `bNetInitial`** (the first spawn packet).
  - The server **NEVER** sends updated `Location` or `Rotation` afterward.
- **Consequence**: If client script returns early from `simulated function Tick()` (e.g. `if (Role != ROLE_Authority) return;`), the client's actor will never turn or change velocity—it will fly along its initial spawn vector in a straight line forever!
- **Solution**:
  1. For player-guided actors (guided missiles): the owning client flies the actor in `simulated function Tick` and drives the server copy. See **2E**.
  2. For server-driven motion that other clients must see, replicate custom state (e.g. `var rotator replicatedRotation;` in the decompiled third-party `battleRoyale\platform.uc`, or `SrvLoc/SrvRot/SrvSpeed` in `PredatorMissile`) and apply it in client `Tick`, or use `RemoteRole = ROLE_DumbProxy`.

### B. `bReplicateInstigator` & Ownership
- By default in `Actor.uc`:
  ```unrealscript
  var bool bReplicateInstigator;
  unreliable if( bReplicateInstigator && (RemoteRole>=ROLE_SimulatedProxy) && (Role==ROLE_Authority) )
      Instigator;
  ```
- Because `bReplicateInstigator` defaults to `False`, **`Instigator` is `None` on clients**!
- If your projectile checks `PlayerPawn(Instigator)`, it will fail on clients unless:
  - You set `bReplicateInstigator = True` in `defaultproperties`.
  - Or you resolve via `Owner` (pass `Owner` in `Spawn(..., Owner)`—`Owner` is always replicated in `Actor.uc`).
  - Best practice:
    ```unrealscript
    GuidePawn = Pawn(Owner);
    if (GuidePawn == None)
        GuidePawn = Instigator;
    ```

### C. Client Input, `ServerMove` & Local Players
- The client sends player inputs to the server via `ServerMove(..., View, ...)`. On the server, `ServerMove` sets `ViewRotation` and `bFire`/`bAltFire`. Other clients never receive another player's `ViewRotation` or `bFire`.
- Decide "is this the machine the player sits at?" by the viewport, **not** by `NetMode`. A `NetMode != NM_DedicatedServer` check is wrong on listen servers with remote players:
  ```unrealscript
  simulated final function bool IsLocalPlayer(PlayerPawn PP)
  {
      return PP != None && PP.Player != None && PP.Player.IsA('Viewport');
  }
  ```
  True for standalone, the listen host's own pawn and the owning client. False on the server for remote pawns (`Player` is a `NetConnection`) and on clients for other players (`Player == None`).
- Never overwrite a remote player's `ViewRotation` on the server: it discards the `ServerMove` input arriving between packets.

### D. Preventing Double Effects & Explosion Lag
- If `bNetTemporary = False`, `simulated function Explode()` runs on **both** server and client.
- If explosion effects (`AddExplosionServer`, `AddVehicleExplosionServer`, `ExplosionGlobal`) are spawned by both, clients get double or quadruple particles, causing immense frame drops.
- **Rule**: Restrict gameplay impact (damage, scoring, server effects) to `Role == ROLE_Authority`. For a simple projectile, the client can just `Destroy()` locally:
  ```unrealscript
  if (Role != ROLE_Authority)
  {
      Destroy();
      return;
  }
  ```
- For guided or camera-carrying actors, do **not** `Destroy()` on a client-side hit: client and server paths differ slightly, and a local destroy drops the camera while the server copy keeps flying. Stop locally and let the server's `Destroy` arrive (see **2E**).

### E. Player-Guided Actors (Pattern Verified In-Game: `PredatorMissile`)
Server-steered missiles feel laggy, and correcting the client toward the server's path feels like different turning. Making the owning client authoritative gives exactly the single-player feel:
- **Client → server function calls work on a `ROLE_SimulatedProxy` projectile whose `Owner` is the client's `PlayerPawn`** (`Spawn(class, OwnerPawn, ...)`), verified in-game. Deeper Owner chains (actor owned by a weapon) should work per UE1's top-owner lookup but are untested:
  ```unrealscript
  replication
  {
      unreliable if (Role == ROLE_Authority && !bNetOwner)   // only clients that don't fly it
          SrvLoc, SrvRot, SrvSpeed;
      unreliable if (Role < ROLE_Authority)
          ServerSyncFlight;      // ~30 Hz: location, yaw/pitch as ints, speed
      reliable if (Role < ROLE_Authority)
          ServerImpact;          // client hit something: detonate there
  }
  ```
- **Guiding machine** (`IsLocalPlayer(PP)`): runs the singleplayer steering in `simulated Tick`, sets `PP.ViewRotation = Rotation` to lock the camera, and calls `ServerSyncFlight` periodically. On a hit it stops (`SetPhysics(PHYS_None)`), calls `ServerImpact` once and waits for `Destroy`.
- **Server**: adopts the synced state (`SetLocation`/`SetRotation`/`Velocity`), ignores its own collisions while client-driven, and owns damage, the movement freeze and `SrvLoc/SrvRot/SrvSpeed` for everyone else.
- **Other clients**: follow `SrvLoc/SrvRot/SrvSpeed` and ignore local hits.
- Pass rotators to replicated functions as separate `int` yaw/pitch. Replicated rotator variables are compressed to a byte per component; whether function parameters are too is untested, and ints avoid the question.
- Do all of this in the projectile, which has no states. A `RageWeapon` subclass's global `Tick` is unreliable on clients (see **7F**).

### F. Debugging Network Code
- Use `log()` with a tag, or ClientMessage text: `log("Sync loc=" $ Location $ " role=" $ Role, 'PredatorMissile');`
- Client output goes to `System/MobileForces.log`; a dedicated server writes its own log (e.g. `System/server.log`, depending on how it was started). Compare both sides to see what each machine believes.
- Log sparingly (on events or throttled with a timer), never every `Tick`. Remove the logs once the behaviour is verified.

---

## 3. Camera, ViewTarget & BehindView Mechanics

### A. How `ViewTarget` Works in Mobile Forces
In `Engine.PlayerPawn` (`event PlayerCalcView`):
```unrealscript
if ( ViewTarget != None )
{
    ...
    if ( bBehindView && ViewTarget.VehicleIn != none )
        CalcBehindViewVehicle(CameraLocation, CameraRotation, 500);
    else
        CalcBehindView(CameraLocation, CameraRotation, 180);
    return;
}
```
- In `CalcBehindView`:
  ```unrealscript
  CameraRotation = ViewRotation;
  View = vect(1,0,0) >> CameraRotation;
  CameraLocation -= (ViewDist - 30) * View;
  ```
- Whenever `ViewTarget != None`, `CalcBehindView` sets `CameraRotation = ViewRotation` and offsets the camera behind `ViewTarget.Location`.
- If `ViewRotation` is free-floating, moving the mouse rotates the camera in an orbit around the target.
- **To lock the camera to the target's flight direction**: on the guiding machine only, the target's `Tick` keeps `PlayerPawn.ViewRotation` synchronized with the missile/vehicle heading (each frame the mouse delta added by `UpdateRotation` becomes the steering input):
  ```unrealscript
  if (IsLocalPlayer(PP))    // see 2C; never NetMode-based
      PP.ViewRotation = NewRot;
  ```
- `PlayerPawn.ViewTarget` replicates reliably to the owner, so setting it on the server is enough to switch the client's camera. References like a weapon's replicated `ActiveMissile` may arrive later; HUD code can fall back to `PredatorMissile(PP.ViewTarget)`.

### B. Clean Camera Restoration
When guidance terminates or the actor is destroyed, **both** server and client must release the camera:
```unrealscript
simulated function Destroyed()
{
    local PlayerPawn PP;

    PP = PlayerPawn(Owner);
    if (PP == None)
        PP = PlayerPawn(Instigator);

    if (PP != None && PP.ViewTarget == self)
    {
        PP.ViewTarget = None;
        PP.bBehindView = false;
    }
    Super.Destroyed();
}
```

---

## 4. HUD, Crosshair & Weapon Icons

### A. The `bOwnsCrossHair` Mechanism
In `RageHUD.uc`:
```unrealscript
if ( !PlayerOwner.bBehindView && (RagePlayerOwner.Weapon != None) && (Level.LevelAction == LEVACT_None) )
{
    Canvas.DrawColor = WhiteColor;
    RagePlayerOwner.Weapon.PostRender(Canvas);

    if ( !RagePlayerOwner.Weapon.bOwnsCrossHair && RagePlayerOwner.Weapon.GetStateName() != 'DownWeapon' )
        DrawCrossHair(Canvas, 0,0 );
}
```
- `bOwnsCrossHair` is an actor variable that **does not replicate automatically**.
- If a weapon draws its own crosshair or terminal overlay (FLIR, missile camera, sniper scope), set `bOwnsCrossHair` in `PostRender` every frame. Don't rely on the weapon's `Tick`, which RageWeapon's client states can shadow (see **7F**):
  ```unrealscript
  if (ActiveMissile != None && !ActiveMissile.bDeleteMe)
      bOwnsCrossHair = true;
  else
      bOwnsCrossHair = false;
  ```

### B. Canvas Rendering Conventions
- Always set `Canvas.Style` explicitly (`STY_Normal`, `STY_Translucent`, `STY_Modulated`, `STY_Alpha`).
- Use `Canvas.SmallFont`, `Canvas.MedFont`, or `RageHUD.MyFonts.GetHUDMedFont(HUDSize)`.
- Use `<<` (un-rotate vector) to project world points into local camera space for 3D HUD markers:
  ```unrealscript
  Rel = (TargetLoc - CamLoc) << CamRot;
  if (Rel.X > 50.0) // In front of camera
  {
      ScreenX = (Canvas.ClipX * 0.5) + (Rel.Y / Rel.X) * Proj;
      ScreenY = (Canvas.ClipY * 0.5) - (Rel.Z / Rel.X) * Proj;
  }
  ```

### C. HUD Weapon Icons (`WeaponIcon`) & The 20px Bottom Badge Rule
Mobile Forces draws inventory weapon icons using `RageHUD.DrawTexRect(Canvas, WeapIcon, RenderWidth, BlockSize)`.

1. **Importing the Icon Texture**:
   Icons are 64×64 textures imported via `#exec`:
   ```unrealscript
   #exec TEXTURE IMPORT NAME=MyWeaponIcon FILE=Textures\my_icon.bmp GROUP=Icons MIPS=OFF Flags=2
   ```
2. **Exact Bitmap Specifications**:
   - **File format**: Windows 3.x **8-bit Paletted BMP** (or PCX), 64×64 pixels (exact size 5,174 bytes for 64×64 BMP).
   - **Masking (`Flags=2`)**: Palette index `0` is the transparent mask color. Palette index `0` **MUST** be pure black `RGB(0, 0, 0)`.
   - **Foreground Colors**: Visible pixels must map to palette indices `1..255` (a grayscale ramp from near-black up to pure white). On the HUD, `RageHUD` multiplies the texture intensity by the HUD theme color (`Canvas.DrawColor`), so grayscale gives clean 3D relief.
3. **The 20px Bottom Clearance Trap (CRITICAL)**:
   - In `RageHUD`, each inventory slot draws a blue ammo quantity badge (e.g. `"1"`, `"2"`, `"3"`) over the **bottom ~20 pixels** of the slot, and slot hotkeys (`"0"`, `"9"`) at the top edge.
   - **Rule**: The visual icon artwork must be placed between `y = 4..43` (vertical center at `y ~ 24`), with **20-21 pixels of transparent clearance at the bottom** and **12-14 pixels of margin on the left/right** (`x = 13..50`).
   - If an icon is centered at `(32, 32)` spanning the entire 64×64 canvas, it will collide with the bottom quantity badge and top key numbers!
4. **Linking in `defaultproperties`**:
   ```unrealscript
   defaultproperties
   {
       WeaponIcon=(X=0,Y=0,W=64,H=64,t=Texture'MyPackage.Icons.MyWeaponIcon')
   }
   ```

---

## 5. Loadout System, Zones & Crates

Mobile Forces has a comprehensive loadout system with spawn rooms (`LoadoutZone`) and supply points (`LoadoutCrate`). Understanding how the game interacts with weapons at these points is vital:

### A. The `TryLoadout` Automatic `Reload()` Trap (CRITICAL)
In `Rage/Classes/RagePlayer.uc` (line 4502), whenever a player is in a loadout zone or touches a crate:
```unrealscript
if (GotOne != Loadout_None)
{
    for ( Inv=Inventory; Inv!=None; Inv=Inv.Inventory )
    {
        RW = RageWeapon(Inv);
        if ( RW != none )
        {
            RW.GiveFullAmmo();
            RW.Reload(); // <-- AUTOMATICALLY CALLED ON EVERY WEAPON IN INVENTORY!
        }
    }
}
```
- **The Trap**: If your custom weapon overrides `function Reload()` to perform an active gameplay action (such as self-healing, injecting a stim, casting a spell, or toggling weapon modes), `RW.Reload()` **will be called automatically by the engine on every touch/tick** at a crate or zone, even if the weapon is **holstered**! This wastes consumables, drains ammo, or spams HUD messages.
- **The Fix**: Always guard custom `Reload()` logic against holstered execution:
  ```unrealscript
  function Reload()
  {
      local Pawn PawnOwner;

      PawnOwner = Pawn(Owner);
      // Ensure the weapon is actually held in the player's hands
      if (PawnOwner == None || PawnOwner.Weapon != self)
          return;

      // Proceed with custom activation...
  }
  ```

### B. Detecting Loadout Zones & Crates
Avoid fragile or redundant multi-state checks (such as querying `LoadoutActive` or `IsInState('Loadout')`, which can vary between client and server or desync during menu transitions). The most reliable, direct way to check if an actor is inside a spawn room or touching a resupply crate is:

```unrealscript
function bool IsAtLoadout()
{
    local LoadoutCrate LCrate;

    // 1. Player is inside a team spawn room / loadout zone
    if (Owner != None && Owner.Region.Zone != None && Owner.Region.Zone.IsA('LoadoutZone'))
        return true;

    // 2. Player is actively touching a loadout crate
    foreach TouchingActors(class'LoadoutCrate', LCrate)
        return true;

    return false;
}
```

> **Note**: For custom weapon `Reload()` abilities, the simplest mitigation against `TryLoadout` auto-firing is checking `if (Pawn(Owner).Weapon != self) return;`. This avoids blocking legitimate self-use while in a loadout zone while preventing holstered weapons from triggering.

### C. Zone Transition & Breathing Pings (`ArmorAbsorbDamage`)
When players transition between zones or enter water/loadout zones, the engine invokes `ReduceDamage(0, 'Breathe', ...)` which queries all inventory armor actors via `ArmorAbsorbDamage(Damage, DamageType, HitLocation)`.
- **Trap**: If an armor/cheat-death item does not guard against `Damage <= 0`, zero-damage environment pings will trigger cheat-death or damage absorption prematurely!
- **Rule**:
  ```unrealscript
  function int ArmorAbsorbDamage(int Damage, name DamageType, vector HitLocation)
  {
      if (Damage <= 0 || DamageType == 'Suicided' || DamageType == 'Crushed')
          return Damage;
      ...
  }
  ```

---

## 6. Single-Use Weapons & Consumables Lifecycle

### A. How `bDestroyWhenEmpty = True` Works
`RageWeapon` has native support for self-destruction when empty:
- In `state DownWeapon`:
  ```unrealscript
  Begin:
      if ( bDestroyWhenEmpty && !AmmoInClip() && !CanReload() )
      {
          Pawn(Owner).ChangedWeapon();
          Pawn(Owner).DropItem (self);
      }
  ```
- `Pawn.DropItem(self)` invokes `Inventory.DropFrom(...)`, and in `RageWeapon.DropFrom`:
  ```unrealscript
  if ( (bDestroyWhenEmpty && !AmmoInClip() && !CanReload()) || (Owner.Region.Zone.IsA('LoadoutZone')) )
  {
      if ( Pawn(Owner) != None )
          Pawn(Owner).DeleteInventory(self);
      Destroy();
      return;
  }
  ```
  This cleanly unlinks the weapon from the Pawn's inventory linked list and destroys the actor.

### B. The Human Player `Finish()` Bug (The "HUD Ghost" Trap)
In `RageWeapon.Finish()`:
- When a **bot** runs out of ammo: the engine calls `PawnOwner.SwitchToBestWeapon(); GotoState('DownWeapon');`.
- But when a **human player** (`PlayerPawn`) runs out of ammo:
  ```unrealscript
  else if ( !AmmoInClip() || (PawnOwner.Weapon != self) )
  {
      GotoState('Idle');
  }
  ```
  The engine sends the weapon to `Idle`! It **never** auto-switches or transitions to `DownWeapon` on its own.
- **Consequence**: Single-use consumable weapons will sit in the player's hands at 0 ammo forever, creating a "ghost weapon" on the HUD until the player manually scrolls away.
- **Solution**: Any single-use weapon (`AdrenalineShot`, `Grenades`, `Totem`, `TripBombs`) must **explicitly** call `GotoState('DownWeapon')` immediately upon consuming its last ammo:
  ```unrealscript
  UseAmmo(1);
  if (!AmmoInClip())
      GotoState('DownWeapon');
  ```

### C. Active vs. Passive Consumables
- **Active Consumables** (held in hands, like `AdrenalineShot` or active stims): Transition to `GotoState('DownWeapon')` so base `RageWeapon` handles `SwitchToBestWeapon()` and inventory unlinking.
- **Passive Consumables** (triggered while holstered, like cheat-death armor or passive charms): **Never** call `DownWeapon`! Calling `DownWeapon` on a holstered weapon disrupts whatever gun the player is currently shooting. Instead, directly unlink and destroy:
  ```unrealscript
  UseAmmo(1);
  if (ClipAmmo <= 0)
  {
      bIsAnArmor = false;
      PawnOwner = Pawn(Owner);
      Destroy(); // Inventory.Destroyed() automatically calls Pawn(Owner).DeleteInventory(self)
      if (PawnOwner != None)
          PawnOwner.SetSpeedFromInventory(); // DeleteInventory keeps the carry penalty (see 7H)
  }
  ```

---

## 7. UnrealScript Gotchas, Traps & Anti-Patterns

### A. State Transitions Cancel Active Timers
In UnrealScript, calling `GotoState(...)` on an actor immediately clears all active timers (`SetTimer(0, false)`).
- `GiveTo(Target)` transitions items from `auto state Pickup` into `state Idle2`.
- **The Trap**: If you spawn a buff/effect actor and call `Buff.ActivateBuff()` (which calls `SetTimer(...)`), and *then* call `Buff.GiveTo(Target)`, the state transition inside `GiveTo()` will silently cancel the timer! The buff will never tick.
- **Rule**: Always call `GiveTo()` **first**, and only activate the timer **after** the actor has settled into its state:
  ```unrealscript
  Buff = Spawn(class'MyBuffEffect', Target);
  if (Buff != None)
  {
      Buff.GiveTo(Target);         // Settle into state Idle2 first
      Buff.ActivateBuff(...);      // Start timer safely afterward
  }
  ```

### B. Redundant Type Casts Cause Compiler Errors
In UnrealScript (unlike modern languages), casting an object to a type it is already declared as is a fatal compiler error:
```unrealscript
local Pawn P;
P = Pawn(Owner);
Pawn(P).ClientMessage("Hello"); // ERROR: Cast from 'Pawn' to 'Pawn' is unnecessary
```
- Always call methods directly on typed variables: `P.ClientMessage(...)`.
- Note: `Pawn` defines `event ClientMessage(coerce string S, optional Name Type, ...)` directly in `Engine.Pawn`. You do not need to cast `Pawn` to `PlayerPawn` just to send a client message.

### C. Cast Caching for Performance
In UnrealScript bytecode, dynamic casts like `Pawn(Owner)` or `Pawn(Other)` perform runtime class hierarchy checks.
- If a function references `Pawn(Owner)` or `Pawn(Other)` multiple times, store the result in a local variable:
  ```unrealscript
  local Pawn PawnOwner;
  PawnOwner = Pawn(Owner);
  ```
- This reduces bytecode size, speeds up execution, and makes the code defensive against `None` pointers.

### D. Short-Circuit Evaluation (`skip`)
In UnrealScript, the logical AND operator `&&` is declared natively with the `skip` keyword:
```unrealscript
native(132) static final operator(30) bool && ( bool A, skip bool B );
```
- Short-circuiting is guaranteed.
- Expressions like `if (TargetPawn != None && TargetPawn.Health > 0 && ApplyHeal(TargetPawn))` will **never** execute `ApplyHeal` if `TargetPawn` is `None` or dead.

### E. Dead & Legacy Properties (Do NOT waste time on these)
- **`NameColor`**: `Engine.Weapon.var() Color NameColor` is an unused UT99 legacy variable. `RageHUD` does not read it. Setting it has zero effect.
- **`AmmoType`**: `RageWeapon` does not use vanilla UT `AmmoType` inventory classes. It manages ammo via `ClipAmmo`/`TotalAmmo`.
- **`bCanThrow`**: Does not prevent weapon dropping in loadout zones unless specifically respected by `RagePlayer`.
- **`PlayerPawn.bFrozen`**: Only read in a few non-walking states (dying, game ended). It does **not** freeze a walking player.

### F. RageWeapon State `Tick`s Shadow Your Global `Tick` on Clients
`RageWeapon` defines `Tick` inside `ClientFiring`, `ClientAltFiring`, `ClientReloading`, `ClientDown`, `ClientZoomedIn`, `PreZoomIn` and `PostZoomOut`. Some also call `Disable('Tick')`. A parent class's state function overrides a subclass's global function, so a weapon subclass's `simulated function Tick` silently stops running on the client in those states.
- Keep client-critical per-frame logic out of weapon `Tick`. Put it in a stateless actor (the projectile) or in `PostRender`.
- Weapon `Tick` is fine for server-only bookkeeping (e.g. a replicated warmup countdown).

### G. Freezing a Player's Movement
- Set it on the **server**: `GroundSpeed` replicates reliably to everyone, `JumpZ` to the owner, and `ServerMove` → `MoveAutonomous` uses the server's values.
- Use a tiny non-zero `GroundSpeed` (e.g. `1.0`), not `0`: `RPlayer.CheckBob` divides by `GroundSpeed`, and a NaN bob breaks the first-person camera. Also set `JumpZ = 0`.
- Save the original values once and restore them on **every** exit path (impact, owner death, weapon destroyed, `LifeSpan` expiry). Restoring from `Destroyed()` of the actor that froze the player covers all of them.

### H. `DeleteInventory` Doesn't Recalculate Speed
`Pawn.DeleteInventory` subtracts `CurrentCarry` but leaves `GroundSpeed` with the item's carry penalty. When a consumable removes itself manually, call `PawnOwner.SetSpeedFromInventory()` after `DeleteInventory`.

### I. Server-Only Globals: `Level.Game` and `Level.PawnList`
- `Level.Game` only exists on the server. Client-side (HUD, `PostRender`) team checks must use `PlayerPawn(Owner).GameReplicationInfo.bTeamGame`.
- `Level.PawnList` is filled by `AddPawn()` in `Pawn.PreBeginPlay`, which isn't `simulated`, so on clients the list is empty. Client-side code must iterate pawns with `foreach AllActors(class'Pawn', P)`.

### J. Vehicles Are Pawns, but Not in `Level.PawnList`
- Hierarchy: `Pawn` → `EnginePhysical` (Engine) → `Physical` (Rage, no source in repo) → `Vehicle` → `Car` → `Armadillo`, etc. `Vehicle(P)` casts on a `Pawn` are legal.
- `EnginePhysical.PreBeginPlay` (`Engine/Classes/EnginePhysical.uc`) replaces `Pawn.PreBeginPlay` and has `Super.PreBeginPlay()` commented out. So it **never calls `AddPawn()`**, and instead links itself into **`Level.VehicleList`** via `NextPhysical`/`LastPhysical`. `Destroyed()` unlinks it again.
- Consequences:
  - A `Level.PawnList` loop never sees vehicles (or any `EnginePhysical`), even on the server. The PRI filter in such a loop is still required, because `PawnList` holds players and bots (with a PRI) and gadget pawns like `SeekerMine` and `SentryGunTurret` (without one).
  - `foreach AllActors(class'Pawn', P)` **does** return vehicles. Filter with `EnginePhysical(P) == None` when only "real" pawns are wanted.
- Idioms (server):
  ```unrealscript
  // Vehicles: cache the next link before SilentDestroy unlinks the current one
  for (Phys = Level.VehicleList; Phys != None; Phys = NextPhys)
  {
      NextPhys = Phys.NextPhysical;
      V = Vehicle(Phys);
      if (V != None)
          V.SilentDestroy();
  }

  // Non-vehicle pawns without a PRI (SeekerMines, SentryGunTurrets, ...)
  for (P = Level.PawnList; P != None; P = NextP)
  {
      NextP = P.NextPawn;
      if (P.PlayerReplicationInfo == None)
          P.Destroy();
  }
  ```
- Target finders that should hit vehicles need both loops. See `SeekerMine.FindBestTarget` and `SentryGunTurret.FindBestTarget`.
- `VehicleList` is maintained only where `Role == ROLE_Authority`, since `Destroyed()` returns early on clients. On clients, use `foreach AllActors(class'Vehicle', V)`.
- To check a class's superclass when the source is missing (e.g. `Physical`), read the export table of the compiled `.u`. `ucc batchexport` crashes under Wine and can't handle the space in "Mobile Forces".

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
- **Windows / PowerShell**:
  ```powershell
  Remove-Item .\System\<PackageName>.u -ErrorAction SilentlyContinue
  .\System\UCC.exe make -nobind
  ```
- Use `-nobind` to prevent native DLL binding issues during automated compilation.
- Ensure 0 errors and 0 warnings before testing in-game.

---

## 9. Coding Style: The Mature Mod Standard (`ZombieGame`, `TripLasers`)

Mature mods in this repository adhere to these principles:

1. **Minimal & Deduplicated**:
   - Avoid creating duplicate variables (e.g. `BaseSpeed` vs `Speed`, or duplicate state booleans).
   - Reuse engine variables (`Speed`, `MaxSpeed`, `Damage`, `MomentumTransfer`) before inventing custom ones.
2. **Defensive Pointer Handling**:
   - Check `if (P != None && !P.bDeleteMe && P.Health > 0)`.
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
