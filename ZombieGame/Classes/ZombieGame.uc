//=============================================================================
// ZombieGame by Animeman - 2025, includes derivatives of Player, HUD, Knife...
//=============================================================================
class ZombieGame extends RageTeamGame config;

// Exponent influencing zombie strength, recommended values: 0.16 - 0.2
var config float Z_BiasExp;

var config int bZombieWeapons; // Zombie weapon ability (0 - 3)
var config bool bZombieLifeSteal; // Consume the flesh of the fallen to regenerate...

var config bool bSpawnAnywhere; // Don't spawn Zombies just from red base
var config bool bZombieInfect; // Humans turn into zombies upon being killed by one
var config bool bKillTransform; // Instead of respawning, instantly turn into a zombie

var NavigationPoint HumanSpawns[50];
var int NumHumanSpawns;

var int MeleeDistance;
var NavigationPoint ZombieSpawns[50];
var int NumZombieSpawns;

// Allows changing the default values and restoring them without guessing
var float SavedJumpZ;

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
    P.BaseGroundSpeed = P.Default.BaseGroundSpeed;
    ZombiePlayerReplicationInfo(P.PlayerReplicationInfo).DefaultHealth = P.Default.Health;
    P.Health = P.Default.Health;
    P.MaxCarry = P.Default.MaxCarry;

    P.FallDamageThreshold = P.Default.FallDamageThreshold;
    P.FallDeathThreshold = P.Default.FallDeathThreshold;
    P.Default.JumpZ = SavedJumpZ;
    P.JumpZ = P.Default.JumpZ;

    P.GroundSpeed = P.Default.GroundSpeed;
    P.WaterSpeed = P.Default.WaterSpeed;
    //P.AirSpeed = P.Default.AirSpeed;

    P.AccelRate = P.Default.AccelRate;
    P.MaxStepHeight = P.Default.MaxStepHeight;
    //P.AirControl = P.Default.AirControl;
    //P.LadderSpeed = P.Default.LadderSpeed;
}

// Buff physical prowess based on scaled defaults
function BecomeZombie(Pawn P)
{
    local ZombiePlayerReplicationInfo ZPRI;
    local float boost;

    ZPRI = ZombiePlayerReplicationInfo(P.PlayerReplicationInfo);
    boost = FClamp(
        (float(Teams[0].Size) / Max(Teams[1].Size, 1)) ** Z_BiasExp,
        1.0, 1.25
    );

    P.BaseGroundSpeed = P.Default.BaseGroundSpeed * 1.45 * boost;
    ZPRI.DefaultHealth = P.Default.Health * 3.3 * boost;
    P.Health = ZPRI.DefaultHealth;
    P.MaxCarry = P.Default.MaxCarry - 2;

    P.FallDamageThreshold = P.Default.FallDamageThreshold * 1.5;
    P.FallDeathThreshold = P.Default.FallDeathThreshold * 1.5;
    P.Default.JumpZ = SavedJumpZ * 1.4 * boost;
    P.JumpZ = P.Default.JumpZ;

    P.GroundSpeed = P.BaseGroundSpeed - 80;
    P.WaterSpeed = P.Default.WaterSpeed * 2;
    //P.AirSpeed = 200;

    P.AccelRate = P.Default.AccelRate * 1.15;
    P.MaxStepHeight = P.Default.MaxStepHeight * 1.15;
    //P.AirControl = P.Default.AirControl * 1.75;
    //P.LadderSpeed = P.Default.LadderSpeed * 1.5;

    TransformItems(P);
    if (bZombieWeapons < 2)
        StripRanged(P);
}

// Give Zombie equivalents to Human items
function TransformItems(Pawn P)
{
    local Inventory inv; // Inv.Next
    for(Inv=P.Inventory; Inv!=None; Inv=Inv.Inventory)
    {
        switch (Inv.Class) {
            case class'AdrenalineShot':
                Inv.Destroy();
                GiveWeapon(P, "ZombieGame.ZombieShot");
                break;
            case class'RageKnife':
                Inv.Destroy();
                GiveWeapon(P, "ZombieGame.ZombieKnife");
                break;
        }
    }
}

