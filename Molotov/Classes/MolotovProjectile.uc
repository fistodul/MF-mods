//=============================================================================
// Molotov cocktail projectile that creates a burning fire area upon exploding.
//=============================================================================

class MolotovProjectile extends Grenade1;

// override explosion to spawn fire too
simulated function Explosion(vector HitLocation, Rotator HitRotation)
{
    Spawn(class'MolotovFire', , , HitLocation);
    Super.Explosion(HitLocation, HitRotation);
}

defaultproperties
{
    Damage=44.0
}
