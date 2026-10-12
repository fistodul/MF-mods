//=============================================================================
// PredatorMissile - Steerable Tactical Nuclear Missile
//=============================================================================
class PredatorMissile extends Projectile;

var PredatorMissileWeapon ControllingWeapon;
var float BaseSpeed;
var float CurrentSpeed;
var bool bBoosting;
var float CeilingHeight;
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

replication
{
    reliable if (Role == ROLE_Authority)
        CurrentSpeed, bBoosting, CeilingHeight, BaseSpeed;
}

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    AmbientSound = Sound'WeaponSFX_RocketLauncher.RocketFly';
    SoundVolume = 255;
    SoundRadius = 255;
    SoundPitch = 64;
}

function InitializeFlight(float InCeilingHeight)
{
    CeilingHeight = FClamp(InCeilingHeight, 600.0, 10000.0);

    // Target descent flight time adapted to ceiling height (bounded by Speed and MaxSpeed)
    BaseSpeed = FClamp(CeilingHeight / FMax(TargetFlightTime, 1.0), Speed, MaxSpeed);

    // Start at initial slow speed to allow comfortable target acquisition
    CurrentSpeed = BaseSpeed * FClamp(InitialSpeedFactor, 0.2, 1.0);

    Velocity = CurrentSpeed * vector(Rotation);
    Acceleration = CurrentSpeed * 0.1 * vector(Rotation);
}

final function int SignedPitch(int P)
{
    P = P & 65535;
    if (P > 32768)
        P -= 65536;
    return P;
}

final function int UnsignedPitch(int P)
{
    return P & 65535;
}

