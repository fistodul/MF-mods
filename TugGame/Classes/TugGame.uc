//=============================================================================
// TugGame by Animeman - 2025, includes derivatives of Player & ReplicationInfo
//=============================================================================
class TugGame extends RageTeamGame config;

var config bool bSpawnAnywhere; // Don't spawn just from your base
var config bool bKillTransform; // Instead of respawning, instantly turn into the other team
var int MeleeDistance;

var NavigationPoint BlueSpawns[50];
var int NumBlueSpawns;

var NavigationPoint RedSpawns[50];
var int NumRedSpawns;

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

simulated function PreBeginPlay()
{
    Super.PreBeginPlay();
    TugReplicationInfo(GameReplicationInfo).bKillTransform = bKillTransform;
}

function PostBeginPlay()
{
    local NavigationPoint NP;

    Super.PostBeginPlay();
    NumBlueSpawns = 0;
    NumRedSpawns = 0;

    // collect PlayerStart actors with TeamNumber == 255 and detonation keys for everyone
    for(NP = Level.NavigationPointList; NP != None; NP = NP.nextNavigationPoint)
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

// Move the killed player to the other team
function Killed(pawn killer, pawn victim, name damageType)
{
    // Call parent first to do normal death processing
    Super.Killed(killer, victim, DamageType);

    if (killer.PlayerReplicationInfo.Team != victim.PlayerReplicationInfo.Team) {
        if (Teams[victim.PlayerReplicationInfo.Team].Size <= 1) {
            killer.PlayerReplicationInfo.Score += 5;
            Teams[killer.PlayerReplicationInfo.Team].Score += 1;

            if (Teams[killer.PlayerReplicationInfo.Team].Score >= FragLimit)
                EndGame("fraglimit");

            // Go to the round if the team is wiped out
        }

        ChangeTeam(victim, killer.PlayerReplicationInfo.Team);
    }
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

/*function EndGame(string Reason)
{
    local int Biggest;

    if (Reason == "timelimit") {
        if (Teams[0].Size > Teams[1].Size)
            Biggest = 0;
        else if (Teams[0].Size < Teams[1].Size)
            Biggest = 1;
        else
            Biggest = Rand(2);

            Teams[Biggest].Score += 1;
            //if (Teams[Biggest].Score >= FragLimit)
            //    EndGame("fraglimit");

        TimeLimit = 9;
        TugReplicationInfo(GameReplicationInfo).TimeLimit = TimeLimit;
        TugReplicationInfo(GameReplicationInfo).RemainingTime = TimeLimit * 60;
        return;
    }

    Super.EndGame(Reason);
}*/

event PlayerPawn Login
(
    string Portal,
    string Options,
    out string Error,
    class<PlayerPawn> SpawnClass
)
{
    if (bKillTransform)
        SpawnClass = Class'TugPlayer';

    return Super.Login(Portal, Options, Error, SpawnClass);
}

defaultproperties
{
    bSpawnAnywhere=false
    bKillTransform=false
    MeleeDistance=600
    GameName="Tug of war"
    BotConfigType=Class'TugBotInfo'
    bScoreTeamKills=false
    FragLimit=3
    TimeLimit=9
    FriendlyFireScale=0.0
    MaxTeamSize=32
    bBalanceTeams=false
    bBalancing=true
    MapPrefix="TG-"
    BeaconName="TG"
    DefaultPlayerClass=Class'TugPlayer'
    GameReplicationInfoClass=Class'TugReplicationInfo'
    HUDType=Class'TugHUD'
}
