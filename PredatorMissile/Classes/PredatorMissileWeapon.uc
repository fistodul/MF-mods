//=============================================================================
// PredatorMissileWeapon - Tactical Missile / Nuclear Strike Controller
//=============================================================================
class PredatorMissileWeapon extends TripBombs;

#exec TEXTURE IMPORT NAME=PredatorIcon FILE=Textures\predator_icon.bmp GROUP=Icons MIPS=OFF Flags=2

var PredatorMissile ActiveMissile;
var bool bGuiding;
var float GroundLevelZ;

var color HudGreen;
var color HudRed;
var color HudOrange;
var color HudDarkGreen;
var color WhiteColor;

var float MarkerFovScale;

var float WarmupDuration;       // Seconds terminal must warm up after being acquired before launch
var float ReadyTime;            // Level.TimeSeconds timestamp when systems are ready

replication
{
    reliable if (Role == ROLE_Authority)
        ActiveMissile, bGuiding, ReadyTime;
}

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (ReadyTime == 0.0 && WarmupDuration > 0.0)
        ReadyTime = Level.TimeSeconds + WarmupDuration;
}

function GiveTo(pawn Other)
{
    Super.GiveTo(Other);
    if (WarmupDuration > 0.0)
        ReadyTime = Level.TimeSeconds + WarmupDuration;
}

