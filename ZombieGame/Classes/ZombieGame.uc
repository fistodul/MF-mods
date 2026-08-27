//=============================================================================
// ZombieGame by Animeman - 2025, includes derivatives of Player, HUD, Knife...
//=============================================================================
class ZombieGame extends RageTeamGame;

struct TeamTracker
{
    var Pawn P;
    var byte InitialTeam;
};
var TeamTracker SavedTeams[128];

// Exponent influencing zombie strength, recommended values: 0.16 - 0.2
var config float zBiasExp;

var config byte zombieWeapons; // Zombie weapon ability (0 - 4)
var config bool bZombieLifeSteal; // Consume the flesh of the fallen to regenerate...

var config bool bSpawnAnywhere; // Don't spawn Zombies just from red base
var config bool bZombieInfect; // Humans turn into zombies upon being killed by one
var config bool bKillTransform; // Instead of respawning, instantly turn into a zombie

var NavigationPoint HumanSpawns[50], ZombieSpawns[50];
var int NumHumanSpawns, NumZombieSpawns;

var int MeleeDistance;
var bool bPendingRestartRound;

// Nemesis related
var bool bZombieInfectSaved;
var bool bRestartingRound;
var RagePlayer humanPlayerRef;

var class<Inventory> MeleeItems[3];
function bool IsMeleeItem(Inventory Inv)
{
    local int i;
    for (i = 0; i < ArrayCount(MeleeItems); i++)
    {
        if (ClassIsChildOf(Inv.Class, MeleeItems[i]))
            return true;
    }

    return false;
}

// Detroit
function BecomeHuman(Pawn P)
{
    local ZombiePlayer ZP;
    local ZombieBotBase ZB;
    local Pawn Other;
    local int Health;
    local float ratio;
    local bool bIsNemesis;

    ratio = (Teams[1].Size + 0.5) / Max(Teams[0].Size, 1);
    bIsNemesis = (ratio >= 5.0);

    if (bIsNemesis)
    {
        Health = P.Default.Health * (ratio / 2.5);
        for (Other = Level.PawnList; Other != None; Other = Other.NextPawn)
            Other.ClientMessage(P.PlayerReplicationInfo.PlayerName $ " is a SURVIVOR!");
    }
    else
        Health = P.Default.Health;

    ZP = ZombiePlayer(P);
    if (ZP != None)
    {
        ZP.MaxHealth = Health;
        ZP.bIsNemesis = bIsNemesis;
        ZP.MaxCarry = P.Default.MaxCarry + 1;
    }
    else
    {
        ZB = ZombieBotBase(P);
        if (ZB != None)
        {
            ZB.MaxHealth = Health;
            ZB.bIsNemesis = bIsNemesis;
        }

        P.MaxCarry = P.Default.MaxCarry + 1;
    }

    P.BaseGroundSpeed = P.Default.BaseGroundSpeed;
    P.Health = Health;

    P.FallDamageThreshold = P.Default.FallDamageThreshold;
    P.FallDeathThreshold = P.Default.FallDeathThreshold;
    P.JumpZ = P.Default.JumpZ;

    P.GroundSpeed = P.Default.GroundSpeed;
    P.WaterSpeed = P.Default.WaterSpeed;
    P.UnderwaterTime = P.Default.UnderwaterTime;
    //P.AirSpeed = P.Default.AirSpeed;

    P.AccelRate = P.Default.AccelRate;
    P.MaxStepHeight = P.Default.MaxStepHeight;
    //P.AirControl = P.Default.AirControl;
    //P.LadderSpeed = P.Default.LadderSpeed;

    TransformToHumanItems(P);
}

