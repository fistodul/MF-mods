//=============================================================================
// The burning area left by a Molotov, deals dot and creates fire effects.
//=============================================================================

class MolotovFire extends Actor;

var float BurnDuration;
var float DamagePerSecond;
var float FireRadius;

var float TimePassed;
var float DamageTickTimer;

simulated function PostBeginPlay()
{
	Super.PostBeginPlay();

	FireRadius = CollisionRadius * 2;
	TimePassed = 0.0;
	DamageTickTimer = 0.0;

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
				Location + (VRand() * vect(1,1,0)) * 100, 
				vect(0,0,0),
				Texture'RageEffects.OldFire.OldFire_A01',
				255,
				1.5,
				2+16+128+2048,
				1.3
			);
		}

		DamageTickTimer = 0.0;
	}

	// Destroy when burn time is over (randomized)
	if (TimePassed >= BurnDuration + FRand())
		Destroy();
}

function Timer()
{
	local float DamageAmount;

	// Calculate damage for this tick
	DamageAmount = DamagePerSecond * 0.1;

	// Damage nearby actors (pawns and vehicles)
	DamageNearby(DamageAmount);
}

function DamageNearby(float Damage)
{
	local Pawn P;
	local float Distance;

	ForEach RadiusActors(class'Pawn', P, FireRadius, Location)
	{
		// All Pawns with a TakeDamage implementation (includes vehicles)
		Distance = VSize(P.Location - Location);

		// Damage falls off with distance
		if (Distance < FireRadius)
			P.TakeDamage(Damage, Instigator, Location, vect(0,0,0), 'Exploded');
	}
}

defaultproperties
{
	BurnDuration=6.9
	DamagePerSecond=20.0
    DrawType=DT_None
    CollisionRadius=150.000000
    bCollideWorld=True
    Physics=PHYS_Falling
    Mass=10.0
}
