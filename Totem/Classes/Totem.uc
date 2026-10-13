//=============================================================================
// Totem - Hybrid Totem of Undying & Tactical Restoration Stim
//
// 1. Passive "Totem of Undying": Intercepts fatal blows, leaving player at
//    configurable SurviveHealth (5 HP), gives 1.5s invulnerability grace
//    period and an emergency recovery HoT (+19 HP over 3s)
// 2. Primary Fire (LMB): AoE Pulse Heal (+56 HP instantly to user and all
//    friendly teammates within 400 radius)
// 3. Secondary Fire (RMB): Targeted HoT on a teammate (+118 HP over 10s)
// 4. Reload (R): Dedicated self-cast for full sustained HoT (+120 HP over 10s)
//=============================================================================
class Totem extends RageWeapon;

#exec TEXTURE IMPORT NAME=TotemIcon FILE=Textures\totem_icon.bmp GROUP=Icons MIPS=OFF Flags=2

var int SurviveHealth;
var int AoEHealAmount;
var float AoERadius;
var float HoTHealPerTick;
var int HoTTicks;
var float HoTInterval;
var float AllyHoTHealPerTick;
var float ReviveHoTHealPerTick;
var int ReviveHoTTicks;
var float ReviveGracePeriod;
var float TraceRange;

// Viewmodel animation stubs (suppresses unassigned 3D mesh sequences)
simulated function PlaySelect() {}
simulated function PlaySelectAnim() {}
simulated function PlayTweenDownAnim() {}
simulated function PlayIdleAnim() {}
simulated function Timer() {}
simulated function PlayZoomedInIdleAnim() {}
simulated function PlayAimDownAnim() {}
simulated function PlayAimUpAnim() {}
simulated function PlayAltFiringAnim() {}
simulated function PlayFiringAnim() {}
simulated function PlayReloadingAnim() {}
simulated function PlayTweenToStillAnim() {}

simulated function String GetAmmoStatus()
{
    return String(ClipAmmo);
}

function bool IsFriendly(Pawn Target)
{
    if (Target == None)
        return false;
    if (Target == Owner)
        return true;
    if (Level.Game.bTeamGame && Target.PlayerReplicationInfo != None)
        return Pawn(Owner).PlayerReplicationInfo.Team == Target.PlayerReplicationInfo.Team;
    return false;
}

//=============================================================================
// Passive Cheat-Death
//=============================================================================

function int ArmorAbsorbDamage(int Damage, name DamageType, vector HitLocation)
{
    local int AllowedDamage;
    local Pawn P;

    // Ignore zero-damage calls (zone transitions send ReduceDamage(0, 'Breathe')) and mover crushes
    if (Damage <= 0 || DamageType == 'Crushed')
        return Damage;

    P = Pawn(Owner);
    if (P.Health > 0 && Damage >= P.Health)
    {
        if (P.Health > SurviveHealth)
            AllowedDamage = P.Health - SurviveHealth;
        else
            AllowedDamage = 0;

        TriggerRevival(HitLocation);
        return AllowedDamage;
    }

    return Damage;
}

function TriggerRevival(vector HitLocation)
{
    local TotemHealEffect Buff;
    local Pawn P;
    P = Pawn(Owner);

    Buff = Spawn(class'TotemHealEffect', P);
    if (Buff != None)
    {
        // GiveTo first (settles the actor into inventory + Idle2 state) THEN ActivateBuff (starts the timer safely after state transition)
        Buff.GiveTo(P);
        Buff.ActivateBuff(ReviveHoTHealPerTick, ReviveHoTTicks, HoTInterval, ReviveGracePeriod);
    }

    P.ClientMessage("Totem of Undying triggered! Death prevented.");
    P.PlayOwnedSound(Sound'MiscSFX.ArmourWearOut', SLOT_Misc, P.SoundDampening * 2.0);

    UseAmmo(1);
    if (ClipAmmo <= 0)
    {
        bIsAnArmor = false;
        Destroy();
    }
}

//=============================================================================
// Primary Fire: AoE Pulse Heal
//=============================================================================

function Fire(float Value)
{
    if (Pawn(Owner).CanFire() && AmmoInClip())
    {
        bPointing = True;
        bCanClientFire = True;
        PulseHeal();
    }
}

function PulseHeal()
{
    local Pawn P, PawnOwner;
    local int TargetsHealed;
    PawnOwner = Pawn(Owner);

    // Count how many targets actually need healing
    TargetsHealed = 0;

    foreach VisibleCollidingActors(class'Pawn', P, AoERadius, PawnOwner.Location)
    {
        if (IsFriendly(P) && ApplyInstantHeal(P, AoEHealAmount))
            TargetsHealed++;
    }

    // Don't consume ammo if nobody actually needed healing
    if (TargetsHealed == 0)
    {
        PawnOwner.ClientMessage("No one needs healing.");
        return;
    }

    PawnOwner.ClientMessage("AoE Pulse Heal activated! (" $ TargetsHealed $ " healed)");
    Owner.PlaySound(Sound'MiscSFX.ArmourWearOut', SLOT_Misc, PawnOwner.SoundDampening);

    UseAmmo(1);
    if (!AmmoInClip())
        ConsumeWeapon();
}