// Strip ranged items
function StripRanged(Pawn P)
{
    local Inventory inv; // Inv.Next
    for(Inv=P.Inventory; Inv!=None; Inv=Inv.Inventory)
    {
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
    foreach RadiusActors(class'PlayerStart', PS, MeleeDistance * 2, candidate.Location)
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

function bool ChangeTeam(Pawn P, int num)
{
    // Let parent do its book-keeping first (teamcounts etc).
    if (Super.ChangeTeam(P, num))
    {
        // Fix for bots not having a team in RestartPlayer...
        if (num == 1)
            BecomeZombie(P);
        else
            BecomeHuman(P);

        return true;
    }

    return false;
}

simulated function PreBeginPlay()
{
    if (bZombieInfect)
    {
        FragLimit = 3;
        bScoreTeamKills = false;
    }
    else
        FragLimit = 30;

    Super.PreBeginPlay();
    ZombieReplicationInfo(GameReplicationInfo).bZombieInfect = bZombieInfect;
}

function PostBeginPlay()
{
    local NavigationPoint NP;
    local PlayerStart PS;
    local LoadoutBlocker LB;

    Super.PostBeginPlay();
    SavedJumpZ = class'Pawn'.Default.JumpZ;

    NumHumanSpawns = 0;
    NumZombieSpawns = 0;

    // collect PlayerStart actors with TeamNumber == 255 and detonation keys for zombies
    for(NP = Level.NavigationPointList; NP != None; NP = NP.nextNavigationPoint)
    {
        if (NP.IsA('PlayerStart'))
        {
            PS = PlayerStart(NP);

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

    foreach AllActors(class'LoadoutBlocker', LB)
        LB.Destroy();

    // if nothing's found, fallback to any NavigationPoint (defensive)
    if (NumZombieSpawns == 0)
    {
        for(NP = Level.NavigationPointList; NP != None; NP = NP.nextNavigationPoint)
        {
            if (NP.IsA('PlayerStart') || NP.IsA('RageDetPossibleKeyPos'))
                AddZombieSpawn(NP);
        }
    }
}

function Killed(pawn killer, pawn victim, name damageType)
{
    local float UnitsAway;
    local int HealthBoost;
    local ZombiePlayerReplicationInfo ZPRI;

    // Call parent first to do normal death processing
    Super.Killed(killer, victim, DamageType);

    if (IsOnTeam(killer, 1) && !IsOnTeam(victim, 1))
    {
        // Let the zombie feast...
        if (bZombieLifeSteal)
        {
            UnitsAway = VSize(killer.Location - victim.Location) / MeleeDistance;
            HealthBoost = 30 * FMax(1.0 - UnitsAway, 0.0) + 0.5;

            ZPRI = ZombiePlayerReplicationInfo(killer.PlayerReplicationInfo);
            killer.Health = Min(killer.Health + healthBoost, ZPRI.DefaultHealth);
        }

        // Move the infected to red
        if (bZombieInfect)
        {
            if (Teams[0].Size <= 1)
            {
                killer.PlayerReplicationInfo.Score += 5;
                Teams[1].Score += 1;

                if (Teams[1].Score >= FragLimit)
                    EndGame("fraglimit");

                // Go to the next round if the team is wiped out
            }

            ChangeTeam(victim, 1);
        }
    }
}

// Applies buffs based on the game state at the time of respawn
function bool RestartPlayer(pawn P)
{
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
        if (IsOnTeam(Other, P.PlayerReplicationInfo.Team))
        {
            if (UnitsAway < 5)
                friendlyPlayers++;
        }
        else if (UnitsAway < 1.5)
            return false;
    }

    return friendlyPlayers >= Teams[P.PlayerReplicationInfo.Team].Size / 4;
}

// avoid humans when spawning zombies and vice versa
function NavigationPoint PickSpawn(Pawn P)
{
    local int tries;
    local NavigationPoint candidate;

    // attempt a few random picks
    for (tries = 0; tries < 9; tries++)
    {
        if (P.PlayerReplicationInfo.Team == 1)
            candidate = ZombieSpawns[Rand(NumZombieSpawns)];
        else
            candidate = HumanSpawns[Rand(NumHumanSpawns)];

        if (IsForTeam(P, candidate))
            return candidate;
    }

    // If we couldn't find a far away spawn, return something anyway
    return candidate;
}

function NavigationPoint FindPlayerStart(Pawn P, optional byte InTeam, optional string incomingName)
{
    if (bSpawnAnywhere && P.PlayerReplicationInfo != none)
        return PickSpawn(P);

    // fallback to normal behavior
    return Super.FindPlayerStart(P, InTeam, incomingName);
}

function EndGame(string Reason)
{
    Super.EndGame(Reason);

    // Restore defaults globally
    class'Pawn'.Default.JumpZ  = SavedJumpZ;
}

function Logout(pawn Exiting)
{
    Super.Logout(Exiting);

    // Restore defaults individually
    Exiting.Default.JumpZ  = SavedJumpZ;
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
)
{
    local PlayerPawn P;
    P = Super.Login(Portal, Options, Error, class'ZombiePlayer');

    if (P != None && P.PlayerReplicationInfo.Team == 1)
        P.PlayerRestartState = 'PlayerWalking';

    //RestartPlayer(P);
    return P;
}

defaultproperties
{
    Z_BiasExp=0.18
    bZombieWeapons=1
    bZombieLifeSteal=true
    bSpawnAnywhere=true
    bZombieInfect=true
    bKillTransform=false
    MeleeDistance=600
    MeleeItems(2)=class'ZombieKnife'
    MeleeItems(1)=class'ZombieShot'
    MeleeItems(0)=class'RageArmour'
    GameName="Zombie Mode"
    TimeLimit=9
    StartUpTeamMessage="You are a"
    TeamColor(0)="Human"
    TeamColor(1)="Zombie"
    FriendlyFireScale=0.01
    MaxTeamSize=32
    bBalanceTeams=false
    bBalancing=true
    MapPrefix="ZM-"
    BeaconName="ZM"
    DefaultPlayerClass=class'ZombiePlayer'
    GameReplicationInfoClass=class'ZombieReplicationInfo'
    HUDType=class'ZombieHUD'
    ScoreBoardType=class'ZombieScoreBoard'
    DMMessageClass=class'ZombieMessageDM'
}
