//=============================================================================
// TripLaserThrown
//=============================================================================

class TripLaserThrown extends TripBombThrown;

simulated function HitWall(vector HitNormal, actor Wall)
{
    if (Wall.IsA('LoadoutBlocker'))
    {
        Destroy();
        return;
    }

    bCanHitOwner = true;
    Velocity = 0.75 * ((Velocity dot HitNormal) * HitNormal * -2.0 + Velocity); // Reflect off Wall w/damping
    Velocity.Z *= 0.5;
    DesiredRotation.Yaw = 2 * FRand();
    speed = VSize(Velocity);

    if (Level.NetMode != NM_DedicatedServer)
        PlaySound(ImpactSound, SLOT_Misc, 1.5);

    if (speed < 160)
    {
        bFixedRotationDir = false;
        DesiredRotation=Rotation;
        bBounce = false;
        SetPhysics(PHYS_None);

        // on the server spawn a bomb where we landed
        if (Role == Role_Authority)
            Spawn(Class'TripLaserOnGround',, '', Location - vect(0, 0, 7), Rotation);

        Destroy();
    }

    if (Level.NetMode != NM_DedicatedServer)
        PlaySound(Sound'WeaponSFX_TripBombs.Bounce', SLOT_Misc, 1.5);

}
