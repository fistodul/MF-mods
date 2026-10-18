---
trigger: model_decision
description: Multiplayer replication (SimulatedProxy, Instigator, ServerMove, local-player checks), player-guided actors like PredatorMissile, network debugging and ViewTarget camera control. Read before writing multiplayer or camera code.
---

# Networking, replication & camera

> Part of the Mobile Forces agent guide. Section numbers are shared across `.agents/rules/`; the index is in the root `AGENTS.md`.

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
- Standalone tests don't replicate anything. To test replication locally, run `UCC.exe server ...` and connect `MobileForces.exe 127.0.0.1`. Both logs are written in 4 KB blocks and a killed client loses its tail, so let a client-side probe (a `bAlwaysRelevant` `Info` with a simulated `Tick`, its package added to `ServerPackages`) log what arrived and then run `ConsoleCommand("exit")`.
- Hidden actors only reach clients when relevant by other means: `bAlwaysRelevant`, ownership, or an ambient sound. Items in loadout crates and zones are hidden. They replicate because state `Pickup` sets `bAlwaysRelevant` on items spawned during level startup (`Level.bStartup`), so items a mod spawns later need `bAlwaysRelevant = true` set by hand. Otherwise the crate's `aWeapons` stay `None` on clients, and `TryLoadoutCrate` keeps waiting ("replication delay"): the loadout screen never opens. Every item class must also be in `ServerPackages`.

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