// Buff physical prowess based on scaled defaults
function BecomeZombie(Pawn P)
{
    local Pawn Other;
    local ZombiePlayer ZP;
    local ZombieBotBase ZB;
    local ZombieReplicationInfo ZRI;
    local float boost;
    local float boost_cap;
    local float exp;
    local float ratio;
    local bool bIsNemesis;

    ratio = (Teams[0].Size + 0.5) / Max(Teams[1].Size, 1);
    bIsNemesis = (ratio >= 5.0);

    if (bIsNemesis && IsOnTeam(P, 1))
    {
        ZRI = ZombieReplicationInfo(GameReplicationInfo);
        exp = FMax(zBiasExp, 0.25);
        boost_cap = 15;

        for (Other = Level.PawnList; Other != None; Other = Other.NextPawn)
            Other.ClientMessage(P.PlayerReplicationInfo.PlayerName $ " is a NEMESIS!");

        // Can't cheat death while a nemesis is alive
        bZombieInfect = false;
        ZRI.bZombieInfect = false;
    }
    else
    {
        exp = zBiasExp;
        boost_cap = 1.253;
    }

    ZP = ZombiePlayer(P);
    boost = FClamp(
        ratio ** exp,
        1.0, boost_cap
    );

    P.BaseGroundSpeed = FMin(P.Default.BaseGroundSpeed * 1.55 * boost, 880.0);
    P.Health = P.Default.Health * 3.33 * boost;

    if (ZP != None)
    {
        ZP.MaxHealth = P.Health;
        ZP.MaxCarry = P.Default.MaxCarry - 2;
        ZP.bIsNemesis = bIsNemesis;
    }
    else
    {
        ZB = ZombieBotBase(P);
        if (ZB != None)
        {
            ZB.MaxHealth = P.Health;
            ZB.bIsNemesis = bIsNemesis;
        }

        P.MaxCarry = P.Default.MaxCarry - 2;
    }

    P.FallDamageThreshold = P.Default.FallDamageThreshold * 1.5;
    P.FallDeathThreshold = P.Default.FallDeathThreshold * 1.5 * boost;
    P.JumpZ = FMin(P.Default.JumpZ * 1.45 * boost, 975.0);

    P.GroundSpeed = P.BaseGroundSpeed - 80;
    P.WaterSpeed = P.Default.WaterSpeed * 2;
    P.UnderwaterTime = P.Default.UnderwaterTime * 2;
    //P.AirSpeed = 200;

    P.AccelRate = P.Default.AccelRate * 1.15;
    P.MaxStepHeight = P.Default.MaxStepHeight * 1.15;
    //P.AirControl = P.Default.AirControl * 1.75;
    //P.LadderSpeed = P.Default.LadderSpeed * 1.5;

    TransformToZombieItems(P);
    if (zombieWeapons < 2)
        StripRanged(P);

    // Feel the hunger in your hands
    P.PendingWeapon = Weapon(P.FindInventoryType(Class'ZombieKnife'));
    P.ChangedWeapon();
}

function TransformItem(Inventory Inv, string NewInv)
{
    local Pawn P;
    P = Pawn(Inv.Owner);

    Inv.Destroy();
    GiveWeapon(P, NewInv);
}

function TransformItems(Pawn P)
{
    if (P.PlayerReplicationInfo.Team == 1)
        TransformToZombieItems(P);
    else
        TransformToHumanItems(P);
}

// Give Human equivalents to Zombie items
function TransformToHumanItems(Pawn P)
{
    local Inventory Inv, NextInv;
    for (Inv = P.Inventory; Inv != None; Inv = NextInv)
    {
        NextInv = Inv.Inventory;
        switch (Inv.Class)
        {
            case Class'ZombieKnife':
                TransformItem(Inv, "RageGame.RageKnife");
                break;
            case Class'AdrenalineShot':
                TransformItem(Inv, "ZombieGame.ZombieShot");
                break;
            case Class'ZombieArmour':
                TransformItem(Inv, "RageGame.RageArmour");
                break;
        }
    }
}

// Give Zombie equivalents to Human items
function TransformToZombieItems(Pawn P)
{
    local Inventory Inv, NextInv;
    for (Inv = P.Inventory; Inv != None; Inv = NextInv)
    {
        NextInv = Inv.Inventory;
        switch (Inv.Class)
        {
            case Class'RageKnife':
                TransformItem(Inv, "ZombieGame.ZombieKnife");
                break;
            case Class'AdrenalineShot':
                TransformItem(Inv, "ZombieGame.ZombieShot");
                break;
            case Class'RageArmour':
                TransformItem(Inv, "ZombieGame.ZombieArmour");
                break;
        }
    }
}

// Strip ranged items
function StripRanged(Pawn P)
{
    local Inventory Inv, NextInv;
    for (Inv = P.Inventory; Inv != None; Inv = NextInv)
    {
        NextInv = Inv.Inventory;
        if (!IsMeleeItem(Inv))
            Inv.Destroy();
    }
}

