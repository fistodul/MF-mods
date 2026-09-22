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

function bool GetPlacedTeam(Actor A, out byte OutTeam)
{
    local string S;

    if (A == None)
        return false;

    S = A.GetPropertyText("PlacedTeam");
    if (S != "")
    {
        OutTeam = byte(int(S));
        return true;
    }

    if (A.IsA('StationaryPawn'))
    {
        OutTeam = StationaryPawn(A).Team;
        return true;
    }

    return false;
}

function bool IsPawnFriendly(Pawn P)
{
    if (P == None || P.Health <= 0)
        return true;

    if (P.PlayerReplicationInfo != None)
    {
        if (Level.Game.bTeamGame)
            return P.PlayerReplicationInfo.Team == PlacedTeam;
        return P == Instigator;
    }

    return true;
}

// Returns true if Other is a confirmed teammate or a non-empty vehicle with ONLY friendly occupants
function bool IsFriendly(Actor Other)
{
    local Vehicle V;
    local int i;
    local bool bFoundFriendly;
    local byte OtherTeam;

    if (Other == None || Other == Self)
        return true;

    // Check generic PlacedTeam / Team attribute (TripLaser, SeekerMine, SentryGunTurret, etc.)
    if (GetPlacedTeam(Other, OtherTeam))
    {
        if (Level.Game.bTeamGame)
            return OtherTeam == PlacedTeam;
        return Other.Instigator == Instigator;
    }

    V = Vehicle(Other);
    if (V != None)
    {
        bFoundFriendly = false;
        for (i = 0; i < V.NumSeats; i++)
        {
            if (V.aSeatsOccupant[i] != None)
            {
                if (!IsPawnFriendly(V.aSeatsOccupant[i]))
                    return false;
                bFoundFriendly = true;
            }
        }
        return bFoundFriendly;
    }

    if (Other.IsA('Pawn'))
        return IsPawnFriendly(Pawn(Other));

    return false;
}

function Timer()
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
    HitA = Trace(HitLocation, HitNormal, TraceEnd, TraceStart, true);
    if (IsFriendly(HitA) && VSize(HitLocation - Location) < LaserMaxDistance)
    {
        TraceStart = HitLocation + Dir * 2;
        Goto 'AnchorTraceLoop';
    }

    if (HitA != None)
        LaserEnd = HitLocation;
    else
        LaserEnd = TraceEnd;

    Laser.Set(Location, LaserEnd);

    AmbientSound = Sound'WeaponSFX_TripBombs.Active';
    GotoState('Active');
}

state Active
{
    function Tick(float Delta)
    {
        local vector HitLocation, HitNormal, Dir;
        local Actor HitA;
        local Pawn P;
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
        for (P = Level.PawnList; P != None; P = P.NextPawn)
        {
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
     SoundVolume=80
     LaserMaxDistance=1536.000000
}
