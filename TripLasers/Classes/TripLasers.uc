//=============================================================================
// TripLasers
//=============================================================================

class TripLasers extends TripBombs;

function bool TryAndStick()
{
    local vector HitLocation, HitNormal, StartTrace, EndTrace, X, Y, Z;
    local actor Other;
    local Pawn PawnOwner;
    local bool bBot;
    local Rotator UseRot;
    local vector BombStart, BombEnd, BombHitLocation, BombHitNormal;

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
        BombStart = HitLocation;
        BombEnd = Location + (HitNormal * MaxLaserDistance);
        if (Trace(BombHitLocation, BombHitNormal, BombEnd, BombStart, true,) != None)
        {
            LastBombPlaced = Spawn(Class'TripLaser', Other,, HitLocation, Rotator(HitNormal));
            return true;
        }
    }

    return false;
}

function ThrowTripBomb()
{
    local TripBombThrown Bomb;
    local vector X, Y, Z;

    UseAmmo(1);
    GetAxes(Pawn(Owner).ViewRotation, X, Y, Z);

    ProjectileSpeed = ThrowPower * 125;
    ProjectileFire(Class'TripLaserThrown', ProjectileSpeed, bAltWarnTarget);
    ClientThrowTripBomb();
}

defaultproperties
{
     MaxLaserDistance=1536.000000
     MaxClipAmmo=3
     DeathMessage="%k Disintegrated %o."
     PickupMessage="Loaded up TripLasers."
     ItemName="Trip Laser"
}
