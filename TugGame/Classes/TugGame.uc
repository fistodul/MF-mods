//=============================================================================
// TugGame by Animeman - 2025, includes derivatives of Player & ReplicationInfo
//=============================================================================
class TugGame extends RageTeamGame;

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

// Fix for bots not having a team at login or whatever...
function bool ChangeTeam(Pawn P, int num)
{
    local TugPlayerReplicationInfo TPRI;
    local TugBotRepInfo TBRI;

    // Let parent do its book-keeping first (teamcounts etc).
    if (Super.ChangeTeam(P, num))
    {
        if (P.PlayerReplicationInfo != None)
        {
            TPRI = TugPlayerReplicationInfo(P.PlayerReplicationInfo);
            TBRI = TugBotRepInfo(P.PlayerReplicationInfo);

            if (TPRI != None && TPRI.InitialTeam == 255)
                TPRI.InitialTeam = P.PlayerReplicationInfo.Team;
            else if (TBRI != None && TBRI.InitialTeam == 255)
                TBRI.InitialTeam = P.PlayerReplicationInfo.Team;
        }

        return true;
    }

    return false;
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

// Move the killed player to the other team
function Killed(pawn killer, pawn victim, name damageType)
{
    // Call parent first to do normal death processing
    Super.Killed(killer, victim, DamageType);

    if (killer.PlayerReplicationInfo.Team != victim.PlayerReplicationInfo.Team)
    {
        if (Teams[victim.PlayerReplicationInfo.Team].Size <= 1)
        {
            killer.PlayerReplicationInfo.Score += 5;
            RoundEnded(killer.PlayerReplicationInfo.Team);
        }

        ChangeTeam(victim, killer.PlayerReplicationInfo.Team);
    }
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
        RestartRound();
}

function RestartRound()
{
    local Pawn P;
    local EnginePhysical Phys;
    local Vehicle V;
    local TripBombOnGround T;

    local TugPlayerReplicationInfo TPRI;
    local TugBotRepInfo TBRI;

    RemainingTime = TimeLimit * 60;
    GameReplicationInfo.RemainingTime = RemainingTime;
    GameReplicationInfo.RemainingMinute = RemainingTime;

    // Destroy vehicles, wheels and trip bombs
    for (Phys = Level.VehicleList; Phys != None; Phys = Phys.NextPhysical)
    {
        V = Vehicle(Phys);
        if (V != None)
            V.SilentDestroy();
    }

    foreach AllActors(Class'TripBombOnGround', T)
        T.Destroy();

    // Reset players to initial teams and respawn
    for (P = Level.PawnList; P != None; P = P.NextPawn)
    {
        if (P.PlayerReplicationInfo != None && !P.IsA('Spectator'))
        {
            // Reset team to initial
            TPRI = TugPlayerReplicationInfo(P.PlayerReplicationInfo);
            TBRI = TugBotRepInfo(P.PlayerReplicationInfo);

            if (TPRI != None && TPRI.InitialTeam != P.PlayerReplicationInfo.Team)
                ChangeTeam(P, TPRI.InitialTeam);
            else if (TBRI != None && TBRI.InitialTeam != P.PlayerReplicationInfo.Team)
                ChangeTeam(P, TBRI.InitialTeam);

            // Reset inventory and respawn
            if (P.IsA('PlayerPawn'))
            {
                DiscardInventory(P);
                P.GotoState('PlayerWalking');
            }
            else
                TugBotBase(P).addLoadoutInventory();

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

    if (Teams[0].Size == 0 && Teams[1].Size > 0)
        RoundEnded(1);
    else if (Teams[1].Size == 0 && Teams[0].Size > 0)
        RoundEnded(0);
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
)
{
    local PlayerPawn P;
    P = Super.Login(Portal, Options, Error, Class'TugPlayer');

    if (P != None && P.PlayerReplicationInfo != None)
        TugPlayerReplicationInfo(P.PlayerReplicationInfo).InitialTeam = P.PlayerReplicationInfo.Team;

    return P;
}

defaultproperties
{
    bSpawnAnywhere=false
    bKillTransform=true
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
