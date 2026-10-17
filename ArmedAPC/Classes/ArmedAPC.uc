//=============================================================================
// ArmedAPC - Armadillo with a turret where the roof hatch passenger stands.
// The gunner aims the turret with the camera and fires it with the fire key.
// This class mounts a heavy machine gun; ArmedAPCRocket a rocket launcher.
//=============================================================================
class ArmedAPC extends Armadillo;

var() int GunnerSeat;
var() vector TurretPivot;			// Hatch centre the gun turns around, relative to the vehicle
var() vector GunOffset;				// Gun relative to the pivot, turning with the turret's yaw
var() vector MuzzleOffset;			// Muzzle relative to the gun, along the barrel
var() int TurretPitchMin, TurretPitchMax;
var() float TurretTurnRate;			// Rotation units per second
var() Mesh TurretMesh;
var() float TurretDrawScale;

var() float FireInterval;
var() int MaxClipAmmo;
var() float ReloadTime;
var() float Spread;
var() class<Projectile> ProjectileClass;	// None fires instant hit traces
var() int Damage;							// Instant hit only, like the next three
var() float MomentumTransfer;
var() name MyDamageType;
var() int TracerEvery;
var() float MaxRange;
var() sound FireSound;
var() sound ReloadSound;

var rotator TurretRot;				// Turret rotation relative to the vehicle
var rotator TurretAim;				// The server's TurretRot, for clients that don't aim it
var int ClipAmmo;
var float FireDelay;
var int TracerCount;
var ArmedAPCTurret Turret;
var ArmedAPCWeapon GunnerWeapon;
var Weapon GunnerLastWeapon;

replication
{
	unreliable if (Role == ROLE_Authority)
		TurretAim, ClipAmmo;
}

simulated function PostBeginPlay()
{
	Super.PostBeginPlay();

	ClipAmmo = MaxClipAmmo;
	if (Level.NetMode != NM_DedicatedServer)
	{
		Turret = Spawn(class'ArmedAPCTurret', self);
		Turret.Mesh = TurretMesh;
		Turret.DrawScale = TurretDrawScale;
	}
}

simulated function Destroyed()
{
	if (Turret != None)
		Turret.Destroy();

	Super.Destroyed();
}

simulated function Tick(float Delta)
{
	local Pawn Gunner;
	local rotator Desired;
	local int Step;

	Super.Tick(Delta);

	// The server and the gunner's own machine aim the turret, other clients follow the server
	Gunner = aSeatsOccupant[GunnerSeat];
	Desired = TurretRot;
	if (Gunner != None && (Role == ROLE_Authority || IsLocalPlayer(Gunner)))
	{
		Desired = rotator(vector(GunnerAim(Gunner)) << Rotation);
		// Signed pitch, so aiming down meets TurretPitchMin
		Desired.Pitch = Clamp(((Desired.Pitch + 32768) & 65535) - 32768, TurretPitchMin, TurretPitchMax);
	}
	else if (Role < ROLE_Authority)
		Desired = TurretAim;

	Step = TurretTurnRate * Delta;
	TurretRot.Yaw = TurnTowards(TurretRot.Yaw, Desired.Yaw, Step) & 65535;
	TurretRot.Pitch = TurnTowards(TurretRot.Pitch, Desired.Pitch, Step);

	if (Turret != None)
	{
		Turret.SetLocation(GetPointWorld2(GunPos()));
		Turret.SetRotation(GetChildRotWorld(TurretRot));
	}

	if (Role < ROLE_Authority)
		return;

	TurretAim = TurretRot;

	if (FireDelay > 0)
	{
		FireDelay -= Delta;
		if (FireDelay <= 0 && ClipAmmo == 0)
			ClipAmmo = MaxClipAmmo;
	}
	else if (Gunner != None && Gunner.bFire != 0)
		FireTurret(Gunner);
}

simulated function bool IsLocalPlayer(Pawn P)
{
	return PlayerPawn(P) != None && Viewport(PlayerPawn(P).Player) != None;
}

// Players aim with the camera, bots at their enemy
simulated function rotator GunnerAim(Pawn Gunner)
{
	if (PlayerPawn(Gunner) == None && Gunner.Enemy != None)
		return rotator(Gunner.Enemy.Location - GetPointWorld2(TurretPivot));
	return Gunner.ViewRotation;
}

// Steps a rotation component by at most MaxStep the short way round
simulated function int TurnTowards(int From, int To, int MaxStep)
{
	return From + Clamp(((To - From + 32768) & 65535) - 32768, -MaxStep, MaxStep);
}

// The gun circles the hatch in front of the gunner, relative to the vehicle
simulated function vector GunPos()
{
	local rotator Yaw;

	Yaw.Yaw = TurretRot.Yaw;
	return TurretPivot + (GunOffset >> Yaw);
}

simulated function GetMuzzle(out vector Start, out vector Dir)
{
	Start = GetPointWorld2(GunPos() + (MuzzleOffset >> TurretRot));
	Dir = vector(GetChildRotWorld(TurretRot));
}

//=============================================================================
// Gunner seat
//=============================================================================

function PawnEnterVehicle(Pawn InPlayer)
{
	Super.PawnEnterVehicle(InPlayer);

	if (aSeatsOccupant[GunnerSeat] == InPlayer)
		TakeTurret(InPlayer);
}

