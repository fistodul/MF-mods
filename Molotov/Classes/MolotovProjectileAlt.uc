//=============================================================================
// Molotov cocktail projectile that explodes on contact.
//=============================================================================

class MolotovProjectileAlt extends Grenade2;

// override explosion to spawn fire too
simulated function Explosion(vector HitLocation, Rotator HitRotation)
{
	Spawn(class'MolotovFire', , , Location);
	Super.Explosion(HitLocation, HitRotation);
}

defaultproperties
{
    Damage=40.000000
}