// Returns true if target was actually healed
function bool ApplyInstantHeal(Pawn Target, int Amount)
{
    if (Target.Health > 0 && Target.Health < Target.Default.Health)
    {
        Target.Health = Min(Target.Default.Health, Target.Health + Amount);
        Target.PlaySound(Target.HitSound2, SLOT_Talk, 0.6);
        return true;
    }
    return false;
}

//=============================================================================
// Secondary Fire: Targeted Ally HoT
//=============================================================================

function AltFire(float Value)
{
    if (Pawn(Owner).CanFire() && AmmoInClip())
    {
        bPointing = True;
        bCanClientFire = True;
        TryTargetedHoT();
    }
}

function TryTargetedHoT()
{
    local vector HitLocation, HitNormal, EndTrace, X, Y, Z, Start;
    local actor Other;
    local Pawn PawnOwner, TargetPawn;
    PawnOwner = Pawn(Owner);

    Owner.MakeNoise(PawnOwner.SoundDampening);
    GetAxes(PawnOwner.ViewRotation, X, Y, Z);
    Start = Owner.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z;
    AdjustedAim = PawnOwner.AdjustAim(1000000, Start, AimError, False, False);
    EndTrace = Owner.Location + (TraceRange * vector(AdjustedAim));
    Other = PawnOwner.TraceShot(HitLocation, HitNormal, EndTrace, Start);

    TargetPawn = Pawn(Other);
    if (IsFriendly(TargetPawn) && Other != Owner)
    {
        if (TargetPawn.Health >= TargetPawn.Default.Health)
        {
            PawnOwner.ClientMessage("Target is already at full health.");
            return;
        }

        ApplyFullHoT(TargetPawn);
        UseAmmo(1);

        if (!AmmoInClip())
            ConsumeWeapon();
        return;
    }

    PawnOwner.ClientMessage("Target not found.");
}

//=============================================================================
// Reload: Self HoT
//=============================================================================

function Reload()
{
    local Pawn PawnOwner;
    PawnOwner = Pawn(Owner);

    // Mitigates loadout issue
    if (PawnOwner.Weapon != self)
        return;

    if (AmmoInClip() && PawnOwner.CanFire())
    {
        if (PawnOwner.Health >= PawnOwner.Default.Health)
        {
            PawnOwner.ClientMessage("Already at full health.");
            return;
        }

        ApplyFullHoT(PawnOwner);
        UseAmmo(1);

        if (!AmmoInClip())
            ConsumeWeapon();
    }
}

//=============================================================================
// Full HoT Buff Applicator
//=============================================================================

function ApplyFullHoT(Pawn Target)
{
    local TotemHealEffect Buff;
    local float HealPerTick;

    if (Target == Owner)
    {
        HealPerTick = HoTHealPerTick;
        Pawn(Owner).ClientMessage("Sustained Regeneration activated.");
    }
    else
    {
        HealPerTick = AllyHoTHealPerTick;
        Pawn(Owner).ClientMessage("Injected ally with Sustained Regeneration!");
    }

    Buff = Spawn(class'TotemHealEffect', Target);
    if (Buff != None)
    {
        // GiveTo first, THEN ActivateBuff (same pattern as TriggerRevival)
        Buff.GiveTo(Target);
        Buff.ActivateBuff(HealPerTick, HoTTicks, HoTInterval, 0.0);
    }

    Target.PlaySound(Target.HitSound2, SLOT_Talk, 0.8);
}

//=============================================================================
// Weapon Consumption & State Transitions
//=============================================================================

// Clean removal: switch to best weapon, then destroy so no HUD ghost remains
function ConsumeWeapon()
{
    bIsAnArmor = false;
    Pawn(Owner).SwitchToBestWeapon();
    GotoState('DownWeapon');
}

state DownWeapon
{
ignores Fire, AltFire;
Begin:
    Pawn(Owner).ChangedWeapon();
    if (!AmmoInClip())
        Destroy();
}

function Finish()
{
    if (!AmmoInClip())
    {
        ConsumeWeapon();
        return;
    }
    GotoState('Idle');
}

simulated function ClientFinish()
{
    if (!AmmoInClip())
    {
        Pawn(Owner).SwitchToBestWeapon();
        return;
    }
    Super.ClientFinish();
}

defaultproperties
{
     SurviveHealth=5
     AoEHealAmount=56
     AoERadius=400.000000
     HoTHealPerTick=6.000000
     HoTTicks=20
     HoTInterval=0.500000
     AllyHoTHealPerTick=5.900000
     ReviveHoTHealPerTick=3.166667
     ReviveHoTTicks=6
     ReviveGracePeriod=1.500000
     TraceRange=160.000000
     MaxClipAmmo=1
     MaxClips=1
     bDestroyWhenEmpty=True
     WeaponIcon=(W=64,H=64,t=Texture'Totem.Icons.TotemIcon')
     bCanThrow=False
     bOwnsCrosshair=True
     AIRating=-1.000000
     MaxCanCarry=1
     CarrySize=1
     AutoSwitchPriority=0
     InventoryGroup=10
     PickupMessage="Loaded up Totem of Undying."
     ItemName="Totem of Undying"
     bIsAnArmor=True
     AbsorptionPriority=1
}
