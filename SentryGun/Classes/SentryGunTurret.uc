//=============================================================================
// SentryGunTurret - Autonomous Stationary Sentry Gun Turret
//=============================================================================
class SentryGunTurret extends StationaryPawn;

var config int MaxSentryAmmo;
var config int SentryHealth;
var config float ScanRange;
var config int ShotDamage;
var config float FireInterval;
var config float AccuracySpread;
var config float TurnRate;

var int CurrentAmmo;
var Actor TargetEnemy;
var SentryGunTripod Tripod;
var bool bDead;

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();

    CurrentAmmo = MaxSentryAmmo;
    Health = SentryHealth;
    SetPhysics(PHYS_None);

    if (Role == ROLE_Authority)
        Tripod = Spawn(class'SentryGunTripod', self,, Location - vect(0,0,20), Rotation);
}

simulated function PostNetBeginPlay()
{
    Super.PostNetBeginPlay();
    UpdateTeamVisuals();
}

function InitPlacer(Pawn Placer)
{
    Instigator = Placer;
    if (Instigator != None && Instigator.PlayerReplicationInfo != None)
    {
        Team = Instigator.PlayerReplicationInfo.Team;
        UpdateTeamVisuals();
    }
}

simulated function UpdateTeamVisuals()
{
    if (Team == 0)
        LightHue = 170; // Blue team
    else if (Team == 1)
        LightHue = 0;   // Red team
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
    local byte OtherTeam;

    if (P == None || P.Health <= 0)
        return true;

    // Check generic PlacedTeam / Team attribute (SentryGunTurret, SeekerMine, etc.)
    if (GetPlacedTeam(P, OtherTeam))
    {
        if (Level.Game != None && Level.Game.bTeamGame)
            return OtherTeam == Team;
        return P.Instigator == Instigator;
    }

    // Players and bots with PlayerReplicationInfo
    if (P.PlayerReplicationInfo != None)
    {
        if (Level.Game != None && Level.Game.bTeamGame)
            return P.PlayerReplicationInfo.Team == Team;
        return P == Instigator;
    }


    return true;
}

function bool IsFriendly(Actor Other)
{
    local byte OtherTeam;
    local Vehicle V;
    local int i;
    local bool bHasOccupant;

    if (Other == None || Other == Self)
        return true;

    // 1. Generic check for any actor with PlacedTeam / Team attribute (SeekerMine, SentryGunTurret, TripLaser, etc.)
    if (GetPlacedTeam(Other, OtherTeam))
    {
        if (Level.Game != None && Level.Game.bTeamGame)
            return OtherTeam == Team;
        return Other.Instigator == Instigator;
    }

    // 2. Vehicle check
    V = Vehicle(Other);
    if (V != None)
    {
        for (i = 0; i < V.NumSeats; i++)
        {
            if (V.aSeatsOccupant[i] != None)
            {
                bHasOccupant = true;
                if (!IsPawnFriendly(V.aSeatsOccupant[i]))
                    return false;
            }
        }
        return true;
    }

    // 3. Pawn check
    if (Other.IsA('Pawn'))
        return IsPawnFriendly(Pawn(Other));

    return true;
}

function vector GetTargetAimPoint(Actor A)
{
    local Pawn P;

    P = Pawn(A);
    if (P != None && !P.IsA('SentryGunTurret'))
        return P.Location + vect(0,0,1) * (P.EyeHeight * 0.5);

    return A.Location + vect(0,0,15);
}

function bool IsValidTarget(Actor A)
{
    local vector MuzzleLoc, TargetPoint;

    if (A == None || A.bDeleteMe || IsFriendly(A))
        return false;

    if (A.IsA('Pawn') && Pawn(A).Health <= 0)
        return false;

    if (VSize(A.Location - Location) > ScanRange)
        return false;

    MuzzleLoc = Location + vect(0,0,10);
    TargetPoint = GetTargetAimPoint(A);

    return FastTrace(TargetPoint, MuzzleLoc);
}

function Actor FindBestTarget()
{
    local Pawn P;
    local EnginePhysical Veh, XNextPhysic;
    local Vehicle V;
    local Actor Best;
    local float Dist, BestDist;
    local vector MuzzleLoc;

    BestDist = ScanRange;
    MuzzleLoc = Location + vect(0,0,10);

    // 1. Check occupied enemy vehicles
    for (Veh = Level.VehicleList; Veh != None; Veh = XNextPhysic)
    {
        XNextPhysic = Veh.NextPhysical;
        V = Vehicle(Veh);
        if (V != None && !IsFriendly(V))
        {
            Dist = VSize(Location - V.Location);
            if (Dist < BestDist)
            {
                if (FastTrace(V.Location + vect(0,0,15), MuzzleLoc))
                {
                    BestDist = Dist;
                    Best = V;
                }
            }
        }
    }

    // 2. Check enemy pawns
    for (P = Level.PawnList; P != None; P = P.NextPawn)
    {
        if (P != Self && P.Health > 0 && !IsFriendly(P) && (!P.IsA('StationaryPawn') || P.IsA('SentryGunTurret')))
        {
            Dist = VSize(Location - P.Location);
            if (Dist < BestDist)
            {
                if (FastTrace(GetTargetAimPoint(P), MuzzleLoc))
                {
                    BestDist = Dist;
                    Best = P;
                }
            }
        }
    }

    return Best;
}

