//=============================================================================
// PredatorMissile - Steerable Tactical Nuclear Missile
//
// Network model:
//   Guiding machine (standalone, listen host or owning client) flies the missile
//   from local mouse/fire input and locks the camera behind it. A remote owning
//   client is fully trusted: it drives the server copy via ServerSyncFlight and
//   decides detonation via ServerImpact.
//   Server freezes the guider's body, does damage and publishes SrvLoc/SrvRot/SrvSpeed
//   for other clients (Location/Rotation of a ROLE_SimulatedProxy never replicate
//   after the initial packet).
//=============================================================================
class PredatorMissile extends Projectile;

var PredatorMissileWeapon ControllingWeapon;
var float BaseSpeed;
var float CurrentSpeed;
var bool bBoosting;
var float FlightTime;
var float SmokeTimer;
var Pawn BotTarget;

// Initial Launch Phase
var float InitialSlowDuration;      // Duration in seconds of initial slow drop phase
var float InitialSpeedFactor;       // Speed multiplier during initial slow drop

// Dive Angle Envelope (Degrees: 0 = level, 90 = straight down)
var float MinDiveAngleDegrees;      // Minimum downward dive angle in degrees
var float MaxDiveAngleDegrees;      // Maximum downward dive angle in degrees

// Steering Agility (Degrees per Second)
var float TurnRateNormal;          // Turn rate unboosted in deg/sec
var float TurnRateBoost;           // Turn rate boosting in deg/sec

// Speed & Flight Timing
var float TargetFlightTime;        // Target descent duration across all ceiling heights
var float BoostMultiplier;         // Speed multiplier when holding Fire/AltFire

// Detonation & Blast
var float BlastRadius;             // Blast damage radius in units

// Server -> other clients flight state
var vector  SrvLoc;
var rotator SrvRot;
var float   SrvSpeed;

// Server-only
var bool  bClientDriven;           // Remote guider's client flies the missile; ignore server collisions
var float LastSyncTime;            // Last ServerSyncFlight; watchdog detonates if syncs stop
var Pawn  FrozenPawn;
var float SavedGroundSpeed;
var float SavedJumpZ;

// Owning client only
var bool  bClientImpacted;
var float ClientSyncTimer;
var float ClientLogTimer;          // Throttled flight log while diagnosing stuck missiles

replication
{
    reliable if (Role == ROLE_Authority)
        BaseSpeed;
    unreliable if (Role == ROLE_Authority && !bNetOwner)
        SrvLoc, SrvRot, SrvSpeed, bBoosting;

    // Owning client -> server (missile Owner is the guiding PlayerPawn)
    unreliable if (Role < ROLE_Authority)
        ServerSyncFlight;
    reliable if (Role < ROLE_Authority)
        ServerImpact;
}

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    AmbientSound = Sound'WeaponSFX_RocketLauncher.RocketFly';
    SoundVolume = 255;
    SoundRadius = 255;
    SoundPitch = 64;
}

function InitializeFlight(float CeilingHeight)
{
    local PlayerPawn PP;

    // Target descent flight time adapted to ceiling height (bounded by Speed and MaxSpeed)
    BaseSpeed = FClamp(FClamp(CeilingHeight, 600.0, 10000.0) / FMax(TargetFlightTime, 1.0), Speed, MaxSpeed);

    // Start at initial slow speed to allow comfortable target acquisition
    CurrentSpeed = BaseSpeed * InitialSpeedFactor;
    Velocity = CurrentSpeed * vector(Rotation);

    PP = PlayerPawn(Instigator);
    bClientDriven = PP != None && !IsLocalPlayer(PP);
    log("Launch guider=" $ Instigator $ " clientDriven=" $ bClientDriven $ " baseSpeed=" $ BaseSpeed, 'PredatorMissile');
}

// Clamp a pitch into the dive envelope; returns an unsigned rotator pitch
static final function int ClampDivePitch(int Pitch)
{
    Pitch = Pitch & 65535;
    if (Pitch > 32768)
        Pitch -= 65536;
    return Clamp(Pitch, -int(default.MaxDiveAngleDegrees * 182.0444), -int(default.MinDiveAngleDegrees * 182.0444)) & 65535;
}

simulated final function int TurnToward(int Current, int Target, int MaxStep)
{
    local int Diff;

    Diff = (Target - Current) & 65535;
    if (Diff > 32768)
        Diff -= 65536;

    return (Current + Clamp(Diff, -MaxStep, MaxStep)) & 65535;
}