function PawnLeaveVehicle(Pawn InPlayer)
{
	// Clients call this too when they get out
	if (Role == ROLE_Authority && aSeatsOccupant[GunnerSeat] == InPlayer)
		LeaveTurret(InPlayer);

	Super.PawnLeaveVehicle(InPlayer);
}

// Holsters the gunner's weapon behind one that can't be put down, like drivers get
function TakeTurret(Pawn Gunner)
{
	GunnerLastWeapon = Gunner.Weapon;
	if (GunnerLastWeapon != None)
		GunnerLastWeapon.PutDown();

	GunnerWeapon = Spawn(class'ArmedAPCWeapon', Gunner);
	GunnerWeapon.AssociatedVehicle = self;
	GunnerWeapon.GiveTo(Gunner);
	Gunner.Weapon = GunnerWeapon;
}

function LeaveTurret(Pawn Gunner)
{
	Gunner.DeleteInventory(GunnerWeapon);
	GunnerWeapon.Destroy();
	GunnerWeapon = None;

	Gunner.PendingWeapon = GunnerLastWeapon;
	GunnerLastWeapon = None;
	Gunner.ChangedWeapon();
}

//=============================================================================
// Firing (server)
//=============================================================================

function FireTurret(Pawn Gunner)
{
	local vector Start, Dir, X, Y, Z;

	GetMuzzle(Start, Dir);
	GetAxes(rotator(Dir), X, Y, Z);
	Dir = Normal(X + (FRand() - 0.5) * Spread * Y + (FRand() - 0.5) * Spread * Z);

	// Spawned by the gunner, so the gunner is its Instigator
	if (ProjectileClass != None)
		Gunner.Spawn(ProjectileClass,,, Start, rotator(Dir));
	else
		TraceFire(Gunner, Start, Dir);

	PlaySound(FireSound, SLOT_None, 4.0);
	MakeNoise(1.0);

	ClipAmmo--;
	if (ClipAmmo > 0)
		FireDelay = FireInterval;
	else
		ReloadTurret();
}

// Empties the clip; Tick refills it after ReloadTime
function ReloadTurret()
{
	ClipAmmo = 0;
	FireDelay = ReloadTime;
	PlaySound(ReloadSound, SLOT_Misc, 4.0);
}

function TraceFire(Pawn Gunner, vector Start, vector Dir)
{
	local vector End, HitLocation, HitNormal, RealHit;
	local actor Other;
	local int i;

	End = Start + Dir * MaxRange;
	Other = Trace(HitLocation, HitNormal, End, Start, true);

	// Shoot past this vehicle's own parts and occupants
	for (i = 0; i < 4 && Other != None && (Other == self || Other.Owner == self || IsOccupant(Pawn(Other))); i++)
		Other = Other.Trace(HitLocation, HitNormal, End, HitLocation, true);

	// Cylinder hits on pawns and vehicles still have to hit the body, as in Pawn.TraceShot
	if (Pawn(Other) != None)
	{
		RealHit = HitLocation;
		if (!Pawn(Other).AdjustHitLocation(HitLocation, Dir))
			Other = Pawn(Other).TraceShot(HitLocation, HitNormal, End, RealHit);
	}

	if (Other == None)
		HitLocation = End;
	else if (Other == Level || Other.bWorldGeometry)
		Class'RageEffects.RageEffect'.static.AddWallHit(self, HitLocation + HitNormal, rotator(HitNormal));
	else
	{
		if (Other.bIsPawn)
			Other.PlaySound(Sound'MiscSFX.RageChunkHit',, 4.0,, 100);

		Other.TakeDamage(Damage, Gunner, HitLocation, Dir * MomentumTransfer, MyDamageType);
		if (!Other.bIsPawn && !Other.IsA('Carcass'))
			Spawn(class'RageSpriteSmokePuff',,, HitLocation + HitNormal * 9);
	}

	TracerCount++;
	if (TracerCount >= TracerEvery)
	{
		TracerCount = 0;
		SpawnTracer(Start, HitLocation);
	}
}

// As SentryGunTurret.SpawnTracer: a local particle here, a FakeTracer for clients
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

	if (Level.NetMode != NM_DedicatedServer)
		Level.Particles.AddOne(Start, Dir * 3000, Texture'RageEffects.TracerTex', 255, 0.1, 2+256+512, FMin(2, Len / 3000));

	if (Level.NetMode == NM_DedicatedServer || Level.NetMode == NM_ListenServer)
	{
		Fake = Spawn(class'FakeTracer', self,, Start);
		Fake.DirL = DirL;
		Fake.Flag = 1;
	}
}

defaultproperties
{
     GunnerSeat=1
     TurretPivot=(Z=84.000000)
     GunOffset=(X=30.000000)
     MuzzleOffset=(X=40.000000)
     TurretPitchMin=-2000
     TurretPitchMax=9000
     TurretTurnRate=30000.000000
     TurretMesh=LodMesh'RageWeapons.HeavyMachineGunPickupCarryMesh'
     TurretDrawScale=1.250000
     FireInterval=0.100000
     MaxClipAmmo=100
     ReloadTime=4.000000
     Spread=0.030000
     Damage=25
     MomentumTransfer=1000.000000
     MyDamageType=tracedshot
     TracerEvery=2
     MaxRange=6000.000000
     FireSound=Sound'WeaponSFX_HeavyMachineGun.Fire'
     ReloadSound=Sound'WeaponSFX_MachineGun.Reload'
     aSeatsPos(1)=(Z=96.000000)
     aSeatsBotDesire(1)=0.900000
}
