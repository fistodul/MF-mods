//=============================================================================
// SentryGun - Placeable Autonomous Sentry Gun Weapon
//=============================================================================
class SentryGun extends TripBombs;

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

    Turret = Spawn(class'SentryGunTurret',,, PlaceLoc + vect(0,0,22), PlaceRot);
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
     bDestroyWhenEmpty=True
     CarrySize=2
     InventoryGroup=11
     PickupMessage="Loaded up Sentry Gun."
     ItemName="Sentry Gun"
     AIRating=0.700000
}
