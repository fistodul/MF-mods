//=============================================================================
// TugGame by Animeman - 2025, includes derivatives of Player & ReplicationInfo
//=============================================================================
class TugGame extends RageTeamGame;

struct TeamTracker
{
    var Pawn P;
    var byte InitialTeam;
};
var TeamTracker SavedTeams[128];

var config bool bSpawnAnywhere; // Don't spawn just from your base
var config bool bKillTransform; // Instead of respawning, instantly turn into the other team

var int MeleeDistance;
var bool bPendingRestartRound;

var NavigationPoint BlueSpawns[50], RedSpawns[50];
var int NumBlueSpawns, NumRedSpawns;

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
function AddBlueSpawn(NavigationPoint NP)
{
    if (NumBlueSpawns >= ArrayCount(BlueSpawns))
        return;

    BlueSpawns[NumBlueSpawns++] = NP;
}

// Helper: append a NavigationPoint to the fixed array safely
function AddRedSpawn(NavigationPoint NP)
{
    if (NumRedSpawns >= ArrayCount(RedSpawns))
        return;

    RedSpawns[NumRedSpawns++] = NP;
}

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
        }
    }
}

// Fix for bots not having a team at login or whatever...
function AddToTeam(int num, Pawn P)
{
    // Let parent do its book-keeping first (teamcounts etc).
    Super.AddToTeam(num, P);
    SetInitialTeam(P, num);
}

simulated function PreBeginPlay()
{
    Super.PreBeginPlay();
    TugReplicationInfo(GameReplicationInfo).bKillTransform = bKillTransform;
}

function PostBeginPlay()
{
    local NavigationPoint NP;

    Super.PostBeginPlay();
    bPendingRestartRound = false;
    NumBlueSpawns = 0;
    NumRedSpawns = 0;

    // collect PlayerStart actors with TeamNumber == 255 and detonation keys for everyone
    for (NP = Level.NavigationPointList; NP != None; NP = NP.nextNavigationPoint)
    {
        if (NP.IsA('PlayerStart') || NP.IsA('RageDetPossibleKeyPos'))
        {
            if (IsSpawnFarEnough(NP, 1))
                AddBlueSpawn(NP);
            if (IsSpawnFarEnough(NP, 0))
                AddRedSpawn(NP);
        }
    }
}

// Reset bot AI state, clear targets, exit gunnery gracefully, and re-evaluate
function ResetBotAI(RageBot RB)
{
    RB.QuitGunnery();
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
        if (
            Other != P && RB != None && P.Health > 0 &&
            (RB.Enemy == P || RB.OldEnemy == P || RB.Target == P)
        )
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

// Move the killed player to the other team before the round ends
function Killed(pawn killer, pawn victim, name damageType)
{
    // Call parent first to do normal death processing
    Super.Killed(killer, victim, DamageType);

    if (killer != None && killer.PlayerReplicationInfo.Team != victim.PlayerReplicationInfo.Team)
        MovedTeam(killer, victim);
}

function RoundEnded(int Winner)
{
    if (Winner == -1)
    {
        if (Teams[0].Size > Teams[1].Size)
            Winner = 0;
        else if (Teams[0].Size < Teams[1].Size)
            Winner = 1;
        else
            Winner = Rand(2);
    }

    Teams[Winner].Score += 1;

    if (Teams[Winner].Score >= FragLimit)
        Super.EndGame("fraglimit");
    else
        bPendingRestartRound = true;
}

function Tick(float Delta)
{
    if (bPendingRestartRound)
    {
        bPendingRestartRound = false;
        RestartRound();
    }
}

function RestartRound()
{
    local Pawn P, NextP;
    local RageBot RB;
    local EnginePhysical Phys, NextPhys;
    local Vehicle V;
    local TripBomb TB;
    local TripBombOnGround TBG;
    local byte initTeam;

    RemainingTime = TimeLimit * 60;
    GameReplicationInfo.RemainingTime = RemainingTime;
    GameReplicationInfo.RemainingMinute = RemainingTime;

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

    // Reset players to initial teams and respawn
    for (P = Level.PawnList; P != None; P = NextP)
    {
        NextP = P.NextPawn; // Cache before modifying player or changing team

        if (P.PlayerReplicationInfo != None && !P.IsA('Spectator'))
        {
            initTeam = GetInitialTeam(P);
            if (initTeam != 255 && initTeam != P.PlayerReplicationInfo.Team)
                ChangeTeam(P, initTeam);

            // Reset inventory and respawn
            RB = RageBot(P);
            if (P.IsA('PlayerPawn'))
            {
                DiscardInventory(P);
                P.PlayerRestartState = 'StartupInLoadout';
                P.GotoState(P.PlayerRestartState);
            }
            else if (RB != None)
            {
                RB.addLoadoutInventory();
                P.GotoState('StartUp');
            }

            RestartPlayer(P);
        }
    }
}

function EndGame(string Reason)
{
    if (Reason == "timelimit")
        RoundEnded(-1);
    else 
        Super.EndGame(Reason);
}

event Logout(Pawn Exiting)
{
    Super.Logout(Exiting);
    RemoveSavedTeam(Exiting);
}

// Return true if candidate is close to friendly players and far from enemies
function bool IsForTeam(Pawn P, actor candidate)
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
        if (IsOnTeam(Other, P.PlayerReplicationInfo.Team)) {
            if (UnitsAway < 5)
                friendlyPlayers++;
        }
        else if (UnitsAway < 1.5)
            return false;
    }

    return friendlyPlayers >= Teams[P.PlayerReplicationInfo.Team].Size / 4;
}

// avoid the other team when picking a spawn point
function NavigationPoint PickSpawn(Pawn P)
{
    local int tries;
    local NavigationPoint candidate;

    // attempt a few random picks
    for (tries = 0; tries < 9; tries++)
    {
        if (P.PlayerReplicationInfo.Team == 1)
            candidate = RedSpawns[Rand(NumRedSpawns)];
        else
            candidate = BlueSpawns[Rand(NumBlueSpawns)];

        if (IsForTeam(P, candidate))
            return candidate;
    }

    // If we couldn't find a far away spawn, return something anyway
    return candidate;
}

function NavigationPoint FindPlayerStart(Pawn P, optional byte InTeam, optional string incomingName)
{
    if (bSpawnAnywhere && P != None && P.PlayerReplicationInfo != None)
        return PickSpawn(P);

    // fallback to normal behavior
    return Super.FindPlayerStart(P, InTeam, incomingName);
}

event PlayerPawn Login
(
    string Portal,
    string Options,
    out string Error,
    class<PlayerPawn> SpawnClass
) {
    local PlayerPawn P;
    P = Super.Login(Portal, Options, Error, Class'TugPlayer');

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
            P.static.SetMultiSkin(P, P.TeamSkinName, P.PlayerReplicationInfo.Team);
        else
            P.static.SetMultiSkin(P, P.TeamSkinName, 0);
    }

    return P;
}

defaultproperties
{
     bSpawnAnywhere=False
     bKillTransform=True
     MeleeDistance=600
     bScoreTeamKills=False
     GoalTeamScore=3.000000
     MaxTeamSize=32
     FragLimit=3
     TimeLimit=8
     BotConfigType=Class'TugGame.TugBotInfo'
     DefaultPlayerClass=Class'TugGame.TugPlayer'
     HUDType=Class'TugGame.TugHUD'
     bBalanceTeams=False
     bPlayersBalanceTeams=False
     MapPrefix="TG-"
     BeaconName="TG"
     GameName="Tug of war"
     GameReplicationInfoClass=Class'TugGame.TugReplicationInfo'
}
