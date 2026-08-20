//=============================================================================
// The burning area left by a Molotov, deals dot and creates fire effects.
//=============================================================================

class MolotovFire extends Actor;

var float BurnDuration;
var float DamagePerTimer;
var float DamageAccumulator;

var float FireRadius;
var float TimePassed;
var float DamageTickTimer;

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();

    BurnDuration += FRand();
    TimePassed = 0.0;
    DamageTickTimer = 0.0;
    DamageAccumulator = 0.0;

    SetTimer(0.1, true); // Check for damage every 0.1 seconds
}

simulated function Tick(float DeltaTime)
{
    local int i;

    TimePassed += DeltaTime;
    DamageTickTimer += DeltaTime;

    // Continously spawn fire effects while burning
    if (DamageTickTimer >= 0.2)
    {
        for (i = 0; i < 3; i++)
        {
            Level.Particles.AddOne(
                Location + VRand() * vect(110, 110, 0), 
                vect(0, 0, 0),
                Texture'RageEffects.OldFire.OldFire_A01',
                255,
                1.5,
                2194, // 2+16+128+2048
                1.3
            );
        }

        PlaySound(Sound'MiscSFX.HitRubber',, 0.5,,, 2.0);
        DamageTickTimer = 0.0;
    }

    // Destroy when burn time is over (randomized)
    if (TimePassed >= BurnDuration)
        Destroy();
}

function Timer()
{
    local int DamageAmount;

    // Add this tick's fractional damage to the pool
    DamageAccumulator += DamagePerTimer;

    // Deal any actual damage for this tick
    if (DamageAccumulator >= 1.0)
    {
        DamageAmount = int(DamageAccumulator);

        // Damage nearby actors (e.g pawns and vehicles)
        DamageAccumulator -= DamageAmount;
        DamageNearby(DamageAmount);
    }
}

function DamageNearby(float Damage)
{
    local Actor A, HitA;
    local float Dist;
    local float VerticalDist;
    local vector HitLocation, HitNormal;

    // All actors with a TakeDamage implementation
    foreach RadiusActors(class'Actor', A, FireRadius, Location)
    {
        Dist = VSize(A.Location - Location);
        VerticalDist = Abs(A.Location.Z - Location.Z);

        // Vehicles seem to be hit farther without Dist checking
        if (Dist <= FireRadius && VerticalDist <= FireRadius * 0.5)
        {
            // Damage if line of sight is clear, or if target is within half radius (fire spreading through doors)
            HitA = Trace(HitLocation, HitNormal, A.Location, Location, false);
            if (HitA == None || Dist <= FireRadius * 0.5)
                A.TakeDamage(Damage, Instigator, Location, vect(0, 0, 0), 'Exploded');
        }
    }
}

defaultproperties
{
     BurnDuration=6.900000
     DamagePerTimer=2.600000
     FireRadius=300.000000
     Physics=PHYS_Falling
     DrawType=DT_None
     CollisionRadius=8.000000
     CollisionHeight=8.000000
     bCollideActors=True
     bCollideWorld=True
     Mass=10.000000
}
