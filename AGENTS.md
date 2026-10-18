# Mobile Forces (MF) Agent Rules

> Always-on rules for modding Mobile Forces (Rage Engine / UE 1.5 hybrid).

- **Response style**: follow [`.agents/rules/caveman.md`](.agents/rules/caveman.md).
- **Detailed guide**: topic files in `.agents/rules/`, with section numbers shared across files. Each rule below points to its section (e.g. "gotchas 7J"). Read that file before writing code in the area.

| File | Sections |
|---|---|
| [`architecture-build.md`](.agents/rules/architecture-build.md) | 1 Architecture, 8 Build workflow, 9 Coding style |
| [`networking.md`](.agents/rules/networking.md) | 2 Replication & guided actors, 3 Camera / ViewTarget |
| [`hud.md`](.agents/rules/hud.md) | 4 HUD, crosshair & weapon icons |
| [`loadout-consumables.md`](.agents/rules/loadout-consumables.md) | 5 Loadouts & armor, 6 Consumables lifecycle |
| [`gotchas.md`](.agents/rules/gotchas.md) | 7 UnrealScript & engine gotchas |
| [`maps.md`](.agents/rules/maps.md) | 10A-D Maps & the editor (tool: `.agents/tools/maptool/`) |
| [`map-content.md`](.agents/rules/map-content.md) | 10E-H Zones, water, game-mode actors, testing |
| [`vehicles.md`](.agents/rules/vehicles.md) | 11 Vehicles, seats & mounted weapons |

---

## Quick Rules