final function int TurnToward(int Current, int Target, int MaxStep)
{
    local int Diff;

    Diff = (Target - Current) & 65535;
    if (Diff > 32768)
        Diff -= 65536;

    if (Abs(Diff) <= MaxStep)
        return Target & 65535;

    if (Diff > 0)
        return (Current + MaxStep) & 65535;
    else
        return (Current - MaxStep) & 65535;
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
            if (Level.Game != None && Level.Game.bTeamGame)
            {
                if (P.PlayerReplicationInfo != None && Instigator.PlayerReplicationInfo != None &&
                    P.PlayerReplicationInfo.Team == Instigator.PlayerReplicationInfo.Team)
                    continue;
            }
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

simulated function Tick(float DeltaTime)
{
    local rotator TargetRot, NewRot;
    local float MaxTurnRate;
    local int MaxStep, SPitch, MinDivePitch, MaxDivePitch;
    local vector TargetDir;

    FlightTime += DeltaTime;

    // Destroy if owner died or disconnected
    if (Instigator == None || Instigator.bDeleteMe || Instigator.Health <= 0)
    {
        Explode(Location, vect(0,0,1));
        return;
    }

    if (PlayerPawn(Instigator) != None)
    {
        // 1. Boost control via Fire or AltFire
        if (PlayerPawn(Instigator).bFire != 0 || PlayerPawn(Instigator).bAltFire != 0)
        {
            bBoosting = true;
            CurrentSpeed = FMin(CurrentSpeed + 2500.0 * DeltaTime, BaseSpeed * BoostMultiplier);
            SoundPitch = 96;
        }
        else
        {
            bBoosting = false;
            SoundPitch = 64;

            // If within initial slow drop phase (e.g. first 1.4s), hold comfortable slow speed
            if (FlightTime < InitialSlowDuration)
            {
                CurrentSpeed = BaseSpeed * InitialSpeedFactor;
            }
            else
            {
                // Smoothly accelerate up to normal cruising speed
                if (CurrentSpeed < BaseSpeed)
                    CurrentSpeed = FMin(CurrentSpeed + (BaseSpeed * 0.8) * DeltaTime, BaseSpeed);
                else
                    CurrentSpeed = FMax(CurrentSpeed - 1200.0 * DeltaTime, BaseSpeed);
            }
        }

        // 2. Steer towards player's mouse view
        TargetRot = PlayerPawn(Instigator).ViewRotation;

        // In Unreal rotators: 0 is horizontal, -16384 is 90 deg down, +16384 is 90 deg up
        SPitch = SignedPitch(TargetRot.Pitch);

        // Convert configurable degree limits to Unreal rotator pitch units (182.0444 units per degree)
        MinDivePitch = int(-MinDiveAngleDegrees * 182.0444);
        MaxDivePitch = int(-MaxDiveAngleDegrees * 182.0444);

        if (SPitch > MinDivePitch)
            SPitch = MinDivePitch;
        else if (SPitch < MaxDivePitch)
            SPitch = MaxDivePitch;

        TargetRot.Pitch = UnsignedPitch(SPitch);

        // Turn rate in degrees per second converted to rotator units
        if (bBoosting)
            MaxTurnRate = TurnRateBoost * 182.0444;
        else
            MaxTurnRate = TurnRateNormal * 182.0444;
        MaxStep = int(MaxTurnRate * DeltaTime);

        NewRot = Rotation;
        NewRot.Yaw = TurnToward(Rotation.Yaw, TargetRot.Yaw, MaxStep);
        NewRot.Pitch = TurnToward(Rotation.Pitch, TargetRot.Pitch, MaxStep);
        NewRot.Roll = 0;

        SetRotation(NewRot);
        Velocity = CurrentSpeed * vector(NewRot);

        // Keep player's view synchronized with actual missile orientation
        PlayerPawn(Instigator).ViewRotation = NewRot;
    }
    else if (EngineBot(Instigator) != None)
    {
        if (BotTarget == None || BotTarget.Health <= 0)
            BotTarget = FindBotTarget();

        if (BotTarget != None)
        {
            TargetDir = Normal(BotTarget.Location - Location);
            TargetRot = rotator(TargetDir);
            MaxStep = int((TurnRateNormal * 182.0444) * DeltaTime);
            NewRot = Rotation;
            NewRot.Yaw = TurnToward(Rotation.Yaw, TargetRot.Yaw, MaxStep);
            NewRot.Pitch = TurnToward(Rotation.Pitch, TargetRot.Pitch, MaxStep);
            SetRotation(NewRot);
            Velocity = (BaseSpeed * 1.5) * vector(NewRot);
        }
    }

    // Exhaust particles
    SmokeTimer += DeltaTime;
    if (SmokeTimer >= 0.035)
    {
        SmokeTimer = 0.0;
        SpawnExhaust();
    }
}

simulated function SpawnExhaust()
{
    local vector ExhaustLoc, BackDir;
    local float FlameScale;

    if (Level.NetMode == NM_DedicatedServer)
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
    local PlayerPawn PP;

    // 1. Immediately reset camera view back to player
    if (Instigator != None)
    {
        PP = PlayerPawn(Instigator);
        if (PP != None && PP.ViewTarget == self)
        {
            PP.ViewTarget = None;
            PP.bBehindView = false;
            PP.ShakeView(0.9, 4500.0, 25.0);
        }
    }

    // 2. Deafening detonation sound
    PlaySound(Sound'MiscSFX.Explode', SLOT_None, 16.0, true, 8000.0);

    // 3. Spawning global server explosions & secondary fireballs
    Class'RageEffects.RageEffect'.static.AddExplosionServer(self, HitLocation + HitNormal * 32.0, 6.0, HitNormal);
    Class'RageEffects.RageEffect'.static.AddVehicleExplosionServer(self, HitLocation + HitNormal * 32.0, 5.0, HitNormal);

    Spawn(class'ExplosionGlobal',,, HitLocation + vect(70,70,50));
    Spawn(class'ExplosionGlobal',,, HitLocation + vect(-70,-70,50));
    Spawn(class'ExplosionGlobal',,, HitLocation + vect(70,-70,90));
    Spawn(class'ExplosionGlobal',,, HitLocation + vect(-70,70,90));

    // 4. Catastrophic nuclear blast damage
    HurtRadius(Damage, BlastRadius, MyDamageType, MomentumTransfer, HitLocation);

    // 5. Notify weapon
    if (ControllingWeapon != None)
    {
        ControllingWeapon.MissileDestroyed();
        ControllingWeapon = None;
    }

    Destroy();
}

simulated function Destroyed()
{
    local PlayerPawn PP;

    if (Instigator != None)
    {
        PP = PlayerPawn(Instigator);
        if (PP != None && PP.ViewTarget == self)
        {
            PP.ViewTarget = None;
            PP.bBehindView = false;
        }
    }

    if (ControllingWeapon != None)
    {
        ControllingWeapon.MissileDestroyed();
        ControllingWeapon = None;
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
     Mesh=LodMesh'RageWeapons.RocketMesh'
     DrawScale=2.500000
     AmbientGlow=96
     bCollisionSphere=True
     CollisionRadius=16.000000
     CollisionHeight=16.000000
     bOwnerNoSee=True
     bAlwaysRelevant=True
     LifeSpan=15.000000
}
