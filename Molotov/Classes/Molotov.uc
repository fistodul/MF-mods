//=============================================================================
// Molotov cocktail weapon - grenade that creates burning fire areas.
//=============================================================================

class Molotov extends Grenades;

defaultproperties
{
    MaxClipAmmo=2
    ProjectileClass=Class'Molotov.MolotovProjectile'
    AltProjectileClass=Class'Molotov.MolotovProjectileAlt'
    DeathMessage="%k Set %o on Fire."
    PickupMessage="Loaded up Molotov cocktails."
    ItemName="Molotov Cocktail"
}