// Turn toward TargetRot at TurnRate (deg/sec) and fly at CurrentSpeed
simulated final function TurnTo(rotator TargetRot, float TurnRate, float DeltaTime)
{
    local rotator NewRot;
    local int MaxStep;

    MaxStep = int(TurnRate * 182.0444 * DeltaTime);
    NewRot.Yaw = TurnToward(Rotation.Yaw, TargetRot.Yaw, MaxStep);
    NewRot.Pitch = TurnToward(Rotation.Pitch, TargetRot.Pitch, MaxStep);
    SetRotation(NewRot);
    Velocity = CurrentSpeed * vector(NewRot);
}

simulated final function PlayerPawn GuidingPlayer()
{
    local PlayerPawn PP;

    PP = PlayerPawn(Owner);
    if (PP == None)
        PP = PlayerPawn(Instigator);
    return PP;
}

// True only on the machine whose viewport drives this pawn (standalone, listen host, owning client)
simulated final function bool IsLocalPlayer(PlayerPawn PP)
{
    return PP != None && PP.Player != None && PP.Player.IsA('Viewport');
}

function Pawn FindBotTarget()
{
    local Pawn P, BestP;
    local float Dist, BestDist;

    BestDist = 20000.0;
    for (P = Level.PawnList; P != None; P = P.NextPawn)
    {
        if (P != Instigator && P.Health > 0 && P.bProjTarget)
        {
            if (Level.Game.bTeamGame && P.PlayerReplicationInfo != None && Instigator.PlayerReplicationInfo != None &&
                P.PlayerReplicationInfo.Team == Instigator.PlayerReplicationInfo.Team)
                continue;

            Dist = VSize(P.Location - Location);
            if (Dist < BestDist)
            {
                BestDist = Dist;
                BestP = P;
            }
        }
    }
    return BestP;
}

// Runs only on the guiding machine: boost from fire buttons, turn toward the mouse view
simulated function SteerByPlayer(PlayerPawn PP, float DeltaTime)
{
    local rotator TargetRot;

    bBoosting = PP.bFire != 0 || PP.bAltFire != 0;
    if (bBoosting)
    {
        CurrentSpeed = FMin(CurrentSpeed + 2500.0 * DeltaTime, BaseSpeed * BoostMultiplier);
        SoundPitch = 96;
    }
    else
    {
        SoundPitch = 64;

        // Hold comfortable slow speed during the initial drop, then ease to cruising speed
        if (FlightTime < InitialSlowDuration)
            CurrentSpeed = BaseSpeed * InitialSpeedFactor;
        else if (CurrentSpeed < BaseSpeed)
            CurrentSpeed = FMin(CurrentSpeed + (BaseSpeed * 0.8) * DeltaTime, BaseSpeed);
        else
            CurrentSpeed = FMax(CurrentSpeed - 1200.0 * DeltaTime, BaseSpeed);
    }

    TargetRot = PP.ViewRotation;
    TargetRot.Pitch = ClampDivePitch(TargetRot.Pitch);
    if (bBoosting)
        TurnTo(TargetRot, TurnRateBoost, DeltaTime);
    else
        TurnTo(TargetRot, TurnRateNormal, DeltaTime);

    // Lock the camera behind the missile (CalcBehindView uses ViewRotation)
    PP.ViewRotation = Rotation;
}

function FreezeGuider(Pawn P)
{
    if (FrozenPawn == None)
    {
        FrozenPawn = P;
        SavedGroundSpeed = P.GroundSpeed;
        SavedJumpZ = P.JumpZ;
    }

    // Tiny non-zero speed: RPlayer.CheckBob divides by GroundSpeed.
    // GroundSpeed replicates to every client; JumpZ to the owner.
    P.GroundSpeed = 1.0;
    P.JumpZ = 0.0;
}

function UnfreezeGuider()
{
    if (FrozenPawn == None)
        return;

    FrozenPawn.GroundSpeed = SavedGroundSpeed;
    FrozenPawn.JumpZ = SavedJumpZ;
    FrozenPawn = None;
}