function Fire(float Value)
{
    local int SecondsLeft;

    if (ActiveMissile != None || bGuiding)
        return;

    if (Level.TimeSeconds < ReadyTime)
    {
        SecondsLeft = int(ReadyTime - Level.TimeSeconds) + 1;
        if (Pawn(Owner) != None)
        {
            Pawn(Owner).ClientMessage("Nuke ready in " $ SecondsLeft $ "s.");
            Pawn(Owner).PlaySound(Sound'RageMenu.Click', SLOT_Interface, 2.0);
        }
        return;
    }

    if (AmmoInClip() && Pawn(Owner) != None && Pawn(Owner).CanFire())
    {
        if (LaunchMissile())
        {
            bPointing = True;
            bCanClientFire = true;
            ClientFire(Value);
        }
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

    if (Level.TimeSeconds < ReadyTime)
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

function bool FindLaunchLocation(out vector OutSpawnLoc, out rotator OutSpawnRot, out float OutCeilingHeight)
{
    local vector StartTrace, ProbeStart, ProbeEnd, HitLoc, HitNorm;
    local actor HitActor;
    local float BestHeight, GroundZ, CeilZ, ProbeHeight;
    local vector BestSpawnLoc, Offsets[5];
    local int i, SPitch;
    local vector GroundHitLoc, GroundHitNorm;

    if (Pawn(Owner) == None)
        return false;

    StartTrace = Pawn(Owner).Location;

    // Detect ground level below player
    HitActor = Trace(GroundHitLoc, GroundHitNorm, StartTrace - vect(0,0,3000), StartTrace, false);
    if (HitActor != None)
        GroundZ = GroundHitLoc.Z;
    else
        GroundZ = StartTrace.Z - 40.0;

    GroundLevelZ = GroundZ;

    // Probe 5 points around player: center, forward, back, left, right
    Offsets[0] = vect(0,0,0);
    Offsets[1] = vect(350,0,0);
    Offsets[2] = vect(-350,0,0);
    Offsets[3] = vect(0,350,0);
    Offsets[4] = vect(0,-350,0);

    BestHeight = 0;
    BestSpawnLoc = StartTrace + vect(0,0,1000);

    for (i = 0; i < 5; i++)
    {
        ProbeStart = StartTrace + Offsets[i];
        ProbeEnd = ProbeStart + vect(0,0,8000);

        HitActor = Trace(HitLoc, HitNorm, ProbeEnd, ProbeStart, false);
        if (HitActor == None)
        {
            // Open sky
            ProbeHeight = 5500.0;
            CeilZ = ProbeStart.Z + 5500.0;
        }
        else
        {
            CeilZ = HitLoc.Z - 96.0;
            ProbeHeight = CeilZ - GroundZ;
        }

        if (ProbeHeight > BestHeight)
        {
            BestHeight = ProbeHeight;
            BestSpawnLoc = ProbeStart;
            BestSpawnLoc.Z = CeilZ;
        }
    }

    if (BestHeight < 400.0)
    {
        Pawn(Owner).ClientMessage("Airspace blocked! Cannot establish missile trajectory.");
        return false;
    }

    OutSpawnLoc = BestSpawnLoc;
    OutCeilingHeight = BestHeight;

    // Aim downwards towards ground near player
    OutSpawnRot = rotator((StartTrace + vect(0,0,50)) - BestSpawnLoc);
    SPitch = SignedPitch(OutSpawnRot.Pitch);
    if (SPitch > -int(class'PredatorMissile'.default.MinDiveAngleDegrees * 182.0444))
        SPitch = -int(class'PredatorMissile'.default.MinDiveAngleDegrees * 182.0444);
    else if (SPitch < -int(class'PredatorMissile'.default.MaxDiveAngleDegrees * 182.0444))
        SPitch = -int(class'PredatorMissile'.default.MaxDiveAngleDegrees * 182.0444);
    OutSpawnRot.Pitch = UnsignedPitch(SPitch);

    return true;
}

function bool LaunchMissile()
{
    local vector SpawnLoc;
    local rotator SpawnRot;
    local float CeilHeight;

    if (!FindLaunchLocation(SpawnLoc, SpawnRot, CeilHeight))
        return false;

    // Bot radio sound: "Nuke the whole area"
    Pawn(Owner).PlaySound(Sound'RagePlayerVoice.Nuke_the_whole_area', SLOT_Talk, 3.5, true, 2500.0);

    ActiveMissile = Spawn(class'PredatorMissile', Owner,, SpawnLoc, SpawnRot);
    if (ActiveMissile == None)
        return false;

    ActiveMissile.Instigator = Pawn(Owner);
    ActiveMissile.ControllingWeapon = self;
    ActiveMissile.InitializeFlight(CeilHeight);

    if (PlayerPawn(Owner) != None)
    {
        PlayerPawn(Owner).ViewTarget = ActiveMissile;
        PlayerPawn(Owner).bBehindView = false;
        PlayerPawn(Owner).ViewRotation = SpawnRot;
    }

    bGuiding = true;
    bOwnsCrossHair = true;
    GotoState('GuidingMissile');

    return true;
}

function MissileDestroyed()
{
    local Pawn PawnOwner;

    if (!bGuiding && ActiveMissile == None)
        return;

    bGuiding = false;
    bOwnsCrossHair = false;

    PawnOwner = Pawn(Owner);

    if (PlayerPawn(PawnOwner) != None && PlayerPawn(PawnOwner).ViewTarget == ActiveMissile)
    {
        PlayerPawn(PawnOwner).ViewTarget = None;
        PlayerPawn(PawnOwner).bBehindView = false;
    }

    if (ActiveMissile != None)
    {
        ActiveMissile.ControllingWeapon = None;
        ActiveMissile = None;
    }

    UseAmmo(1);

    if (PawnOwner != None)
    {
        if (!AmmoInClip())
        {
            PawnOwner.DeleteInventory(self);
            PawnOwner.Weapon = None;
            PawnOwner.SwitchToBestWeapon();
            if (PawnOwner.PendingWeapon != None)
                PawnOwner.ChangedWeapon();
            Destroy();
            return;
        }
    }

    GotoState('Idle');
}

simulated function Destroyed()
{
    if (ActiveMissile != None)
    {
        ActiveMissile.ControllingWeapon = None;
        ActiveMissile.Destroy();
        ActiveMissile = None;
    }

    if (PlayerPawn(Owner) != None && PlayerPawn(Owner).ViewTarget == ActiveMissile)
    {
        PlayerPawn(Owner).ViewTarget = None;
        PlayerPawn(Owner).bBehindView = false;
    }

    Super.Destroyed();
}

state GuidingMissile
{
    ignores Fire, AltFire;

    function Tick(float DeltaTime)
    {
        if (Pawn(Owner) != None)
        {
            Pawn(Owner).Velocity = vect(0,0,0);
            Pawn(Owner).Acceleration = vect(0,0,0);
        }

        if (ActiveMissile == None || ActiveMissile.bDeleteMe)
            MissileDestroyed();
    }
}

// ----------------------------------------------------------------------------
// Tactical HUD Rendering (PostRender)
// ----------------------------------------------------------------------------

simulated function bool IsPawnFriendly(Pawn P)
{
    if (P == None || P.Health <= 0)
        return true;

    if (P == Owner)
        return true;

    if (P.PlayerReplicationInfo != None)
    {
        if (Level.Game != None && Level.Game.bTeamGame)
        {
            if (Pawn(Owner) != None && Pawn(Owner).PlayerReplicationInfo != None)
                return P.PlayerReplicationInfo.Team == Pawn(Owner).PlayerReplicationInfo.Team;
        }
        return false;
    }
    return false;
}

simulated function byte GetVehicleStatus(Vehicle V)
{
    local int i;
    local bool bHasFriendly;

    if (V == None)
        return 0;

    for (i = 0; i < V.NumSeats; i++)
    {
        if (V.aSeatsOccupant[i] != None)
        {
            if (!IsPawnFriendly(V.aSeatsOccupant[i]))
                return 2;
            bHasFriendly = true;
        }
    }

    if (bHasFriendly)
        return 1;

    return 0;
}

simulated function DrawBox(canvas Canvas, float X, float Y, float W, float H)
{
    Canvas.SetPos(X, Y);
    Canvas.DrawTile(Texture'Engine.WhiteTexture', W, H, 0, 0, 1, 1);
}

simulated function DrawCornerBrackets(canvas Canvas, float X1, float Y1, float X2, float Y2, float L)
{
    DrawBox(Canvas, X1, Y1, L, 2);
    DrawBox(Canvas, X1, Y1, 2, L);
    DrawBox(Canvas, X2 - L, Y1, L, 2);
    DrawBox(Canvas, X2 - 2, Y1, 2, L);
    DrawBox(Canvas, X1, Y2 - 2, L, 2);
    DrawBox(Canvas, X1, Y2 - L, 2, L);
    DrawBox(Canvas, X2 - L, Y2 - 2, L, 2);
    DrawBox(Canvas, X2 - 2, Y2 - L, 2, L);
}

simulated function DrawTargetDiamond(canvas Canvas, float CX, float CY, float Size)
{
    DrawBox(Canvas, CX - Size, CY - 1, Size * 2, 2);
    DrawBox(Canvas, CX - 1, CY - Size, 2, Size * 2);
    DrawCornerBrackets(Canvas, CX - Size, CY - Size, CX + Size, CY + Size, 6);
}

simulated function DrawWarmupStatus(canvas Canvas, PlayerPawn PP)
{
    local float CX, CY, TW, TH;
    local int SecondsLeft;
    local string S;

    CX = Canvas.ClipX * 0.5;
    CY = Canvas.ClipY * 0.5;

    Canvas.Style = ERenderStyle.STY_Translucent;
    Canvas.Font = Canvas.SmallFont;

    if (Level.TimeSeconds < ReadyTime)
    {
        SecondsLeft = int(ReadyTime - Level.TimeSeconds) + 1;
        S = "[ SATELLITE UPLINK: CONNECTING (" $ SecondsLeft $ "s) ]";
        Canvas.DrawColor = HudOrange;
    }
    else
    {
        S = "[ AGM-114 UPLINK: ONLINE // READY TO LAUNCH ]";
        Canvas.DrawColor = HudGreen;
    }

    Canvas.TextSize(S, TW, TH);
    Canvas.SetPos(CX - TW * 0.5, CY + 40);
    Canvas.DrawText(S, false);
}

simulated function PostRender(canvas Canvas)
{
    local PlayerPawn PP;
    local float CX, CY, Proj, BoxSize, TW, TH, CurrentFOV;
    local int AltMeters, SpdMeters, DistM;
    local vector CamLoc, Rel, GroundHit, GroundNorm, TargetLoc;
    local rotator CamRot;
    local string S;
    local Pawn P;
    local Vehicle V;
    local byte VStatus;
    local Actor VA;

    Super.PostRender(Canvas);

    PP = PlayerPawn(Owner);
    if (PP == None)
        return;

    // If weapon is held by player but missile is not active, display warmup telemetry on HUD
    if (!bGuiding || ActiveMissile == None || ActiveMissile.bDeleteMe)
    {
        if (PP.Weapon == self && WarmupDuration > 0.0)
            DrawWarmupStatus(Canvas, PP);
        return;
    }

    // Use PlayerCalcView to obtain the EXACT rendering camera location and rotation
    PP.PlayerCalcView(VA, CamLoc, CamRot);
    CX = Canvas.ClipX * 0.5;
    CY = Canvas.ClipY * 0.5;

    Canvas.Style = ERenderStyle.STY_Translucent;
    Canvas.Font = Canvas.SmallFont;

    // 1. Fullscreen tactical framing brackets
    Canvas.DrawColor = HudDarkGreen;
    DrawCornerBrackets(Canvas, 30, 30, Canvas.ClipX - 30, Canvas.ClipY - 30, 40);

    // 2. Top-Left Telemetry
    Canvas.DrawColor = HudGreen;
    Canvas.SetPos(45, 45);
    Canvas.DrawText("[ AGM-114 PREDATOR STRIKE ]", false);
    Canvas.SetPos(45, 60);
    Canvas.DrawText("SYS: GUIDANCE ONLINE", false);
    Canvas.SetPos(45, 75);
    Canvas.DrawText("WARHEAD: ARMED // 500KT", false);

    // 3. Top-Right Telemetry (Radar Altimeter)
    if (Trace(GroundHit, GroundNorm, CamLoc - vect(0,0,15000), CamLoc, false) != None)
        AltMeters = int(VSize(CamLoc - GroundHit) / 50.0);
    else
        AltMeters = int((CamLoc.Z - GroundLevelZ) / 50.0);
    if (AltMeters < 0) AltMeters = 0;
    SpdMeters = int(ActiveMissile.CurrentSpeed / 50.0);

    Canvas.SetPos(Canvas.ClipX - 220, 45);
    Canvas.DrawText("ALT: " $ AltMeters $ " M", false);
    Canvas.SetPos(Canvas.ClipX - 220, 60);
    Canvas.DrawText("SPD: " $ SpdMeters $ " M/S", false);

    if (ActiveMissile.bBoosting)
    {
        Canvas.DrawColor = HudRed;
        Canvas.SetPos(Canvas.ClipX - 220, 75);
        Canvas.DrawText(">>> BOOST ACTIVE <<<", false);
    }
    else
    {
        Canvas.DrawColor = HudGreen;
        Canvas.SetPos(Canvas.ClipX - 220, 75);
        Canvas.DrawText("BOOST: READY", false);
    }

    // 4. Center Guidance Reticle
    Canvas.DrawColor = HudGreen;
    // Crosshair ticks
    DrawBox(Canvas, CX - 35, CY - 1, 20, 2);
    DrawBox(Canvas, CX + 15, CY - 1, 20, 2);
    DrawBox(Canvas, CX - 1, CY - 35, 2, 20);
    DrawBox(Canvas, CX - 1, CY + 15, 2, 20);
    // Center point
    DrawBox(Canvas, CX - 2, CY - 2, 4, 4);

    // Center prompt
    Canvas.Font = Canvas.SmallFont;
    S = "[ BOOST: HOLD FIRE / ALTFIRE ]";
    Canvas.TextSize(S, TW, TH);
    Canvas.SetPos(CX - TW * 0.5, CY + 50);
    Canvas.DrawText(S, false);

    // 5. 3D-to-2D Target Tracking (COD Predator HUD)
    CurrentFOV = PP.FOVAngle;
    if (CurrentFOV <= 0.0)
        CurrentFOV = PP.DesiredFOV;
    if (CurrentFOV <= 0.0)
        CurrentFOV = PP.DefaultFOV;
    if (CurrentFOV <= 0.0)
        CurrentFOV = 90.0;

    // In Unreal Engine 1, horizontal FOV spans Canvas.ClipX
    Proj = (Canvas.ClipX * 0.5) / FMax(Tan(CurrentFOV * 0.008726646), 0.001);
    Proj *= MarkerFovScale;

    // Track enemy pawns
    for (P = Level.PawnList; P != None; P = P.NextPawn)
    {
        if (P != Owner && P.Health > 0 && P.bProjTarget && !IsPawnFriendly(P))
        {
            TargetLoc = P.Location;
            TargetLoc.Z += P.EyeHeight * 0.2;
            Rel = (TargetLoc - CamLoc) << CamRot;
            if (Rel.X > 60.0)
            {
                CX = (Canvas.ClipX * 0.5) + (Rel.Y / Rel.X) * Proj;
                CY = (Canvas.ClipY * 0.5) - (Rel.Z / Rel.X) * Proj;

                if (CX >= 20 && CX <= Canvas.ClipX - 20 && CY >= 20 && CY <= Canvas.ClipY - 20)
                {
                    BoxSize = FClamp(12000.0 / Rel.X, 10.0, 36.0);
                    Canvas.DrawColor = HudRed;
                    DrawTargetDiamond(Canvas, CX, CY, BoxSize);

                    DistM = int(Rel.X / 50.0);
                    S = DistM $ "m";
                    Canvas.TextSize(S, TW, TH);
                    Canvas.SetPos(CX - TW * 0.5, CY + BoxSize + 2);
                    Canvas.DrawText(S, false);
                }
            }
        }
    }

    // Track vehicles
    foreach AllActors(class'Vehicle', V)
    {
        VStatus = GetVehicleStatus(V);
        if (VStatus == 2 || VStatus == 0)
        {
            TargetLoc = V.Location;
            TargetLoc.Z += V.CollisionHeight * 0.2;
            Rel = (TargetLoc - CamLoc) << CamRot;
            if (Rel.X > 60.0)
            {
                CX = (Canvas.ClipX * 0.5) + (Rel.Y / Rel.X) * Proj;
                CY = (Canvas.ClipY * 0.5) - (Rel.Z / Rel.X) * Proj;

                if (CX >= 20 && CX <= Canvas.ClipX - 20 && CY >= 20 && CY <= Canvas.ClipY - 20)
                {
                    BoxSize = FClamp(20000.0 / Rel.X, 16.0, 50.0);
                    if (VStatus == 2)
                    {
                        Canvas.DrawColor = HudRed;
                        S = "HOSTILE VEHICLE";
                    }
                    else
                    {
                        Canvas.DrawColor = HudOrange;
                        S = "VEHICLE";
                    }
                    DrawCornerBrackets(Canvas, CX - BoxSize, CY - BoxSize * 0.7, CX + BoxSize, CY + BoxSize * 0.7, 8);
                    Canvas.TextSize(S, TW, TH);
                    Canvas.SetPos(CX - TW * 0.5, CY + BoxSize * 0.7 + 2);
                    Canvas.DrawText(S, false);
                }
            }
        }
    }
}

defaultproperties
{
     MaxClipAmmo=1
     ClipAmmo=1
     WeaponIcon=(X=0,Y=0,W=128,H=64,t=Texture'PredatorMissile.Icons.PredatorIcon')
     MarkerFovScale=1.000000
     WarmupDuration=10.000000
     AIRating=0.850000
     DeathMessage="%k called in a Predator Missile on %o."
     MaxCanCarry=1
     CarrySize=2
     InventoryGroup=12
     PickupMessage="Predator Missile Terminal."
     ItemName="Predator Missile"
     bDestroyWhenEmpty=True
     HudGreen=(R=80,G=255,B=120,A=255)
     HudRed=(R=255,G=50,B=50,A=255)
     HudOrange=(R=255,G=165,B=0,A=255)
     HudDarkGreen=(R=30,G=120,B=50,A=200)
     WhiteColor=(R=255,G=255,B=255,A=255)
}
