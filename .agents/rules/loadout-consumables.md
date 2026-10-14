---
trigger: model_decision
description: Loadout zones and crates (TryLoadout Reload trap), what reaches ArmorAbsorbDamage, and single-use weapon lifecycle (bDestroyWhenEmpty, Finish() bug). Read before writing Reload() abilities, armor or consumables.
---

# Loadouts, armor & consumables

> Part of the Mobile Forces agent guide. Section numbers are shared across `.agents/rules/`; the index is in the root `AGENTS.md`.

---

## 5. Loadout System, Zones & Crates

Mobile Forces has a comprehensive loadout system with spawn rooms (`LoadoutZone`) and supply points (`LoadoutCrate`). Understanding how the game interacts with weapons at these points is vital:

### A. The `TryLoadout` Automatic `Reload()` Trap
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
- **The Trap**: If your custom weapon overrides `function Reload()` to perform an active gameplay action (such as self-healing, injecting a stim, casting a spell, or toggling weapon modes), `RW.Reload()` **is called automatically each time the player opens loadout** at a crate or in a zone (the `TryLoadout` key, or the timer in `state StartupInLoadout` when spawning into a loadout room), even if the weapon is **holstered**. This wastes consumables, drains ammo, or spams HUD messages. Stock weapons are unaffected, because `Reload()` only reloads them.
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
Avoid fragile or redundant multi-state checks (such as querying `LoadoutActive` or `IsInState('Loadout')`, which can vary between client and server or desync during menu transitions). Mirror the engine's own checks, `RagePlayer.TryLoadoutZone` and `TryLoadoutCrate`. The crate check is a radius test against the player's collision radius. `LoadoutCrate` is the colliding actor (radius 129); the visible `LoadoutCrate_Blue`/`_Red`/`_DM` meshes are `Decoration`s:

```unrealscript
function bool IsAtLoadout()
{
    local LoadoutCrate LCrate;

    // 1. Player is inside a team spawn room / loadout zone
    if (Owner != None && Owner.Region.Zone.IsA('LoadoutZone'))
        return true;

    // 2. Player is within reach of a loadout crate
    foreach RadiusActors(class'LoadoutCrate', LCrate, Owner.CollisionRadius, Owner.Location)
        return true;

    return false;
}
```

> **Note**: For custom weapon `Reload()` abilities, the simplest mitigation against `TryLoadout` auto-firing is checking `if (Pawn(Owner).Weapon != self) return;`. This avoids blocking legitimate self-use while in a loadout zone while preventing holstered weapons from triggering.

### C. What Reaches `ArmorAbsorbDamage`
`Pawn.HeadZoneChange` sends zero-damage pings `Inventory.ReduceDamage(0, 'Breathe', ...)` and `(0, 'Drowned', ...)` when the head leaves or enters water. These never reach armor. `Inventory.ReduceDamage` only walks the armor chain while damage remains:
```unrealscript
ReducedAmount = Damage;
FirstArmor = PrioritizeArmor(Damage, DamageType, HitLocation);   // only queries ArmorPriority()
while( (FirstArmor != None) && (ReducedAmount > 0) )
    ReducedAmount = FirstArmor.ArmorAbsorbDamage(ReducedAmount, DamageType, HitLocation);
```
- `ArmorAbsorbDamage` is therefore only called with `Damage > 0`, so a `Damage <= 0` guard is redundant.
- `ArmorPriority(DamageType)` **is** called for every ping, including the zero-damage ones. Keep it side-effect free.
- `'Suicided'` goes straight to `Died()` and never reaches armor.
- `'Crushed'` comes from `Mover` via `TakeDamage` with real damage (10000 or `EncroachDamage`). Decide explicitly whether a cheat-death item absorbs it (`Totem` lets it through).

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
- When a **bot** runs out of ammo (and can't reload): the engine calls `PawnOwner.StopFiring(); PawnOwner.SwitchToBestWeapon();` and goes to `DownWeapon` if that set `bChangeWeapon`.
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
      if (PawnOwner != None)
      {
          PawnOwner.DeleteInventory(self);   // Inventory.Destroyed() would do this too...
          PawnOwner.SetSpeedFromInventory(); // ...but never drops the carry penalty (see 7H)
      }
      Destroy();
  }
  ```
  `Totem.DestroyConsumed()` implements exactly this.
