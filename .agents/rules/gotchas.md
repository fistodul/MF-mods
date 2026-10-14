---
trigger: model_decision
description: Engine traps such as GiveTo() clearing timers, cast rules, RageWeapon state Ticks, freezing players, DeleteInventory speed, server-only Level.Game and PawnList, vehicles in VehicleList. Read when iterating pawns or using timers.
---

# UnrealScript & engine gotchas

> Part of the Mobile Forces agent guide. Section numbers are shared across `.agents/rules/`; the index is in the root `AGENTS.md`.

---

## 7. UnrealScript Gotchas, Traps & Anti-Patterns

### A. `GiveTo()` Cancels Active Timers
`Inventory.GiveTo()` (`Engine/Classes/Inventory.uc`) runs `BecomeItem(); Other.AddInventory(Self); GotoState('Idle2');`, and `BecomeItem()` calls `SetTimer(0.0, False)`. `BecomeCrateItem()` does the same. The reset comes from that explicit call, not from the state change.
- **The Trap**: If you spawn a buff/effect actor and call `Buff.ActivateBuff()` (which calls `SetTimer(...)`), and *then* call `Buff.GiveTo(Target)`, `BecomeItem()` silently cancels the timer and the buff never ticks.
- **Rule**: Always call `GiveTo()` **first**, and only activate the timer afterwards:
  ```unrealscript
  Buff = Spawn(class'MyBuffEffect', Target);
  if (Buff != None)
  {
      Buff.GiveTo(Target);         // BecomeItem() clears timers
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
