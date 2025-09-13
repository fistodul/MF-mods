//=============================================================================
// TugGame by Animeman - 2025, includes derivatives of Player & ReplicationInfo
//=============================================================================
class TugGame extends RageTeamGame config;

var config bool bSpawnAnywhere; // Don't spawn just from your base
var config bool bKillTransform; // Instead of respawning, instantly turn into the other team
var int MeleeDistance;

var NavigationPoint BlueSpawns[100];
var int NumBlueSpawns;

var NavigationPoint RedSpawns[100];
var int NumRedSpawns;

// Helper: append a NavigationPoint to the fixed array safely
function AddBlueSpawn(NavigationPoint NP)
{
    if (NumBlueSpawns >= 100)
        return;

    BlueSpawns[NumBlueSpawns++] = NP;
}

// Helper: append a NavigationPoint to the fixed array safely
function AddRedSpawn(NavigationPoint NP)
{
    if (NumRedSpawns >= 100)
        return;

    RedSpawns[NumRedSpawns++] = NP;
}

function PostBeginPlay()
{
    local Actor Act;
    local PlayerStart PS;
    local RageDetPossibleKeyPos DK;

    Super.PostBeginPlay();
    if (bSpawnAnywhere) {
        NumBlueSpawns = 0;
        NumRedSpawns = 0;

        // collect PlayerStart actors with TeamNumber == 255 and detonation keys
        foreach AllActors(class'Actor', Act)
        {
            if (Act.IsA('PlayerStart'))
            {
                PS = PlayerStart(Act);

                if (PS.TeamNumber != 1)
                    AddBlueSpawn(PS);
                if (PS.TeamNumber != 0)
                    AddRedSpawn(PS);
            }
            else if (Act.IsA('RageDetPossibleKeyPos')) {
                DK = RageDetPossibleKeyPos(Act);
                AddBlueSpawn(DK);
                AddRedSpawn(DK);
            }
        }
    }
}

// Move the killed player to the other team
function Killed(pawn killer, pawn victim, name damageType)
{
    // Call parent first to do normal death processing
    Super.Killed(killer, victim, DamageType);
    if (killer.PlayerReplicationInfo.Team != victim.PlayerReplicationInfo.Team)
        ChangeTeam(victim, killer.PlayerReplicationInfo.Team);
}

// Return true if candidate is close to friendly players and far from enemies
function bool IsForTeam(Pawn P, actor candidate, int team)
{
    local Pawn Other;
    local float UnitsAway;
    local int friendlyPlayers;

    friendlyPlayers = 0;
    foreach AllActors(class'Pawn', Other)
    {
        // Prevents counting self and vehicles etc
        if (Other.PlayerReplicationInfo == None || Other == P)
            continue;

        UnitsAway = VSize(Other.Location - candidate.Location) / MeleeDistance;
        if (IsOnTeam(Other, team)) {
            if (UnitsAway < 3)
                friendlyPlayers++;
        }
        else if (UnitsAway < 1.5)
            return false;
    }

    return friendlyPlayers >= Teams[P.PlayerReplicationInfo.Team].Size / 4;
}

// avoid the other team when picking a spawn point
function NavigationPoint PickSpawn(Pawn P, int team)
{
    local int tries;
    local NavigationPoint candidate;

    // attempt a few random picks
    for (tries = 0; tries < 9; tries++)
    {
        if (team == 1)
            candidate = RedSpawns[Rand(NumRedSpawns)];
        else
            candidate = BlueSpawns[Rand(NumBlueSpawns)];

        if (IsForTeam(P, candidate, team))
            return candidate;
    }

    // If we couldn't find a far away spawn, return something anyway
    return candidate;
}

function NavigationPoint FindPlayerStart(Pawn P, optional byte InTeam, optional string incomingName)
{
    if (bSpawnAnywhere)
        return PickSpawn(P, P.PlayerReplicationInfo.Team);

    // fallback to normal behavior
    return Super.FindPlayerStart(P, InTeam, incomingName);
}

event PlayerPawn Login
(
    string Portal,
    string Options,
    out string Error,
    class<PlayerPawn> SpawnClass
)
{
    if (bKillTransform)
        SpawnClass = class'TugPlayer';

    return Super.Login(Portal, Options, Error, SpawnClass);
}

defaultproperties
{
    bSpawnAnywhere=false
    bKillTransform=false
    MeleeDistance=600
    GameName="Tug of war"
    FriendlyFireScale=0.0
    MaxTeamSize=32
    bBalanceTeams=false
    bPlayersBalanceTeams=false
    bBalancing=true
    MapPrefix='TG-'
    DefaultPlayerClass=class'TugPlayer'
    GameReplicationInfoClass=class'TugReplicationInfo'
}