function string KillMessage(name damageType, pawn Other)
{
    if (Instigator != None && Instigator.PlayerReplicationInfo != None)
        return Instigator.PlayerReplicationInfo.PlayerName $ "'s Sentry Gun shredded " $ Other.PlayerReplicationInfo.PlayerName;

    return Other.PlayerReplicationInfo.PlayerName $ " was shredded by a Sentry Gun";
}

function bool UpdateTurretRotation(Actor Target, float DeltaTime)
{
    local vector FireStart, TargetPoint, AimDir;
    local rotator DesiredRot, NewRot;
    local int YawDiff, PitchDiff, MaxStep;

    if (Target == None)
        return false;

    FireStart = Location + vect(0,0,10);
    TargetPoint = GetTargetAimPoint(Target);
    AimDir = Normal(TargetPoint - FireStart);
    if (VSize(AimDir) < 0.001)
        return false;

    DesiredRot = rotator(AimDir);
    if (TurnRate <= 0.0)
    {
        SetRotation(DesiredRot);
        return true;
    }

    YawDiff = (DesiredRot.Yaw - Rotation.Yaw) & 65535;
    if (YawDiff > 32768)
        YawDiff -= 65536;

    PitchDiff = (DesiredRot.Pitch - Rotation.Pitch) & 65535;
    if (PitchDiff > 32768)
        PitchDiff -= 65536;

    if (DeltaTime > 0.0)
    {
        MaxStep = int(TurnRate * 182.0444 * DeltaTime);
        if (MaxStep < 1)
            MaxStep = 1;

        NewRot = Rotation;
        if (Abs(YawDiff) <= MaxStep)
            NewRot.Yaw = DesiredRot.Yaw;
        else if (YawDiff > 0)
            NewRot.Yaw += MaxStep;
        else
            NewRot.Yaw -= MaxStep;

        if (Abs(PitchDiff) <= MaxStep)
            NewRot.Pitch = DesiredRot.Pitch;
        else if (PitchDiff > 0)
            NewRot.Pitch += MaxStep;
        else
            NewRot.Pitch -= MaxStep;

        NewRot.Roll = 0;
        SetRotation(NewRot);
    }

    return (Abs(YawDiff) < 2730 && Abs(PitchDiff) < 2730);
}

function FireShot()
{
    local vector FireStart, AimDir, EndTrace, HitLocation, HitNormal, X, Y, Z;
    local actor HitActor;

    if (CurrentAmmo <= 0)
        return;

    CurrentAmmo--;

    FireStart = Location + vect(0,0,10);
    GetAxes(Rotation, X, Y, Z);

    AimDir = Normal(X + (FRand() - 0.5) * AccuracySpread * Y + (FRand() - 0.5) * AccuracySpread * Z);
    EndTrace = FireStart + AimDir * ScanRange;

    HitActor = Trace(HitLocation, HitNormal, EndTrace, FireStart, true);
    if (HitActor == None)
        HitLocation = EndTrace;

    SpawnTracer(FireStart, HitLocation);

    PlaySound(Sound'WeaponSFX_HeavyMachineGun.Fire', SLOT_Misc, 3.0);
    MakeNoise(1.0);

    if (HitActor != None)
        ProcessTraceHit(HitActor, HitLocation, HitNormal, AimDir);
}

function ProcessTraceHit(Actor Other, Vector HitLoc, Vector HitNorm, Vector Dir)
{
    local Pawn DamageInstigator;

    if (Other == None || Other == Self)
        return;

    if (Other == Level || Other.bWorldGeometry)
    {
        Class'RageEffects.RageEffect'.static.AddWallHit(self, HitLoc + HitNorm, Rotator(HitNorm));
    }
    else
    {
        if (Other.bIsPawn)
            Other.PlaySound(Sound'MiscSFX.RageChunkHit',, 4.0,, 100);

        if (Instigator != None)
            DamageInstigator = Instigator;
        else
            DamageInstigator = Self;

        Other.TakeDamage(ShotDamage, DamageInstigator, HitLoc, Dir * 1000, 'tracedshot');

        if (!Other.bIsPawn && !Other.IsA('Carcass'))
            Spawn(class'RageSpriteSmokePuff',,, HitLoc + HitNorm * 9);
    }
}

