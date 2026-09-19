//=============================================================================
// SeekerMine - Autonomous Hunter-Killer Drone / Spider Mine
//=============================================================================
class SeekerMine extends Pawn;

var byte PlacedTeam;
var Pawn Placer;
var Actor TargetEnemy;
var() config bool bFlyer;
var() config float SeekRadius;
var() config int Damage;
var() config float DamageRadius;
var bool bDetonated;

function PostBeginPlay()
{
    Super.PostBeginPlay();

    if (Instigator != None)
        InitPlacer(Instigator);
    else
        PlacedTeam = 255;

    if (bFlyer)
        SetPhysics(PHYS_Flying);
    else
        SetPhysics(PHYS_Walking);

    UpdateTeamLight();
    AmbientSound = Sound'WeaponSFX_TripBombs.Active';
}

function InitPlacer(Pawn InPlacer)
{
    if (InPlacer == None)
        return;

    Placer = InPlacer;
    Instigator = InPlacer;

    if (InPlacer.PlayerReplicationInfo != None)
        PlacedTeam = InPlacer.PlayerReplicationInfo.Team;
    else
        PlacedTeam = 255;

    UpdateTeamLight();
}

function UpdateTeamLight()
{
    if (PlacedTeam == 0)
        LightHue = 170; // Blue
    else if (PlacedTeam == 1)
        LightHue = 0;   // Red
    else
        LightHue = 40;  // Amber / Deathmatch
}

function float GetMoveSpeed()
{
    if (bFlyer)
        return AirSpeed;
    return GroundSpeed;
}

function bool IsPawnFriendly(Pawn P)
{
    if (P == None || P.Health <= 0 || P == Placer)
        return true;
    if (Level.Game.bTeamGame)
        return P.PlayerReplicationInfo != None && P.PlayerReplicationInfo.Team == PlacedTeam;
    return false;
}

function bool IsFriendly(Actor Other)
{
    local Vehicle V;
    local int i;

    if (Other == None || Other == Self || Other == Placer || Other.IsA('SeekerMine'))
        return true;

    V = Vehicle(Other);
    if (V != None)
    {
        for (i = 0; i < V.NumSeats; i++)
        {
            if (!IsPawnFriendly(V.aSeatsOccupant[i]))
                return false;
        }
        return true;
    }

    if (Other.IsA('Pawn'))
        return IsPawnFriendly(Pawn(Other));

    return true;
}

function Actor FindBestTarget()
{
    local Pawn P;
    local EnginePhysical Veh, XNextPhysic;
    local Vehicle V;
    local Actor Best;
    local float Dist, BestDist;

    BestDist = SeekRadius;

    // 1. Scan for occupied enemy vehicles
    for (Veh = Level.VehicleList; Veh != None; Veh = XNextPhysic)
    {
        XNextPhysic = Veh.NextPhysical;
        V = Vehicle(Veh);
        if (V != None && !IsFriendly(V))
        {
            Dist = VSize(Location - V.Location);
            if (Dist < BestDist)
            {
                BestDist = Dist;
                Best = V;
            }
        }
    }

    // 2. Scan for enemy pawns
    for (P = Level.PawnList; P != None; P = P.NextPawn)
    {
        if (P.Health > 0 && !IsFriendly(P))
        {
            Dist = VSize(Location - P.Location);
            if (Dist < BestDist)
            {
                BestDist = Dist;
                Best = P;
            }
        }
    }

    return Best;
}

function BlowUp()
{
    local vector ExplodeLoc;

    if (bDetonated)
        return;

    bDetonated = true;
    ExplodeLoc = Location + vect(0,0,16);

    HurtRadius(Damage, DamageRadius, 'RageWeaponsDOTTripBombs', 75000, ExplodeLoc);
    MakeNoise(1.0);

    if (Level.NetMode != NM_DedicatedServer)
        Class'RageEffects.RageEffect'.static.AddExplosion(self, ExplodeLoc, 3.5, vect(0,0,1));

    PlaySound(Sound'WeaponSFX_TripBombs.Bounce', SLOT_Misc, 2.0);
    Destroy();
}

simulated function Touch(Actor Other)
{
    if (!bDetonated && !IsFriendly(Other) && (Other.IsA('Pawn') || Other.IsA('Vehicle')))
        GotoState('Detonating');
}

simulated function Bump(Actor Other)
{
    Touch(Other);
}

event TakeDamage(int DamageAmount, Pawn InstigatedBy, Vector HitLocation, Vector Momentum, name damageType)
{
    Health -= DamageAmount;
    if (Health <= 0 && !bDetonated)
        BlowUp();
}