// Make sure they have melee items
function GiveMelee(Pawn P)
{
    local int i;
    for (i = 0; i < ArrayCount(MeleeItems); i++)
    {
        if (P.FindInventoryType(MeleeItems[i]) == None)
            GiveWeapon(P, MeleeItems[i].outer.name $ "." $ MeleeItems[i].Name);
    }
}

// Return false if candidate is too close to a spawn of the given team
function bool IsSpawnFarEnough(NavigationPoint candidate, int team)
{
    local PlayerStart PS;
    foreach RadiusActors(Class'PlayerStart', PS, MeleeDistance * 2, candidate.Location)
    {
        if (PS.TeamNumber == team)
            return false;
    }

    return true;
}

// Helper: append a NavigationPoint to the fixed array safely
function AddHumanSpawn(NavigationPoint NP)
{
    if (NumHumanSpawns >= ArrayCount(HumanSpawns))
        return;

    HumanSpawns[NumHumanSpawns++] = NP;
}

// Helper: append a NavigationPoint to the fixed array safely
function AddZombieSpawn(NavigationPoint NP)
{
    if (NumZombieSpawns >= ArrayCount(ZombieSpawns))
        return;

    ZombieSpawns[NumZombieSpawns++] = NP;
}

// SetPhysics(PHYS_Flying);
// SetPhysics(PHYS_None);

function byte GetInitialTeam(Pawn P)
{
    local int i;

    for (i = 0; i < ArrayCount(SavedTeams); i++)
    {
        if (SavedTeams[i].P == P)
            return SavedTeams[i].InitialTeam;
    }

    return 255;
}

function SetInitialTeam(Pawn P, byte team)
{
    local int i, emptyIdx;

    if (GetInitialTeam(P) != 255)
        return;

    emptyIdx = -1;
    for (i = 0; i < ArrayCount(SavedTeams); i++)
    {
        if (SavedTeams[i].P == None)
        {
            emptyIdx = i;
            break;
        }
    }

    if (emptyIdx != -1)
    {
        SavedTeams[emptyIdx].P = P;
        SavedTeams[emptyIdx].InitialTeam = team;
    }
}

function RemoveSavedTeam(Pawn P)
{
    local int i;
    for (i = 0; i < ArrayCount(SavedTeams); i++)
    {
        if (SavedTeams[i].P == P)
        {
            SavedTeams[i].P = None;
            SavedTeams[i].InitialTeam = 255;
            return;
        }
    }
}

// The game mode is asymmetrical; never auto-balance teams
function ReBalance()
{
}

function AddToTeam(int num, Pawn P)
{
    Super.AddToTeam(num, P);
    SetInitialTeam(P, num);

    // Apply live transformation if the pawn is already spawned
    if (P.Health > 0)
    {
        if (num == 1)
            BecomeZombie(P);
        else
            BecomeHuman(P);
    }
}

simulated function PreBeginPlay()
{
    local ZombieReplicationInfo ZRI;

    if (bZombieInfect)
    {
        FragLimit = 3;
        bScoreTeamKills = false;
    }
    else
    {
        FragLimit = 30;
        bScoreTeamKills = true;
    }

    Super.PreBeginPlay();
    ZRI = ZombieReplicationInfo(GameReplicationInfo);

    ZRI.bZombieInfect = bZombieInfect;
    ZRI.bKillTransform = bKillTransform;
    ZRI.zombieWeapons = zombieWeapons;
}

function PostBeginPlay()
{
    local NavigationPoint NP;
    local PlayerStart PS;
    local LoadoutBlocker LB;

    Super.PostBeginPlay();
    bBalanceTeams = false;
    bPlayersBalanceTeams = false;
    bZombieInfectSaved = bZombieInfect;

    // collect PlayerStart actors with TeamNumber == 255 and detonation keys for zombies
    for (NP = Level.NavigationPointList; NP != None; NP = NP.nextNavigationPoint)
    {
        PS = PlayerStart(NP);
        if (PS != None)
        {
            if (PS.TeamNumber == 255)
            {
                if (IsSpawnFarEnough(PS, 0) && IsSpawnFarEnough(PS, 1))
                    AddZombieSpawn(PS);
            }
            else
                AddHumanSpawn(PS);
        }
        else if (NP.IsA('RageDetPossibleKeyPos'))
            AddZombieSpawn(NP);
    }

    foreach AllActors(Class'LoadoutBlocker', LB)
        LB.Destroy();

    // if nothing's found, fallback to any PlayerStart (defensive)
    if (NumZombieSpawns == 0)
    {
        for (NP = Level.NavigationPointList; NP != None; NP = NP.nextNavigationPoint)
        {
            if (NP.IsA('PlayerStart'))
                AddZombieSpawn(NP);
        }
    }
}

