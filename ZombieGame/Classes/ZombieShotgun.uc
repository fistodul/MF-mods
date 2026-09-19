//=============================================================================
// ZombieShotgun - Simplified slam-fire shotgun
//=============================================================================
class ZombieShotgun extends Shotgun;

// Both fire modes do the same thing: fire a single blast using 1 ammo
function Fire(float Value)
{
    if (AmmoInClip() && UseAmmo(1) && Pawn(Owner) != None && Pawn(Owner).CanFire())
    {
        LeftLoaded = false;
        GotoState('NormalFire');
        bPointing = True;
        NotifyClientFire();
        Pawn(Owner).PlayRecoil(FiringSpeed);
        TraceFire(Accuracy);
        FireBeginTime = Level.TimeSeconds;
        FlashCount++;
    }
}

function AltFire( float Value )
{
    Fire(Value);
}

simulated function bool ClientFire(float Value)
{
    if (RagePlayerBase(Owner) != None && RagePlayerBase(Owner).LoadoutActive)
        return false;

    NotifyClientFire();
}

simulated function bool ClientAltFire( float Value )
{
    return ClientFire(Value);
}

// After reload or GiveFullAmmo, always mark both barrels as loaded
function bool ReloadAmmo()
{
    local bool Ret;
    Ret = Super.ReloadAmmo();

    LeftLoaded = true;
    RightLoaded = true;

    return Ret;
}

// Slightly more damage per pellet (15 vs 12) for zombie stopping power
function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
    if (Other == None)
        return;

    if (Other == Level || Other.bWorldGeometry == true)
        Class'RageEffects.RageEffect'.static.AddWallHit(self, HitLocation + HitNormal, Rotator(HitNormal));
    else if ((Other != self) && (Other != Owner) && (Other != None))
    {
        if (Other.bIsPawn)
            Other.PlaySound(Sound'MiscSFX.RageChunkHit',, 4.0,, 100);

        Other.TakeDamage(15, Pawn(Owner), HitLocation, HitNormal * 1000, MyDamageType);

        if (!Other.bIsPawn && !Other.IsA('Carcass'))
            spawn(class'RageSpriteSmokePuff',,, HitLocation + HitNormal * 9);
    }
}

defaultproperties
{
     MaxClips=22
     NumShellFragments=12
     DeathMessage="%k blasted %o with the Boomstick."
     PickupMessage="Loaded up Zombie Boomstick."
     ItemName="Zombie Boomstick"
}
