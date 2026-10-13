# Mobile Forces UnrealScript Rules & Guidelines

## 1. Engine & Networking Rules
- **ROLE_SimulatedProxy**: `Actor.Location` and `Actor.Rotation` do NOT replicate to clients after `bNetInitial` in UE1/MF. Any actor requiring smooth client-side steering or movement must execute physics simulation in `simulated function Tick()` on the client.
- **Instigator Replication**: `bReplicateInstigator` defaults to `False`. Always set `bReplicateInstigator=True` in `defaultproperties` if clients need `Instigator`, or fall back to `Owner`.
- **Dedicated Server ViewRotation**: On dedicated servers, `PlayerPawn.ViewRotation` is received from the client via `ServerMove`. Do NOT overwrite `PlayerPawn.ViewRotation` on `NM_DedicatedServer`, but DO synchronize `PlayerPawn.ViewRotation = NewRot` on clients and standalone to keep the camera locked behind guided projectiles or turrets.
- **Single-Authority Damage & Explosions**: In `simulated function Explode()`, guard explosion spawns, sound, and `HurtRadius` behind `if (Role == ROLE_Authority)` to prevent duplicate explosion effects and server/client desync.
- **Weapon Crosshair**: `RageHUD` checks `RagePlayerOwner.Weapon.bOwnsCrossHair`. Ensure custom weapons set `bOwnsCrossHair = true` on the client whenever a custom overlay or guidance state is active.

## 2. Loadout & Crate Rules
- **The `TryLoadout` Reload Trap**: The engine automatically calls `RW.Reload()` on **every** weapon in a player's inventory when touching a crate or in a spawn room (`LoadoutZone`). Never execute active weapon abilities in `Reload()` without checking `if (Pawn(Owner) == None || Pawn(Owner).Weapon != self) return;`.
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
