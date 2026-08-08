//=============================================================================
// TripLaser
//=============================================================================

class TripLaser extends TripBomb;

var byte PlacedTeam; // Team frozen at placement time, immune to mid-game team changes

function PostBeginPlay()
{
    PlacedTeam = Instigator.PlayerReplicationInfo.Team;
    Super.PostBeginPlay();
}

// Returns true if Other is the placer, a confirmed teammate, or a non-empty vehicle with ONLY friendly occupants
function bool IsFriendly(Actor Other)
{
    local Pawn P;
    local Vehicle V;
    local int i;
    local bool bFoundFriendly;

    if (Other == None)
        return false;

    // Ignore other trip lasers so they don't trigger each other
    if (Other.IsA('TripLaser') || Other.IsA('TripLaserOnGround') || Other.IsA('TripLaserThrown'))
        return true;

    V = Vehicle(Other);
    if (V != None)
    {
        bFoundFriendly = false;
        for (i = 0; i < V.NumSeats; i++)
        {
            if (V.aSeatsOccupant[i] != None)
            {
                if (Level.Game.bTeamGame)
                {
                    if (V.aSeatsOccupant[i].PlayerReplicationInfo.Team != PlacedTeam)
                        return false;
                    bFoundFriendly = true;
                }
                else
                {
                    if (V.aSeatsOccupant[i] != Instigator)
                        return false;
                    bFoundFriendly = true;
                }
            }
        }

        return bFoundFriendly;
    }

    P = Pawn(Other);
    if (P != None)
    {
        if (Level.Game.bTeamGame)
            return P.PlayerReplicationInfo.Team == PlacedTeam;
        else
            return P == Instigator;
    }

    return false;
}

//=============================================================================
//
//=============================================================================

function Timer ()
{
    // Activate the laser
    local vector HitLocation, HitNormal, Dir;
    local vector TraceStart;
    local Actor HitA;

    if (Owner.IsA('LevelInfo') || Owner.bWorldGeometry)
        SetOwner (None);
    else
    {
        AttachedLoc = Owner.Location;
        AttachedRot = Owner.Rotation;
        //AttachedRot.Roll += 16383;
    }

    // Tripwire style: fade at source end + different dot for contrast
    if (PlacedTeam >= 1)
    {
        Laser = Spawn(Class'RedBeamRifle', self,, Location, Rotation);
        if (Laser != None)
            Laser.LaserDot = Texture'RAGEEFFECTS.Laser.BlueLaserSpot_A01';
    }
    else
    {
        Laser = Spawn(Class'BlueBeamRifle', self,, Location, Rotation);
        if (Laser != None)
            Laser.LaserDot = Texture'RAGEEFFECTS.Laser.RedLaserSpot_A01';
    }

    Dir = Vector(Rotation);
    TraceEnd = Location + Dir * LaserMaxDistance;

    // Skip friendlies during placement setup
    TraceStart = Location;
    AnchorTraceLoop:
    HitA = Trace ( HitLocation, HitNormal, TraceEnd, TraceStart, true);
    if (HitA != None && IsFriendly(HitA) && VSize(HitLocation - Location) < LaserMaxDistance )
    {
        TraceStart = HitLocation + Dir * 2;
        Goto 'AnchorTraceLoop';
    }

    if (HitA != None)
        LaserEnd = HitLocation;
    else
        LaserEnd = TraceEnd;

    Laser.Set ( Location, LaserEnd );

    AmbientSound = Sound'WeaponSFX_TripBombs.Active';
    GotoState('Active');
}

state Active
{
    function Tick(float Delta)
    {
        local vector HitLocation, HitNormal, Dir;
        local Actor HitA;
        local Pawn P, XNextPawn;
        local float Dist;

        if (Owner != None && (AttachedLoc != Owner.Location || AttachedRot != Owner.Rotation))
        {
            Explode();
            return;
        }

        if (Laser != None)
        {
            HitA = Trace(HitLocation, HitNormal, TraceEnd, Location, true);
            if (HitA != None && Pawn(HitA) != None && !IsFriendly(HitA))
            {
                HitA.TakeDamage(280, Instigator, HitLocation, vect(0, 0, 0), 'RageWeaponsDOTTripBombs');
                Explode();
                return;
            }
        }

        // tell local bots about self
        for (P = Level.PawnList; P != None; P = XNextPawn)
        {
            XNextPawn = P.NextPawn;

            if (P.IsA('EngineBot'))
            {
                Dist = DistToLaser (P.Location);

                if (Dist < 800 && P.Weapon != None && RageWeapon(P.Weapon).bCanShootBombs && P != Instigator &&
				   (!Level.Game.bTeamGame || (P.PlayerReplicationInfo.Team != Instigator.PlayerReplicationInfo.Team)) && P.LineOfSightTo(self)
				) {
                    // Shoot enemy trip bombs
                    EngineBot(P).ShootTarget(self);
                    break;
                }

                if (Dist < (P.CollisionRadius * 3) &&
                    ((Level.Game.bTeamGame && (P.PlayerReplicationInfo.Team == Instigator.PlayerReplicationInfo.Team)) ||
                    (!Level.Game.bTeamGame && P == Instigator))
				) {
                    // Duck our own trip bombs
                    if (P.Location.Z >= Location.Z && P.Physics == PHYS_Walking)
                        EngineBot(P).BigJump(P.MoveTarget);
                    else
                        EngineBot(P).DuckLaser(self);
                    break;
                }
            }
        }
    }

    function Explode()
    {
        if (Laser != None)
            Laser.Destroy();
        Destroy();
    }

    event TakeDamage(int Damage, Pawn InstigatedBy, Vector HitLocation, Vector Momentum, name damageType)
    {
        Explode();
    }

}

defaultproperties
{
    LaserMaxDistance=1536.0
}