auto state Deploying
{
Begin:
    PlaySound(Sound'WeaponSFX_TripBombs.Activating', SLOT_Misc, 2.0);
    Sleep(0.35);
    GotoState('Hunting');
}

state Hunting
{
Begin:
Scan:
    TargetEnemy = FindBestTarget();
    if (TargetEnemy == None)
    {
        // If deployer is alive and nearby, escort them
        if (Placer != None && Placer.Health > 0 && VSize(Location - Placer.Location) < 2500)
            GotoState('Escorting');
        else
            GotoState('Roaming');
    }

    PlaySound(Sound'WeaponSFX_TripBombs.Activating', SLOT_Misc, 1.5);

Chase:
    if (TargetEnemy == None || IsFriendly(TargetEnemy) || (Pawn(TargetEnemy) != None && Pawn(TargetEnemy).Health <= 0))
        Goto('Scan');

    // If within blast detonation range (~130 units):
    if (VSize(Location - TargetEnemy.Location) <= 130.0)
        GotoState('Detonating');

    // Check direct reachable line of sight
    if (actorReachable(TargetEnemy))
    {
        TurnToward(TargetEnemy);
        MoveToward(TargetEnemy, GetMoveSpeed());
        Goto('Chase');
    }

    // Obstructed by walls/geometry: find pathnode toward target
    MoveTarget = FindPathToward(TargetEnemy);
    if (MoveTarget != None)
    {
        TurnToward(MoveTarget);
        MoveToward(MoveTarget, GetMoveSpeed());
        Goto('Chase');
    }
    else
    {
        // No node path found: move in general direction of enemy
        MoveTo(Location + Normal(TargetEnemy.Location - Location) * 150, GetMoveSpeed() * 0.7);
        Sleep(0.1);
        Goto('Scan');
    }
}

state Escorting
{
Begin:
FollowLoop:
    TargetEnemy = FindBestTarget();
    if (TargetEnemy != None)
        GotoState('Hunting');

    if (Placer == None || Placer.Health <= 0)
        GotoState('Roaming');

    // Follow / guard around placer at a comfortable distance (~450 units)
    if (VSize(Location - Placer.Location) > 450.0)
    {
        if (actorReachable(Placer))
        {
            TurnToward(Placer);
            MoveToward(Placer, GetMoveSpeed() * 0.85);
        }
        else
        {
            MoveTarget = FindPathToward(Placer);
            if (MoveTarget != None)
            {
                TurnToward(MoveTarget);
                MoveToward(MoveTarget, GetMoveSpeed() * 0.85);
            }
            else
                Sleep(0.3);
        }
    }
    else if (VSize(Location - Placer.Location) < 250.0)
    {
        // Too close to player: back up slightly to maintain the guarding perimeter
        Velocity = Velocity * 0.3;
        TurnToward(Placer);
        MoveTo(Location + Normal(Location - Placer.Location) * 160.0, GetMoveSpeed() * 0.5);
    }
    else
    {
        // Orbiting / hovering in the guard perimeter
        Velocity = Velocity * 0.5;
        TurnToward(Placer);
        Sleep(0.25);
    }

    Sleep(0.1);
    Goto('FollowLoop');
}

state Roaming
{
Begin:
RoamLoop:
    TargetEnemy = FindBestTarget();
    if (TargetEnemy != None)
        GotoState('Hunting');

    if (Placer != None && Placer.Health > 0 && VSize(Location - Placer.Location) < 2000)
        GotoState('Escorting');

    MoveTarget = FindRandomDest();
    if (MoveTarget != None)
    {
        TurnToward(MoveTarget);
        MoveToward(MoveTarget, GetMoveSpeed() * 0.5);
    }
    else
        Sleep(0.5);

    Sleep(0.2);
    Goto('RoamLoop');
}

state Detonating
{
    ignores Touch, Bump, TakeDamage;

Begin:
    PlaySound(Sound'WeaponSFX_TripBombs.Activating', SLOT_Misc, 3.0);
    Sleep(0.12);
    BlowUp();
}

defaultproperties
{
     bFlyer=True
     SeekRadius=1800.000000
     Damage=350
     DamageRadius=450.000000
     Health=75
     AirSpeed=620.000000
     GroundSpeed=540.000000
     AccelRate=2400.000000
     DrawType=DT_Mesh
     Mesh=LodMesh'RageWeapons.TripBombsThrowMesh'
     DrawScale=2.000000
     CollisionRadius=24.000000
     CollisionHeight=16.000000
     LightType=LT_Pulse
     LightBrightness=255
     LightRadius=12
}