// Reset bot AI state, clear targets, exit gunnery gracefully, and re-evaluate
function ResetBotAI(RageBot RB)
{
    RB.QuitGunnery();
    RB.Enemy = None;
    RB.OldEnemy = None;
    RB.Target = None;
    RB.WhatToDoNext('', '');
}

function ResetBotsAI(Pawn P)
{
    local RageBot RB;
    local Pawn Other;

    // Reset P if it's a bot
    RB = RageBot(P);
    if (RB != None)
        ResetBotAI(RB);

    // Clear references to P from all other bots in the match
    for (Other = Level.PawnList; Other != None; Other = Other.NextPawn)
    {
        RB = RageBot(Other);
        if (Other != P && RB != None && (RB.Enemy == P || RB.OldEnemy == P || RB.Target == P))
            ResetBotAI(RB);
    }
}

function MovedTeam(Pawn Instigator, Pawn Other)
{
    local byte OldTeam;
    OldTeam = Other.PlayerReplicationInfo.Team;

    ChangeTeam(Other, Instigator.PlayerReplicationInfo.Team);
    if (Teams[OldTeam].Size <= 0)
    {
        Instigator.PlayerReplicationInfo.Score += 2;
        RoundEnded(Instigator.PlayerReplicationInfo.Team);
        return;
    }

    // Reset bots AI safely for the pawn and any bots targeting it
    ResetBotsAI(Other);
}

function bool IsTeamDead(int num)
{
    local Pawn P;

    for (P = Level.PawnList; P != None; P = P.NextPawn)
    {
        if (
            P.Health > 0 &&
            P.PlayerReplicationInfo != None &&
            P.PlayerReplicationInfo.Team == num &&
            !P.IsA('Spectator') &&
            !P.IsInState('playerWaiting')
        )
            return false;
    }

    return true;
}

function PutPlayerToSpectate(RagePlayer RP)
{
    local name BackupRestartState;

    if (RP == None)
        return;

    ResetBotsAI(RP);
    if (Level.NetMode != NM_Standalone)
    {
        BackupRestartState = RP.PlayerRestartState;
        RP.PlayerRestartState = 'PlayerWalking';
        RP.StartWalk();
        RP.PlayerRestartState = BackupRestartState;
    }

    RP.GotoState('playerWaiting');
    RP.bProjTarget = false;
    RP.SetCollision(false, false, false);

    if (RP.bIsWalking && RP.Weapon != None)
        RP.Weapon.PutDown();
}

// Bots treat pawns in playerWaiting as teammates so they stop firing
function byte AssessBotAttitude(RBot aBot, Pawn Other)
{
    if (Other != None && Other.IsInState('playerWaiting'))
        return 3;

    return Super.AssessBotAttitude(aBot, Other);
}

function EndGame(string Reason)
{
    if ((bZombieInfect || bZombieInfectSaved) && Reason == "timelimit")
        RoundEnded(-1);
    else
        Super.EndGame(Reason);
}

