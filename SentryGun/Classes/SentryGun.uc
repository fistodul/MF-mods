//=============================================================================
// SentryGun - Placeable Autonomous Sentry Gun Weapon
//=============================================================================
class SentryGun extends TripBombs;

#exec TEXTURE IMPORT NAME=SentryIcon FILE=Textures\sentry_icon.bmp GROUP=Icons MIPS=OFF Flags=2

var int MaxActiveSentries;

function Fire(float Value)
{
    FireBeginTime = Level.TimeSeconds;
    if (AmmoInClip() && Pawn(Owner) != None && Pawn(Owner).CanFire())
    {
        GotoState('NormalFire');
        bPointing = True;
        bCanClientFire = true;
        ClientFire(Value);
    }
}

function AltFire(float Value)
{
    Fire(Value);
}

simulated function bool ClientFire(float Value)
{
    if (RagePlayerBase(Owner) != None && RagePlayerBase(Owner).LoadoutActive)
        return false;

    if (bCanClientFire && ((Role == ROLE_Authority) || AmmoInClip()))
    {
        PlayFiringAnim();
        return true;
    }
    return false;
}

simulated function bool ClientAltFire(float Value)
{
    return ClientFire(Value);
}

simulated function bool FindPlacementSpot(out vector PlaceLoc, out rotator PlaceRot)
{
    local vector EyeLoc, LookDir, ForwardDir, TraceEnd, HitLocation, HitNormal, Diff;
    local actor HitActor;
    local rotator FlatRot;

    if (Pawn(Owner) == None)
        return false;

    FlatRot = Pawn(Owner).ViewRotation;
    FlatRot.Pitch = 0;
    FlatRot.Roll = 0;
    ForwardDir = vector(FlatRot);
    EyeLoc = Pawn(Owner).Location + vect(0,0,1) * Pawn(Owner).EyeHeight;
    LookDir = vector(Pawn(Owner).ViewRotation);

    // 1. Try tracing where player is aiming (if looking down at ground in front)
    TraceEnd = EyeLoc + LookDir * 150.0;
    HitActor = Pawn(Owner).Trace(HitLocation, HitNormal, TraceEnd, EyeLoc, true);

    if (HitActor != None && (HitActor == Level || HitActor.bWorldGeometry) && HitNormal.Z > 0.65)
    {
        Diff = HitLocation - Pawn(Owner).Location;
        Diff.Z = 0;
        if (VSize(Diff) >= 40.0 && VSize(Diff) <= 140.0)
        {
            PlaceLoc = HitLocation;
            PlaceRot = FlatRot;
            return true;
        }
    }

    // 2. Fallback: Trace straight down to floor 75 units forward from player
    TraceEnd = Pawn(Owner).Location + ForwardDir * 75.0;
    HitActor = Pawn(Owner).Trace(HitLocation, HitNormal, TraceEnd - vect(0,0,120), TraceEnd + vect(0,0,20), true);

    if (HitActor != None && (HitActor == Level || HitActor.bWorldGeometry) && HitNormal.Z > 0.65)
    {
        PlaceLoc = HitLocation;
        PlaceRot = FlatRot;
        return true;
    }

    return false;
}

function int CountActiveSentries()
{
    local Pawn P;
    local SentryGunTurret Turret;
    local int Count;

    for (P = Level.PawnList; P != None; P = P.NextPawn)
    {
        Turret = SentryGunTurret(P);
        if (Turret != None && Turret.Instigator == Owner && Turret.Health > 0)
            Count++;
    }
    return Count;
}

// Whether a player, bot, turret or vehicle part (wheel, petrol cap) is in the turret's cylinder at
// Loc. Vehicles themselves are skipped: their collision cylinder is set from their whole extent
// (a truck's radius is 445), so it covers open ground around them.
function bool TurretObstructed(vector Loc)
{
    local actor A;
    local vector Diff;

    foreach RadiusActors(class'Actor', A, 150, Loc)
    {
        if (!A.bCollideActors || !A.bBlockPlayers || A.bWorldGeometry || EnginePhysical(A) != None)
            continue;
        Diff = A.Location - Loc;
        if (Abs(Diff.Z) < A.CollisionHeight + class'SentryGunTurret'.default.CollisionHeight)
        {
            Diff.Z = 0;
            if (VSize(Diff) < A.CollisionRadius + class'SentryGunTurret'.default.CollisionRadius)
                return true;
        }
    }
    return false;
}

// The turret has no collision by default, so Spawn only refuses world geometry, and
// TurretObstructed decides about actors. Its collision is switched on once it stands.
function SentryGunTurret SpawnTurret(vector PlaceLoc, rotator PlaceRot)
{
    local SentryGunTurret Turret;

    PlaceLoc.Z += 22;
    if (TurretObstructed(PlaceLoc))
        return None;
    Turret = Spawn(class'SentryGunTurret',,, PlaceLoc, PlaceRot);
    if (Turret != None)
        Turret.SetCollision(true, true, true);
    return Turret;
}

function bool TryPlaceSentry()
{
    local vector PlaceLoc;
    local rotator PlaceRot;
    local SentryGunTurret Turret;

    if (Pawn(Owner) == None)
        return false;

    if (CountActiveSentries() >= MaxActiveSentries)
    {
        Pawn(Owner).ClientMessage("Max active Sentry Guns reached: " $ MaxActiveSentries);
        return false;
    }

    if (!FindPlacementSpot(PlaceLoc, PlaceRot))
    {
        Pawn(Owner).ClientMessage("Cannot place Sentry Gun here (clear flat ground required)");
        return false;
    }

    Turret = SpawnTurret(PlaceLoc, PlaceRot);
    if (Turret == None)
    {
        Pawn(Owner).ClientMessage("Cannot deploy Sentry Gun (space obstructed)");
        return false;
    }

    Turret.InitPlacer(Pawn(Owner));
    return true;
}

state NormalFire
{
    function AnimEnd()
    {
        if (TryPlaceSentry())
        {
            UseAmmo(1);
            PlayTripBombPlant();
            Pawn(Owner).PlayFiring();
        }
        else
            PlayTripBombFailToPlant();
        GotoState('NormalFire2');
    }
}

function Finish()
{
    GotoState('Idle');
}

simulated function ClientFinish()
{
    local vector PlaceLoc;
    local rotator PlaceRot;

    if (AnimSequence == 'PlaceForward')
    {
        if (FindPlacementSpot(PlaceLoc, PlaceRot))
            PlayTripBombPlant();
        else
            PlayTripBombFailToPlant();
    }
    else if (!AmmoInClip())
    {
        if (PlayerPawn(Owner) != None)
            PlayerPawn(Owner).SwitchToBestWeapon();
        return;
    }
    else
        Super.ClientFinish();
}

defaultproperties
{
     MaxActiveSentries=2
     MaxClipAmmo=1
     WeaponIcon=(X=0,W=128,t=Texture'SentryGun.Icons.SentryIcon')
     AIRating=0.700000
     DeathMessage="%k's %w shredded %o."
     CarrySize=2
     InventoryGroup=11
     PickupMessage="Loaded up Sentry Gun."
     ItemName="Sentry Gun"
}