simulated function Tick(float DeltaTime)
{
    local PlayerPawn PP;

    SmokeTimer += DeltaTime;
    if (SmokeTimer >= 0.035)
    {
        SmokeTimer = 0.0;
        SpawnExhaust();
    }

    FlightTime += DeltaTime;

    if (Role == ROLE_Authority)
    {
        ServerTick(DeltaTime);
        return;
    }

    PP = GuidingPlayer();
    if (IsLocalPlayer(PP))
    {
        ClientLogTimer -= DeltaTime;
        if (ClientLogTimer <= 0.0)
        {
            ClientLogTimer = 2.0;
            log("Flight t=" $ FlightTime $ " loc=" $ Location $ " speed=" $ CurrentSpeed $ " phys=" $ Physics $ " impacted=" $ bClientImpacted, 'PredatorMissile');
        }

        if (bClientImpacted)
            return;

        // Fallback if BaseSpeed hasn't arrived yet
        if (BaseSpeed == 0.0)
            BaseSpeed = Speed;
        if (CurrentSpeed == 0.0)
            CurrentSpeed = BaseSpeed * InitialSpeedFactor;

        if (PP.ViewTarget == None)
        {
            PP.ViewTarget = self;
            PP.bBehindView = false;
        }
        SteerByPlayer(PP, DeltaTime);

        ClientSyncTimer -= DeltaTime;
        if (ClientSyncTimer <= 0.0)
        {
            ClientSyncTimer = 0.05;
            ServerSyncFlight(Location, Rotation.Yaw, Rotation.Pitch, CurrentSpeed, bBoosting);
        }
    }
    else if (SrvSpeed > 0)
    {
        // Other clients follow the server
        SetRotation(SrvRot);
        CurrentSpeed = SrvSpeed;
        Velocity = SrvSpeed * vector(SrvRot);
        if (VSize(SrvLoc - Location) > 1000.0)
            SetLocation(SrvLoc);
        else
            SetLocation(Location + (SrvLoc - Location) * FMin(1.0, DeltaTime * 8.0));
    }
}

function ServerTick(float DeltaTime)
{
    local PlayerPawn PP;

    // Destroy if owner died (a disconnect destroys the weapon, which destroys the missile)
    if (Instigator == None || Instigator.Health <= 0)
    {
        bClientDriven = false;
        Explode(Location, vect(0,0,1));
        return;
    }

    // Client-driven missile whose syncs stopped (client stalled or crashed): detonate where it is
    if (bClientDriven && FlightTime > 2.0 && Level.TimeSeconds - LastSyncTime > 1.0)
    {
        log("Watchdog: no client sync for " $ (Level.TimeSeconds - LastSyncTime) $ "s, detonating", 'PredatorMissile');
        bClientDriven = false;
        Explode(Location, vect(0,0,1));
        return;
    }

    PP = PlayerPawn(Instigator);
    if (PP != None)
    {
        FreezeGuider(PP);
        if (!bClientDriven)
            SteerByPlayer(PP, DeltaTime);
    }
    else if (EngineBot(Instigator) != None)
    {
        if (BotTarget == None || BotTarget.Health <= 0)
            BotTarget = FindBotTarget();

        if (BotTarget != None)
        {
            CurrentSpeed = BaseSpeed * 1.5;
            TurnTo(rotator(BotTarget.Location - Location), TurnRateNormal, DeltaTime);
        }
    }

    SrvLoc = Location;
    SrvRot = Rotation;
    SrvSpeed = VSize(Velocity);
}

// Owning client -> server: adopt the client's flight state
function ServerSyncFlight(vector ClientLoc, int ClientYaw, int ClientPitch, float ClientSpeed, bool bClientBoost)
{
    local rotator R;

    LastSyncTime = Level.TimeSeconds;
    R.Yaw = ClientYaw;
    R.Pitch = ClientPitch;
    SetLocation(ClientLoc);
    SetRotation(R);
    CurrentSpeed = ClientSpeed;
    Velocity = ClientSpeed * vector(R);
    bBoosting = bClientBoost;
    if (bBoosting)
        SoundPitch = 96;
    else
        SoundPitch = 64;
}

// Owning client -> server: the client hit something, detonate there
function ServerImpact(vector HitLocation, vector HitNormal)
{
    log("ServerImpact at " $ HitLocation $ " serverLoc=" $ Location $ " t=" $ FlightTime, 'PredatorMissile');
    bClientDriven = false;
    Explode(HitLocation, HitNormal);
}

simulated function SpawnExhaust()
{
    local vector ExhaustLoc, BackDir;
    local float FlameScale;

    if (Level.NetMode == NM_DedicatedServer || bClientImpacted)
        return;

    BackDir = -vector(Rotation);
    ExhaustLoc = Location + BackDir * 45.0;

    // White smoke trail
    Level.Particles.AddOne(ExhaustLoc + VRand() * 4.0,
                           BackDir * (CurrentSpeed * 0.1),
                           Texture'RageEffects.WispySmoke.WindySmoke_A01',
                           255,
                           0.8,
                           2+16+128,
                           0.9);

    // Rocket thruster fire
    if (bBoosting)
        FlameScale = 0.7;
    else
        FlameScale = 0.45;

    Level.Particles.AddOne(ExhaustLoc + VRand() * 2.0,
                           BackDir * (CurrentSpeed * 0.25),
                           Texture'RageEffects.OldFire.OldFire_A01',
                           255,
                           FlameScale,
                           2+16+128+2048,
                           0.9);
}