### Engine & Networking Rules
- **ROLE_SimulatedProxy**: `Actor.Location`, `Rotation` and `Velocity` do NOT replicate to clients after `bNetInitial` in UE1/MF. Native physics keeps moving the client copy along its last `Velocity`. Any change of direction or speed must be computed in the client's `simulated function Tick()`, or sent through custom replicated variables. (networking 2A)
- **Instigator Replication**: `bReplicateInstigator` defaults to `False`. Always set `bReplicateInstigator=True` in `defaultproperties` if clients need `Instigator`, or fall back to `Owner`. (networking 2B)
- **Local Player Check, Not NetMode**: Test `PP.Player != None && PP.Player.IsA('Viewport')` to find the machine a player sits at. Only there may you write `PP.ViewRotation` (e.g. to lock a camera behind a guided projectile). `NetMode != NM_DedicatedServer` is wrong on listen servers; the server must never overwrite a remote player's `ViewRotation`. (networking 2C)
- **Player-Guided Actors**: Let the owning client fly the actor and drive the server copy with `Role < ROLE_Authority` replicated functions on the actor itself (verified for a projectile whose Owner is the client's PlayerPawn). Replicate custom position/rotation for other clients. See networking 2E (`PredatorMissile`).
- **Single-Authority Damage & Explosions**: In `simulated function Explode()`, guard explosion spawns, sound, and `HurtRadius` behind `if (Role == ROLE_Authority)` to prevent duplicate explosion effects and server/client desync. Guided/camera actors must not `Destroy()` on a client-side hit; stop and wait for the server. (networking 2D)
- **Weapon Crosshair**: `RageHUD` checks `RagePlayerOwner.Weapon.bOwnsCrossHair`. Set it every frame in `PostRender` whenever a custom overlay or guidance state is active. (hud 4A)
- **Weapon `Tick` Is Unreliable on Clients**: RageWeapon's client states (`ClientFiring`, `ClientDown`, zoom states, ...) define their own `Tick`, which shadows a subclass's global `Tick`. Keep client per-frame logic in a stateless actor or `PostRender`. (gotchas 7F)
- **Late-Spawned Hidden Actors Don't Replicate**: Loadout crate items spawned after level startup need `bAlwaysRelevant = true`, or clients never get them and the loadout screen hangs. Test replication on a local server with a connected client, not standalone. (networking 2F)
- **Debug via Logs**: `log("...", 'MyPackage')` writes to `System/MobileForces.log` on the client, alongside the engine's `ScriptWarning: ... Accessed None` lines. For in-game output, `Pawn.ClientMessage("...")`. (networking 2F)

### Loadout & Crate Rules
- **The `TryLoadout` Reload Trap**: When a player opens loadout at a crate or in a `LoadoutZone` (the `TryLoadout` key, or spawning into a loadout room), `ServerTryLoadout` calls `RW.Reload()` on **every** weapon in the inventory, holstered ones included. A weapon whose `Reload()` triggers an ability must check `if (Pawn(Owner) == None || Pawn(Owner).Weapon != self) return;`. (loadout-consumables 5A)
- **`InventoryGroup` Must Be 1..11**: `RagePlayer`'s loadout arrays (`aLoadoutWeaps[12]`, `aLoadoutWeapsCount[12]`) are indexed by group, so 12+ logs `AddItemToLoadout ... Accessed array out of bounds (12/12)`. Every stock group is taken (1 default, 2 Pistol ... 10 AdrenalineShot, 11 RageArmour), so mods share one (grenLaunch 7, Totem 10, SentryGun/PredatorMissile 11). The HUD shows number keys only for groups 1-9.
- **Detecting Loadout Presence**: Avoid fragile multi-state checks. Do what `RagePlayer.TryLoadoutZone`/`TryLoadoutCrate` do: `LoadoutZone(Owner.Region.Zone) != None`, or `foreach RadiusActors(class'LoadoutCrate', LCrate, Owner.CollisionRadius, Owner.Location)`. The visible crate meshes (`LoadoutCrate_Blue`, ...) are `Decoration`s, not `LoadoutCrate`s. (loadout-consumables 5B)
- **Freezing Players**: `bFrozen` doesn't stop walking. On the server set `GroundSpeed = 1.0` (not 0: `CheckBob` divides by it) and `JumpZ = 0`, saving and restoring the originals on every exit path. (gotchas 7G)
- **`DeleteInventory` Keeps Carry Penalty**: Call `PawnOwner.SetSpeedFromInventory()` after manually deleting an item. (gotchas 7H)
- **Client Team Checks**: `Level.Game` is `None` on clients; use `PlayerPawn(Owner).GameReplicationInfo.bTeamGame`. (gotchas 7I)
- **`Level.PawnList` Is Server-Only**: It's empty on clients. Use `foreach AllActors(class'Pawn', P)` in HUD/client code, and filter vehicles out with `EnginePhysical(P) == None`. (gotchas 7I)
- **Vehicles Are Pawns but Not in `PawnList`**: `EnginePhysical.PreBeginPlay` skips `AddPawn()` and links into `Level.VehicleList` (`NextPhysical`). Iterate vehicles on the server with `for (Phys = Level.VehicleList; Phys != None; Phys = NextPhys) { NextPhys = Phys.NextPhysical; ... }` (cache the next link before `SilentDestroy`). See gotchas 7J.
- **Armor Only Sees Real Damage**: `Inventory.ReduceDamage` (`Engine/Classes/Inventory.uc`) calls `ArmorAbsorbDamage` only while the remaining damage is `> 0`. The zero-damage `'Breathe'`/`'Drowned'` pings (head leaving or entering water) never reach armor, so a `Damage <= 0` guard is redundant. `'Suicided'` never reaches armor either: it goes straight to `Died()`. `'Crushed'` (from `Mover`) does arrive with real damage; whether cheat-death items should absorb it is a design choice (`Totem` lets it through). (loadout-consumables 5C)

### Weapon Lifecycle & Consumables
- **The Human `Finish()` Idle Bug**: In `RageWeapon.Finish()`, human players with empty weapons are sent to `state Idle` instead of auto-switching. Single-use items (`bDestroyWhenEmpty=True`) must explicitly call `GotoState('DownWeapon')` immediately after consuming their last ammo. (loadout-consumables 6B)
- **Passive vs. Active Destruction**: Active weapons transition to `DownWeapon` on empty. Passive items (e.g. cheat-death armor triggered while holstered) must **never** call `DownWeapon`; call direct `Destroy()` to prevent disrupting the player's active firearm. (loadout-consumables 6C)

### Code Style (architecture-build 9)
- **Override, Don't Copy**: Override only what differs and call `Super.Func(...)` for the rest. Avoid pasting a parent function's body into a subclass.

### Timers, States & Compiler Quirks
- **`GiveTo()` Clears Timers**: `Inventory.GiveTo()` calls `BecomeItem()`, which runs `SetTimer(0.0, False)`. When spawning buff/effect items, call `Buff.GiveTo(Target)` **first**, and only start timers (`Buff.ActivateBuff()`) **afterwards**. (gotchas 7A)
- **No Redundant Guards**: Look up the source before adding a check. Skip it if a callee, the parent class or the engine already handles the case. Check `bDeleteMe` only on references held across ticks (architecture-build 9.2).
- **`IsA` Names Aren't Compiled**: `IsA('X')` compiles even when class `X` doesn't exist. Confirm `X` is in `*/Classes` first: MF has no `Bot` class, and its bots are `EngineBot` > `RBot` > `RageBot`. (architecture-build 9.2)
- **Cache Repeated Casts**: Dynamic casts like `Pawn(Owner)` and `Pawn(Other)` incur runtime bytecode overhead. If used $\ge 2$ times in a function, store in a local variable (`PawnOwner = Pawn(Owner);`). (gotchas 7C)
- **Ignore Legacy Properties**: Do not waste time configuring `NameColor` (completely ignored by `RageHUD`) or `AmmoType` (`RageWeapon` does not use UT ammo classes). (gotchas 7E)

### HUD Weapon Icons
- **Texture Format**: Must be Windows 3.x 8-bit paletted BMP (64×64 pixels, 5,174 bytes) imported with `Flags=2` (`PF_Masked`). Palette index `0` must be pure black `RGB(0, 0, 0)` for transparency. (hud 4C)
- **The 20px Bottom Clearance Rule**: In `RageHUD`, the ammo quantity badge covers the bottom ~20 pixels of the inventory slot. The visual icon must be drawn in `y = 4..43` (centered at `y ~ 24`), leaving **20-21 pixels of transparent space at the bottom**. (hud 4C)

### Vehicles (vehicles 11)
- **Vehicles Run Script on Clients**: Their client role is `ROLE_Physical` (above `ROLE_AutonomousProxy`), and `PawnLeaveVehicle` is called on clients too. Guard server-only work with `Role == ROLE_Authority`. (vehicles 11A)
- **Seat Input**: On the server, an occupant's `ViewRotation` is its world aim and `bFire` its fire key, bots included. The seat camera is the overridable `GetSeatPos`. (vehicles 11B-C)
- **Passengers Keep Their Weapons**: Only drivers get a placeholder `VehicleWeapon` and a switch block. A non-`RageWeapon` held in first person needs `bOwnsCrossHair=True`. (vehicles 11D)
- **Bullets Don't Hurt Vehicles**: Non-explosive damage types deal 0 to vehicles; `<Package>DOT<Class>` types count as explosive. (vehicles 11E)
- **64 Physical Objects per Level**: Props (`Ball`s) and vehicles share the limit. Past it, map props vanish and generators log `Destroying car on creation` forever. (vehicles 11G)
- **Boarding From Water Is Unreliable**: `ServerTryEnterExit` only takes walking or falling players, yet a submerged tank can be entered depending on where its seat is. Moor boats at a jetty. (vehicles 11G)

### Maps (maps 10A-D, map-content 10E-H)
- **Script Maps Through the Editor**: Export/import T3D and run editor macros with `.agents/tools/maptool/`. Mind the import traps: package `MyLevel`, first brush becomes the builder brush, bare texture names only. (maps 10A-D)
- **Fog End Is the Draw Distance**: Nothing renders past a zone's `DistanceFogEnd`, even with fog off. (map-content 10E)
- **No Open-Air Zone Volumes**: They smear (hall of mirrors) and block traces. (map-content 10E)
- **Neutral Spawns Are `TeamNumber=255`**: Non-team games only use `PlayerStart`s with `TeamNumber >= 2`; the default 0 is a blue spawn. (map-content 10G)
- **Test Maps on a Local Server**: `UCC.exe server <map>?game=... -forcelogflush`, read stdout, and use a throwaway probe mutator for what the log doesn't show. (map-content 10H)

### Compilation & Workflow
- **Rebuilding Packages** (architecture-build 8C): Always delete the old `.u` file before compiling:
  `rm -f System/<PackageName>.u && wine System/UCC.exe make -nobind`. On Windows, run UCC from the 8.3 short path of `System`.
- **EditPackages Order**: In `System/MobileForces.ini`, packages compile from top to bottom. Add custom packages to the end of the `EditPackages` list under `[Editor.EditorEngine]`. (architecture-build 8A)
