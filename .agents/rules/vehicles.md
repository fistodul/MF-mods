---
trigger: model_decision
description: Vehicle seats, passenger input and cameras, net roles of vehicles, blocking weapons in a seat, damage types against vehicles, and mounting a turret (ArmedAPC). Read before writing or reviewing vehicle code.
---

# Vehicles

> Part of the Mobile Forces agent guide. Section numbers are shared across `.agents/rules/`; the index is in the root `AGENTS.md`. Vehicles in `Level.VehicleList` are in gotchas 7J.

---

## 11. Vehicles, Seats & Mounted Weapons

### A. Net Role: `ROLE_Physical`
- `ENetRole` (`Engine/Classes/Actor.uc`) has an extra `ROLE_Physical` between `ROLE_AutonomousProxy` and `ROLE_Authority`. `Physical` sets `RemoteRole=ROLE_Physical`, so a vehicle's `Role` on a client is above `ROLE_AutonomousProxy`.
- Inferred from code that works online (jeep's client branch in its non-simulated `PreBeginPlay`): non-simulated vehicle functions **also run on clients**. Mark client logic `simulated` anyway, and guard server-only work with `Role == ROLE_Authority`. `Role < ROLE_Authority` still means "client".
- `Vehicle.PawnLeaveVehicle` is commented "Server only", but `RagePlayer.sc_ClientLeaveVehicle` calls it on the client too. Guard server-only work in an override with `Role == ROLE_Authority`. `PawnEnterVehicle` runs on the server only.

### B. Seats & Cameras
- Seat arrays live in `Vehicle` (`aSeatsPos`, `aSeatsRot`, `aSeatsRotLimit`, `aSeatsSit`, `aSeatsDoor`/`aDoorsSeat`, `aSeatsBotDesire`, `aSeatsProtection`). `aSeatsOccupant` is replicated.
- A seated `RagePlayer`'s camera (first person) is `Vehicle.GetSeatPos(SeatNum)`, placed by `GetPointWorld2` (from `RealLocation`). Its body is the same point minus `EyeHeight`. `GetSeatPos` is simulated and overridable, so a subclass can move a seat at runtime.
- The flag, lights and the jeep's gun are placed with the native `GetPointWorld` instead. The two frames haven't been compared; put a mounted mesh and the seat it belongs to in the same one.
- Passengers are always `CAMERA_INCAR` (`RagePlayer.InCarState.SetCamera`); only the driver gets behind views. The patched `RagePlayer` has a "free camera" for passengers and drivers (`bIndepCamRotPass`/`bIndepCamRotDriv`, toggled with the Run key). Its `TurretRotation` is replicated but nothing reads it.
- Vehicle model and collision sources aren't in the repo, and `Physics/*.COL` only holds coarse physics spheres. Positions on a vehicle (roof height, hatch) can't be measured. Pick a guess and tune live in a practice game with `set <Class> <Property> <Value>`, which changes the default and every existing instance (`mutPack.changeDefProperties` relies on it). Properties copied at spawn (e.g. a `DrawScale` given to a spawned mesh) need a new vehicle.

### C. Passenger Input on the Server
- `RagePlayer.cs_ServerMove2` sends each seated player's view and fire to the server. There, the occupant's `ViewRotation` is the world aim in both camera modes, and `bFire` is set. `Vehicle.UpdateControls(SeatNo, ..., inView, inFire)` also receives it per seat, but bots don't call it every tick.
- So a vehicle reading its occupants should read `aSeatsOccupant[i].ViewRotation` and `.bFire` on the server. Bots set `bFire` in `RBot.FireWeapon` (state `AttackingVehicle`) and have `Enemy` for aiming.

### D. Keeping Occupants Off Their Own Weapons
- Drivers: `RagePlayer.EnterVehicle` calls `DriverPutDownWeapon` (holsters the weapon, hands over the vehicle's `VehicleWeapon` copy) and `InCarState` blocks weapon switching for the driver seat only. Passengers keep their weapons, can switch, and fire them.
- To lock a passenger onto a placeholder weapon (as `ArmedAPCWeapon` does): override `BringUp()` to do nothing, so it never enters `Weapon`'s `Active`/`Idle` states (their `PutDown` would bypass yours), and make `PutDown()` clear `PendingWeapon` and return false. Give and remove the weapon yourself (`Spawn` + `GiveTo`, then `DeleteInventory` + `Destroy`), and restore the old weapon with `PendingWeapon` + `ChangedWeapon()`.
- A first-person passenger holding a non-`RageWeapon` needs `bOwnsCrossHair=True`: `RageHUD.DrawCrossHair` casts the weapon to `RageWeapon` (Accessed None otherwise). Draw the crosshair in the weapon's `PostRender`. The HUD inventory bar only lists `RageWeapon`s.
- On clients an inventory item is a simulated proxy, so its calls to non-simulated natives such as `Project` are skipped and return zeros: the crosshair landed in the top-left corner online, while it worked offline. Call them on an actor the client owns, e.g. `HUD.Project(Canvas, Pos)`.
- The Reload key calls `RageWeapon(Weapon).ClientReload()` on the client (Accessed None for any other weapon, stock drivers included) and `Weapon.Reload()` on the server through `cs_Reload`.

### E. Damage Against Vehicles
- `Mutator.MutatorTakeDamage` zeroes damage to any `Physical` unless `IsExplosiveDamageType`. So `'tracedshot'` and other bullet types don't hurt vehicles by default; `mutPack.changeDamage` changes that.
- `RageGameInfo.IsExplosiveDamageType` treats any `<Package>DOT<Class>` damage type as explosive: vehicles take ×1.5 (`Vehicle.TakeDamage`) and seat protection applies to occupants. The death message comes from that `Inventory` class's `DeathMessage`. Other damage types use `Killer.Weapon`'s.
- A projectile spawned by a pawn (`Gunner.Spawn(...)`) gets that pawn as `Instigator` (`Pawn.PreBeginPlay` sets `Instigator = Self`). `Rocket.ProcessTouch` then ignores the instigator and `Instigator.VehicleIn`.
- Traces from a vehicle skip the vehicle itself, but its wheel/petrol-cap collision actors (`Owner == self`) and its occupants block them. Re-trace from the hit actor (`Other.Trace`, which skips `Other`), as `ArmedAPC.TraceFire` does.

### F. Mounted Turret Pattern (`ArmedAPC`)
- Each machine spawns its own turret mesh (`RemoteRole=ROLE_None`) and places it in the vehicle's simulated `Tick`. The server and the gunner's own machine aim it from the gunner's `ViewRotation`; the server replicates its rotation for other clients. Firing, ammo and reload run on the server.