function Killed(pawn killer, pawn victim, name damageType)
{
    local ZombiePlayer ZP;
    local ZombieBotBase ZB;
    local float UnitsAway;
    local int HealthBoost, MaxHealth;

    // Call parent first to do normal death processing
    Super.Killed(killer, victim, DamageType);

    if (!IsOnTeam(victim, 1))
    {
        // Don't let the last human cheat death...
        if (Teams[1].Size > 0 && IsTeamDead(0))
        {
            RoundEnded(1);
            return;
        }

        if (killer != None && IsOnTeam(killer, 1))
        {
            // Let the zombie feast...
            if (bZombieLifeSteal)
            {
                ZP = ZombiePlayer(killer);
                ZB = ZombieBotBase(killer);

                if (ZP != None)
                    MaxHealth = ZP.MaxHealth;
                else if (ZB != None)
                    MaxHealth = ZB.MaxHealth;
                else
                    MaxHealth = killer.Default.Health;

                UnitsAway = VSize(killer.Location - victim.Location) / MeleeDistance;
                HealthBoost = Min(MaxHealth / 11 * FMax(1.0 - UnitsAway, 0.0) + 0.5, 100);
                killer.Health = Min(killer.Health + healthBoost, MaxHealth);
            }

            // Move the infected to red before the round ends
            if (bZombieInfect && damageType != 'RunDown')
                MovedTeam(killer, victim);
        }

        // Send the human player to spectate next tick during Nemesis mode
        if (!bZombieInfect)
            humanPlayerRef = RagePlayer(victim);
    }
}

function RoundEnded(int Winner)
{
    if (Winner == -1)
    {
        if (Teams[0].Size > 0)
            Winner = 0;
        else
            Winner = 1;
    }

    Teams[Winner].Score += 1;

    if (Teams[Winner].Score >= FragLimit)
        Super.EndGame("fraglimit");
    else
        bPendingRestartRound = true;
}

function ProcessRegeneration(float Delta)
{
    local Pawn P;
    local ZombiePlayer ZP;
    local ZombieBotBase ZB;
    local int healAmount;

    for (P = Level.PawnList; P != None; P = P.NextPawn)
    {
        if (P.Health <= 0 || P.PlayerReplicationInfo == None || IsOnTeam(P, 1))
            continue;

        ZP = ZombiePlayer(P);
        ZB = ZombieBotBase(P);

        if (ZP != None && ZP.bIsNemesis && ZP.Health < ZP.MaxHealth)
        {
            ZP.regenerationAccumulator += ZP.regenerationRate * Delta;
            if (ZP.regenerationAccumulator >= 1.0)
            {
                healAmount = int(ZP.regenerationAccumulator);
                ZP.regenerationAccumulator -= healAmount;
                ZP.Health = Min(ZP.Health + healAmount, ZP.MaxHealth);
            }
        }
        else if (ZB != None && ZB.bIsNemesis && ZB.Health < ZB.MaxHealth)
        {
            ZB.regenerationAccumulator += ZB.regenerationRate * Delta;
            if (ZB.regenerationAccumulator >= 1.0)
            {
                healAmount = int(ZB.regenerationAccumulator);
                ZB.regenerationAccumulator -= healAmount;
                ZB.Health = Min(ZB.Health + healAmount, ZB.MaxHealth);
            }
        }
    }
}

function Tick(float Delta)
{
    if (bPendingRestartRound)
    {
        bPendingRestartRound = false;
        RestartRound();
    }

    if (humanPlayerRef != None)
    {
        PutPlayerToSpectate(humanPlayerRef);
        humanPlayerRef = None;
    }

    ProcessRegeneration(Delta);
}