simulated function HitWall(vector HitNormal, actor Wall)
{
    Explode(Location + ExploWallOut * HitNormal, HitNormal);
}

simulated function ProcessTouch(actor Other, vector HitLocation)
{
    if (Other != Instigator)
        Explode(HitLocation, Normal(HitLocation - Other.Location));
}

simulated function Touch(actor Other)
{
    if (Other != Instigator && !Other.IsA('Projectile'))
        Explode(Location, Normal(Location - Other.Location));
}

simulated function Landed(vector HitNormal)
{
    Explode(Location, HitNormal);
}

simulated function Explode(vector HitLocation, vector HitNormal)
{
    // Clients never detonate. The owning client reports its hit and waits for the
    // server's Destroy; other clients ignore local hits and keep following the server.
    if (Role < ROLE_Authority)
    {
        if (!bClientImpacted && IsLocalPlayer(GuidingPlayer()))
        {
            log("Client impact at " $ HitLocation $ " t=" $ FlightTime, 'PredatorMissile');
            bClientImpacted = true;
            Velocity = vect(0,0,0);
            SetPhysics(PHYS_None);
            ServerImpact(HitLocation, HitNormal);
        }
        return;
    }

    // A client-driven server copy only detonates through ServerImpact
    if (bClientDriven)
        return;

    PlaySound(Sound'MiscSFX.Explode', SLOT_None, 16.0, true, 8000.0);

    Class'RageEffects.RageEffect'.static.AddExplosionServer(self, HitLocation + HitNormal * 32.0, 6.0, HitNormal);
    Class'RageEffects.RageEffect'.static.AddVehicleExplosionServer(self, HitLocation + HitNormal * 32.0, 5.0, HitNormal);

    Spawn(class'ExplosionGlobal',,, HitLocation + vect(70,70,50));
    Spawn(class'ExplosionGlobal',,, HitLocation + vect(-70,-70,50));

    // Unfreeze first so the blast can push the guider
    UnfreezeGuider();
    HurtRadius(Damage, BlastRadius, MyDamageType, MomentumTransfer, HitLocation);

    Destroy();
}

// Runs on server and clients: release camera, unfreeze guider, notify weapon
simulated function Destroyed()
{
    local PlayerPawn PP;

    log("Destroyed role=" $ Role $ " t=" $ FlightTime $ " lifeSpan=" $ LifeSpan $ " clientImpacted=" $ bClientImpacted, 'PredatorMissile');

    PP = GuidingPlayer();
    if (PP != None && PP.ViewTarget == self)
    {
        PP.ViewTarget = None;
        PP.bBehindView = false;
    }
    if (IsLocalPlayer(PP))
        PP.ShakeView(0.9, 4500.0, 25.0);

    if (Role == ROLE_Authority)
    {
        UnfreezeGuider();
        if (ControllingWeapon != None)
            ControllingWeapon.MissileDestroyed();
    }

    Super.Destroyed();
}

defaultproperties
{
     InitialSlowDuration=1.500000
     InitialSpeedFactor=0.500000
     MinDiveAngleDegrees=5.000000
     MaxDiveAngleDegrees=89.000000
     TurnRateNormal=120.000000
     TurnRateBoost=75.000000
     TargetFlightTime=4.500000
     BoostMultiplier=2.500000
     BlastRadius=1400.000000
     speed=280.000000
     MaxSpeed=1600.000000
     Damage=1000.000000
     MomentumTransfer=250000
     MyDamageType=PredatorMissileDOTPredatorMissileWeapon
     ExplosionDecal=Class'RAGEEFFECTS.Scorch'
     RemoteRole=ROLE_SimulatedProxy
     bNetTemporary=False
     bReplicateInstigator=True
     Mesh=LodMesh'RageWeapons.RocketMesh'
     DrawScale=2.500000
     AmbientGlow=96
     bCollisionSphere=True
     CollisionRadius=16.000000
     CollisionHeight=16.000000
     bOwnerNoSee=True
     bAlwaysRelevant=True
     LifeSpan=20.000000
}