function SpawnTracer(vector Start, vector End)
{
    local vector Dir, DirL;
    local float Len;
    local FakeTracer Fake;

    DirL = End - Start;
    Len = VSize(DirL);
    if (Len < 128)
        return;

    Dir = DirL / Len;
    Start += Dir * 40;

    if (Level.NetMode != NM_DedicatedServer && Level.Particles != None)
        Level.Particles.AddOne(Start, Dir * 3000, Texture'RageEffects.TracerTex', 255, 0.1, 2+256+512, FMin(2, Len / 3000));

    if (Level.NetMode == NM_DedicatedServer || Level.NetMode == NM_ListenServer)
    {
        Fake = Spawn(class'FakeTracer', Self,, Start);
        if (Fake != None)
        {
            Fake.DirL = DirL;
            Fake.Flag = 1;
        }
    }
}

auto state Deploying
{
Begin:
    PlaySound(Sound'WeaponSFX_TripBombs.Activating', SLOT_Misc, 2.0);
    Sleep(0.4);
    GotoState('Scanning');
}

state Scanning
{
    function Timer()
    {
        if (CurrentAmmo <= 0)
        {
            GotoState('OutOfAmmo');
            return;
        }

        TargetEnemy = FindBestTarget();
        if (TargetEnemy != None)
        {
            PlaySound(Sound'WeaponSFX_TripBombs.Activating', SLOT_Misc, 1.5);
            GotoState('Firing');
        }
    }

    function BeginState()
    {
        TargetEnemy = None;
        SetTimer(0.2, true);
    }

    function EndState()
    {
        SetTimer(0.0, false);
    }
}

state Firing
{
    function Tick(float Delta)
    {
        if (!bDead && TargetEnemy != None && IsValidTarget(TargetEnemy))
            UpdateTurretRotation(TargetEnemy, Delta);
    }

    function Timer()
    {
        if (CurrentAmmo <= 0)
        {
            GotoState('OutOfAmmo');
            return;
        }

        if (!IsValidTarget(TargetEnemy))
        {
            TargetEnemy = FindBestTarget();
            if (TargetEnemy == None)
            {
                GotoState('Scanning');
                return;
            }
        }

        if (TurnRate <= 0.0 || UpdateTurretRotation(TargetEnemy, 0.0))
            FireShot();

        if (CurrentAmmo <= 0)
        {
            GotoState('OutOfAmmo');
            return;
        }
    }

    function BeginState()
    {
        SetTimer(FireInterval, true);
    }

    function EndState()
    {
        SetTimer(0.0, false);
    }
}

state OutOfAmmo
{
    function BeginState()
    {
        SetTimer(0.0, false);
        LightType = LT_None;
    }

Begin:
    PlaySound(Sound'WeaponSFX_HeavyMachineGun.SpinDown', SLOT_Misc, 3.0);
    Sleep(0.7);
    Destroy();
}

event TakeDamage(int DamageAmount, Pawn DamageInstigator, Vector HitLocation, Vector Momentum, name damageType)
{
    Health -= DamageAmount;
    if (Health <= 0 && !bDead)
        BlowUp();
}

function BlowUp()
{
    local vector ExplodeLoc;

    if (bDead)
        return;

    bDead = true;
    ExplodeLoc = Location + vect(0,0,10);

    HurtRadius(80, 250, 'RageWeaponsDOTTripBombs', 70000, ExplodeLoc);
    MakeNoise(1.0);

    Class'RageEffects.RageEffect'.static.AddExplosionServer(self, ExplodeLoc, 2.5, vect(0,0,1));
    PlaySound(Sound'WeaponSFX_TripBombs.Bounce', SLOT_Misc, 2.0);

    Destroy();
}

simulated event Destroyed()
{
    if (Tripod != None)
    {
        Tripod.Destroy();
        Tripod = None;
    }

    Super.Destroyed();
}

defaultproperties
{
     MaxSentryAmmo=850
     SentryHealth=80
     ScanRange=1900.000000
     ShotDamage=20
     FireInterval=0.150000
     AccuracySpread=0.025000
     TurnRate=90.000000
     Team=255
     Health=80
     DrawType=DT_Mesh
     Mesh=LodMesh'RageWeapons.HeavyMachineGunPickupCarryMesh'
     DrawScale=1.250000
     CollisionRadius=20.000000
     CollisionHeight=22.000000
     bCollideActors=True
     bCollideWorld=True
     bBlockActors=True
     bBlockPlayers=True
     bProjTarget=True
     bCanFly=False
     LightType=LT_Pulse
     LightBrightness=255
     LightHue=40
     LightRadius=12
     RemoteRole=ROLE_SimulatedProxy
     bAlwaysRelevant=True
     NetPriority=2.500000
}