function RestartRound()
{
    local Pawn P, NextP;
    local ZombieBotBase ZB;
    local ZombieReplicationInfo ZRI;
    local EnginePhysical Phys, NextPhys;
    local Vehicle V;
    local TripBomb TB;
    local TripBombOnGround TBG;
    local byte initTeam;

    RemainingTime = TimeLimit * 60;
    GameReplicationInfo.RemainingTime = RemainingTime;
    GameReplicationInfo.RemainingMinute = RemainingTime;
    ZRI = ZombieReplicationInfo(GameReplicationInfo);

    // Reset nemesis state between rounds
    bZombieInfect = bZombieInfectSaved;
    ZRI.bZombieInfect = bZombieInfectSaved;
    humanPlayerRef = None;

    // Destroy vehicles, wheels and trip bombs
    for (Phys = Level.VehicleList; Phys != None; Phys = NextPhys)
    {
        NextPhys = Phys.NextPhysical; // cache before SilentDestroy
        V = Vehicle(Phys);
        if (V != None)
            V.SilentDestroy();
    }

    foreach AllActors(Class'TripBomb', TB)
    {
        TB.Laser.Destroy();
        TB.Destroy();
    }

    foreach AllActors(Class'TripBombOnGround', TBG)
        TBG.Destroy();

    bRestartingRound = true;

    // Pass 1: Reset all players to initial teams first so team sizes are settled
    for (P = Level.PawnList; P != None; P = NextP)
    {
        NextP = P.NextPawn;
        if (P.PlayerReplicationInfo != None && !P.IsA('Spectator'))
        {
            initTeam = GetInitialTeam(P);
            if (initTeam != 255 && initTeam != P.PlayerReplicationInfo.Team)
                ChangeTeam(P, initTeam);
        }
    }

    // Pass 2: Reset inventory, state, and respawn all players
    for (P = Level.PawnList; P != None; P = NextP)
    {
        NextP = P.NextPawn;
        if (P.PlayerReplicationInfo != None && !P.IsA('Spectator'))
        {
            ZB = ZombieBotBase(P);
            if (P.IsA('PlayerPawn'))
            {
                DiscardInventory(P);
                PlayerPawn(P).bBehindView = false;
                PlayerPawn(P).ViewTarget = None;
                PlayerPawn(P).bProjTarget = true;
                PlayerPawn(P).SetCollision(true, true, true);

                if (IsOnTeam(P, 1))
                    P.PlayerRestartState = 'PlayerWalking';
                else
                    P.PlayerRestartState = 'StartupInLoadout';

                P.GotoState(P.PlayerRestartState);
            }
            else if (ZB != None)
            {
                ZB.addLoadoutInventory();
                P.GotoState('StartUp');
            }

            RestartPlayer(P);
        }
    }

    bRestartingRound = false;
}

event Logout(Pawn Exiting)
{
    Super.Logout(Exiting);
    RemoveSavedTeam(Exiting);
}

// Applies buffs based on the game state at the time of respawn
function bool RestartPlayer(pawn P)
{
    // During mid-round Nemesis mode, dead humans do not respawn until round restart
    if (!bRestartingRound && !bZombieInfect && !IsOnTeam(P, 1))
        return false;

    if (Super.RestartPlayer(P))
    {
        if (IsOnTeam(P, 1))
            BecomeZombie(P);
        else
            BecomeHuman(P);

        return true;
    }

    return false;
}

// Zombies get jack shite
function AddDefaultInventory(Pawn P)
{
    if (IsOnTeam(P, 1))
        GiveMelee(P);
    else
        Super.AddDefaultInventory(P);
}

// Return true if candidate is close to friendly players and far from enemies
function bool IsForTeam(Pawn P, NavigationPoint candidate, int friendlyTarget)
{
    local Pawn Other;
    local float UnitsAway;
    local int friendlyPlayers;

    friendlyPlayers = 0;
    for (Other = Level.PawnList; Other != None; Other = Other.NextPawn)
    {
        // Prevents counting self and vehicles etc
        if (Other.PlayerReplicationInfo == None || Other == P)
            continue;

        UnitsAway = VSize(Other.Location - candidate.Location) / MeleeDistance;
        if (IsOnTeam(Other, P.PlayerReplicationInfo.Team))
        {
            if (UnitsAway < 4.5)
                friendlyPlayers++;
        }
        else if (UnitsAway < 1.5)
            return false;
    }

    return friendlyPlayers >= friendlyTarget;
}

function bool IsSpawnFree(NavigationPoint candidate)
{
    local Pawn Other;
    foreach RadiusActors(Class'Pawn', Other, 70.0, candidate.Location)
    {
        if (Other.bCollideActors && Other.Health > 0)
            return false;
    }

    return true;
}

// avoid the other team when picking a spawn point
function NavigationPoint PickSpawn(Pawn P)
{
    local int pass, tries, friendlyTarget;
    local NavigationPoint candidate;

    for (pass = 0; pass < 3; pass++)
    {
        // Fallback: no friendlies in the area needed after pass 0
        friendlyTarget = (Teams[P.PlayerReplicationInfo.Team].Size / 4) * int(pass == 0);

        for (tries = 0; tries < 6; tries++)
        {
            if (P.PlayerReplicationInfo.Team == 1)
                candidate = ZombieSpawns[Rand(NumZombieSpawns)];
            else
                candidate = HumanSpawns[Rand(NumHumanSpawns)];

            // Fallback: any unoccupied team spawn after pass 1
            if (IsSpawnFree(candidate) && (pass > 1 || IsForTeam(P, candidate, friendlyTarget)))
                return candidate;
        }
    }

    // Fallback: return something anyway
    return candidate;
}

