---
trigger: always_on
---

# Mobile Forces UnrealScript Rules & Guidelines

## 1. Engine & Networking Rules
- **ROLE_SimulatedProxy**: `Actor.Location` and `Actor.Rotation` do NOT replicate to clients after `bNetInitial` in UE1/MF. Any actor requiring smooth client-side steering or movement must execute physics simulation in `simulated function Tick()` on the client.
- **Instigator Replication**: `bReplicateInstigator` defaults to `False`. Always set `bReplicateInstigator=True` in `defaultproperties` if clients need `Instigator`, or fall back to `Owner`.
- **Local Player Check, Not NetMode**: Test `PP.Player != None && PP.Player.IsA('Viewport')` to find the machine a player sits at. Only there may you write `PP.ViewRotation` (e.g. to lock a camera behind a guided projectile). `NetMode != NM_DedicatedServer` is wrong on listen servers; the server must never overwrite a remote player's `ViewRotation`.
- **Player-Guided Actors**: Let the owning client fly the actor and drive the server copy with `Role < ROLE_Authority` replicated functions on the actor itself (verified for a projectile whose Owner is the client's PlayerPawn). Replicate custom position/rotation for other clients. See AGENTS.md 2E (`PredatorMissile`).
- **Single-Authority Damage & Explosions**: In `simulated function Explode()`, guard explosion spawns, sound, and `HurtRadius` behind `if (Role == ROLE_Authority)` to prevent duplicate explosion effects and server/client desync. Guided/camera actors must not `Destroy()` on a client-side hit; stop and wait for the server.
- **Weapon Crosshair**: `RageHUD` checks `RagePlayerOwner.Weapon.bOwnsCrossHair`. Set it every frame in `PostRender` whenever a custom overlay or guidance state is active.
- **Weapon `Tick` Is Unreliable on Clients**: RageWeapon's client states (`ClientFiring`, `ClientDown`, zoom states, ...) define their own `Tick`, which shadows a subclass's global `Tick`. Keep client per-frame logic in a stateless actor or `PostRender`.
- **Debug via Logs**: Use tagged `log(..., 'MyPackage')` and read `System/MobileForces.log` (client) and the server's log. Potentially use ClientMessage.

## 2. Loadout & Crate Rules
- **The `TryLoadout` Reload Trap**: The engine automatically calls `RW.Reload()` on **every** weapon in a player's inventory when touching a crate or in a spawn room (`LoadoutZone`). Never execute active weapon abilities in `Reload()` without checking `if (Pawn(Owner) == None || Pawn(Owner).Weapon != self) return;`.
- **Detecting Loadout Presence**: Avoid fragile multi-state checks. Check `Owner.Region.Zone.IsA('LoadoutZone')` or `TouchingActors(class'LoadoutCrate', LCrate)` directly.
- **Freezing Players**: `bFrozen` doesn't stop walking. On the server set `GroundSpeed = 1.0` (not 0: `CheckBob` divides by it) and `JumpZ = 0`, saving and restoring the originals on every exit path.
- **`DeleteInventory` Keeps Carry Penalty**: Call `PawnOwner.SetSpeedFromInventory()` after manually deleting an item.
- **Client Team Checks**: `Level.Game` is `None` on clients; use `PlayerPawn(Owner).GameReplicationInfo.bTeamGame`.
- **`Level.PawnList` Is Server-Only**: It's empty on clients. Use `foreach AllActors(class'Pawn', P)` in HUD/client code, and filter vehicles out with `EnginePhysical(P) == None`.
- **Vehicles Are Pawns but Not in `PawnList`**: `EnginePhysical.PreBeginPlay` skips `AddPawn()` and links into `Level.VehicleList` (`NextPhysical`). Iterate vehicles on the server with `for (Phys = Level.VehicleList; Phys != None; Phys = NextPhys) { NextPhys = Phys.NextPhysical; ... }` (cache the next link before `SilentDestroy`). See AGENTS.md 7J.
- **Zero-Damage Zone Transitions**: Zone transitions ping all armor items via `ArmorAbsorbDamage(0, 'Breathe', ...)`. Any armor or cheat-death item MUST early return on `if (Damage <= 0 || DamageType == 'Suicided' || DamageType == 'Crushed') return Damage;` to avoid false triggers.

## 3. Weapon Lifecycle & Consumables
- **The Human `Finish()` Idle Bug**: In `RageWeapon.Finish()`, human players with empty weapons are sent to `state Idle` instead of auto-switching. Single-use items (`bDestroyWhenEmpty=True`) must explicitly call `GotoState('DownWeapon')` immediately after consuming their last ammo.
- **Passive vs. Active Destruction**: Active weapons transition to `DownWeapon` on empty. Passive items (e.g. cheat-death armor triggered while holstered) must **never** call `DownWeapon`; call direct `Destroy()` to prevent disrupting the player's active firearm.

## 4. Timers, States & Compiler Quirks
- **State Changes Clear Timers**: Calling `GotoState(...)` (including `GiveTo()` transitioning to `Idle2`) cancels all active timers. When spawning buff/effect items, call `Buff.GiveTo(Target)` **first**, and only start timers (`Buff.ActivateBuff()`) **afterwards**.
- **No Redundant Casts**: Casting a variable to its own type (e.g. `Pawn(P)` when `P` is already a `Pawn`) causes a fatal compiler error: `Cast from 'Pawn' to 'Pawn' is unnecessary`.
- **Cache Repeated Casts**: Dynamic casts like `Pawn(Owner)` and `Pawn(Other)` incur runtime bytecode overhead. If used $\ge 2$ times in a function, store in a local variable (`PawnOwner = Pawn(Owner);`).
- **Ignore Legacy Properties**: Do not waste time configuring `NameColor` (completely ignored by `RageHUD`) or `AmmoType` (`RageWeapon` does not use UT ammo classes).

## 5. HUD Weapon Icons
- **Texture Format**: Must be Windows 3.x 8-bit paletted BMP (64×64 pixels, 5,174 bytes) imported with `Flags=2` (`PF_Masked`). Palette index `0` must be pure black `RGB(0, 0, 0)` for transparency.
- **The 20px Bottom Clearance Rule**: In `RageHUD`, the ammo quantity badge covers the bottom ~20 pixels of the inventory slot. The visual icon must be drawn in `y = 4..43` (centered at `y ~ 24`), leaving **20-21 pixels of transparent space at the bottom**.

## 6. Compilation & Workflow
- **Rebuilding Packages**: Always delete the old `.u` file before compiling:
  `rm -f System/<PackageName>.u && wine System/UCC.exe make -nobind` (or PowerShell: `Remove-Item .\System\<PackageName>.u; .\System\UCC.exe make -nobind`).
- **EditPackages Order**: In `System/MobileForces.ini`, packages compile from top to bottom. Add custom packages to the end of the `EditPackages` list under `[Editor.EditorEngine]`.
