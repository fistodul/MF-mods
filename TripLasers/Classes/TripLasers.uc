//=============================================================================
// TripLasers
//=============================================================================

class TripLasers extends TripBombs;

#exec TEXTURE IMPORT NAME=TripLaserIcon FILE=Textures\triplaser_icon.bmp GROUP=Icons MIPS=OFF Flags=2

var int MaxActiveLasers;

// Planted, on-ground and in-flight lasers all count, so quick throws can't exceed the cap
function int CountActiveLasers()
{
    local Actor A;
    local int Count;

    foreach AllActors(class'Actor', A)
    {
        if (A.Instigator == Owner && (TripLaser(A) != None || TripLaserOnGround(A) != None || TripLaserThrown(A) != None))
            Count++;
    }
    return Count;
}

function bool AtLaserLimit()
{
    if (CountActiveLasers() < MaxActiveLasers)
        return false;

    Pawn(Owner).ClientMessage("Max active Trip Lasers reached: " $ MaxActiveLasers);
    return true;
}

function bool TryAndStick()
{
    local vector HitLocation, HitNormal, StartTrace, EndTrace, X, Y, Z;
    local actor Other;
    local Pawn PawnOwner;
    local bool bBot;
    local Rotator UseRot;

    if (AtLaserLimit())
        return false;

    PawnOwner = Pawn(Owner);
    bBot = Owner.IsA('EngineBot');

    Owner.MakeNoise(PawnOwner.SoundDampening);
    UseRot = PawnOwner.ViewRotation;
    if (bBot)
    {
        UseRot.Pitch = 0;
        UseRot.Roll = 0;
    }

    GetAxes(UseRot, X, Y, Z);
    StartTrace = Owner.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z; 

    if (bBot)
        AdjustedAim = UseRot;
    else
        AdjustedAim = PawnOwner.AdjustAim(1000000, StartTrace, 2 * AimError, False, False);

    EndTrace = StartTrace;
    X = vector(AdjustedAim);

    if (bBot)
        EndTrace += (400 * X); 
    else
        EndTrace += (50 * X); 

    Other = PawnOwner.TraceShot(HitLocation, HitNormal, EndTrace, StartTrace);
    if (Other != None && (Pawn(Other) == None || !Pawn(Other).bIsPlayer)) // Dont stick to players
    {
        LastBombPlaced = Spawn(Class'TripLaser', Other,, HitLocation, Rotator(HitNormal));
        return true;
    }

    return false;
}

function ThrowTripBomb()
{
    local vector X, Y, Z;

    if (AtLaserLimit())
        return;

    UseAmmo(1);
    GetAxes(Pawn(Owner).ViewRotation, X, Y, Z);

    ProjectileSpeed = ThrowPower * 125;
    ProjectileFire(Class'TripLaserThrown', ProjectileSpeed, bAltWarnTarget);
    ClientThrowTripBomb();
}

defaultproperties
{
     MaxActiveLasers=10
     MaxLaserDistance=1500.000000
     MaxClipAmmo=3
     WeaponIcon=(X=0,t=Texture'triplasers.Icons.TripLaserIcon')
     DeathMessage="%k Disintegrated %o."
     PickupMessage="Loaded up TripLasers."
     ItemName="Trip Laser"
}