function NavigationPoint FindPlayerStart(Pawn P, optional byte InTeam, optional string incomingName)
{
    if (bSpawnAnywhere && P != None && P.PlayerReplicationInfo != None)
        return PickSpawn(P);

    // fallback to normal behavior
    return Super.FindPlayerStart(P, InTeam, incomingName);
}

function bool SetEndCams(string Reason)
{
    if (Super.SetEndCams(Reason))
    {
        if (Teams[0].Score > Teams[1].Score)
            GameReplicationInfo.GameEndedComments = "Humans have survived the apocalypse!";
        else
            GameReplicationInfo.GameEndedComments = "Zombies have taken over the world!";

        return true;
    }

    return false;
}

event PlayerPawn Login
(
    string Portal,
    string Options,
    out string Error,
    class<PlayerPawn> SpawnClass
) {
    local PlayerPawn P;
    P = Super.Login(Portal, Options, Error, Class'ZombiePlayer');

    if (P != None)
    {
        if (SpawnClass != None)
        {
            P.TeamSkin0 = SpawnClass.default.TeamSkin0;
            P.TeamSkin1 = SpawnClass.default.TeamSkin1;
            P.TeamSkin2 = SpawnClass.default.TeamSkin2;
            P.TeamSkin3 = SpawnClass.default.TeamSkin3;
            P.TeamSkinCaptain = SpawnClass.default.TeamSkinCaptain;
            P.TeamSkinName = SpawnClass.default.TeamSkinName;
            P.TeamMeshName = SpawnClass.default.TeamMeshName;
            P.MenuName = SpawnClass.default.MenuName;
            P.Mesh = SpawnClass.default.Mesh;
        }

        if (P.PlayerReplicationInfo != None)
        {
            if (P.PlayerReplicationInfo.Team == 1)
                P.PlayerRestartState = 'PlayerWalking';

            P.static.SetMultiSkin(P, P.TeamSkinName, P.PlayerReplicationInfo.Team);
        }
        else
            P.static.SetMultiSkin(P, P.TeamSkinName, 0);
    }

    return P;
}

function pawn AddBot(optional byte Type)
{
    if (Type < 1)
    {
        // Passively try to maintain a ratio of 3 humans vs 1 zombie
        if (Teams[0].Size < 3 * Max(Teams[1].Size, 1))
            Type = 1;
        else
            Type = 2;
    }

    return Super.AddBot(Type);
}

// Zombies fear no car...
function int ReduceDamage(int Damage, name DamageType, pawn injured, pawn instigatedBy)
{
    if (DamageType == 'RunDown' && injured.PlayerReplicationInfo != None && injured.PlayerReplicationInfo.Team == 1)
        Damage /= 10;

    return Super.ReduceDamage(Damage, DamageType, injured, instigatedBy);
}

defaultproperties
{
     zBiasExp=0.180000
     zombieWeapons=1
     bZombieLifeSteal=True
     bSpawnAnywhere=True
     bZombieInfect=True
     bKillTransform=False
     MeleeDistance=600
     MeleeItems(0)=Class'ZombieGame.ZombieArmour'
     MeleeItems(1)=Class'ZombieGame.ZombieShot'
     MeleeItems(2)=Class'ZombieGame.ZombieKnife'
     FriendlyFireScale=0.010000
     MaxTeamSize=32
     StartUpTeamMessage="You are a"
     teamcolor(0)="Human"
     teamcolor(1)="Zombie"
     FragLimit=3
     TimeLimit=8
     InstructionSound=Sound'RagePlayerVoice.Fire_At_Will'
     BotConfigType=Class'ZombieGame.ZombieBotInfo'
     DefaultPlayerClass=Class'ZombieGame.ZombiePlayer'
     ScoreBoardType=Class'ZombieGame.ZombieScoreBoard'
     HUDType=Class'ZombieGame.ZombieHUD'
     MapPrefix="ZM-"
     BeaconName="ZM"
     GameName="Zombie Mode"
     DMMessageClass=Class'ZombieGame.ZombieMessageDM'
     GameReplicationInfoClass=Class'ZombieGame.ZombieReplicationInfo'
}
