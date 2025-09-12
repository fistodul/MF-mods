//=============================================================================
// ZombieGame by Animeman - 2025, includes derivatives of Player, HUD, Knife...
//=============================================================================
class ZombieGame extends RageTeamGame config;

// Exponent influencing zombie strength, recommended values: 0.16 - 0.2
var config float Z_BiasExp;

var config bool bZombieWeapons; // Can zombies use weapons at all
var config bool bZombieCrateWeapons; // If so, can they use weapon crates
var config bool bZombieLifeSteal; // Consume the flesh of the fallen to regenerate...

var config bool bSpawnAnywhere; // Don't spawn Zombies just from red base
var config bool bZombieInfect; // Humans turn into zombies upon being killed by one
var config bool bInfectTransform; // Instead of respawning, instantly turn into a zombie

var int MeleeDistance;
var NavigationPoint ZombieSpawns[100];
var int NumZombieSpawns;

var NavigationPoint HumanSpawns[50];
var int NumHumanSpawns;

// Allows changing the default values and restoring them without guessing
var int SavedHealth;
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
    P.Default.Health = SavedHealth;
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
    local float boost;
    boost = FClamp(
        (float(Teams[0].Size) / Max(Teams[1].Size, 1)) ** Z_BiasExp,
        1.0, 1.25
    );

    P.BaseGroundSpeed = P.Default.BaseGroundSpeed * 1.45 * boost;
    P.Default.Health = SavedHealth * 3.2 * boost;
    P.Health = P.Default.Health;
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

    if (bInfectTransform || !bZombieCrateWeapons) {
        StripRanged(P);
	    if (P.FindInventoryType(class'ZombieKnife') == None) {
            GiveWeapon(P, "ZombieGame.ZombieKnife");
        }
    }
}

// Strip ranged items
function StripRanged(Pawn P)
{
    local Inventory inv; // Inv.Next
    for( Inv=P.Inventory; Inv!=None; Inv=Inv.Inventory )
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
        if (P.FindInventoryType(MeleeItems[i]) == None) {
            GiveWeapon(P, MeleeItems[i].outer.name $ "." $ MeleeItems[i].Name);
        }
    }
}

// Helper: append a NavigationPoint to the fixed array safely
function AddZombieSpawn(NavigationPoint NP)
{
    if (NumZombieSpawns >= 100)
        return;

    ZombieSpawns[NumZombieSpawns++] = NP;
}

// Helper: append a NavigationPoint to the fixed array safely
function AddHumanSpawn(NavigationPoint NP)
{
    if (NumZombieSpawns >= 50)
        return;

    HumanSpawns[NumHumanSpawns++] = NP;
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

function PostBeginPlay()
{
    local Actor Act;
    local PlayerStart PS;

    Super.PostBeginPlay();
    SavedHealth = class'Pawn'.Default.Health;
    SavedJumpZ = class'Pawn'.Default.JumpZ;

    if (bSpawnAnywhere) {
        NumZombieSpawns = 0;
        NumHumanSpawns = 0;

        // collect PlayerStart actors with TeamNumber == 255 and detonation keys
        foreach AllActors(class'Actor', Act)
        {
            if (Act.IsA('PlayerStart'))
            {
                PS = PlayerStart(Act);

                if (PS.TeamNumber == 255)
                    AddZombieSpawn(PS);
                else
                    AddHumanSpawn(PS);
            }
            else if (Act.IsA('RageDetPossibleKeyPos'))
                AddZombieSpawn(RageDetPossibleKeyPos(Act));
            else if (Act.IsA('LoadoutBlocker')) 
                Act.Destroy();
        }

        // if nothing's found, fallback to any PlayerStart (defensive)
        if (NumZombieSpawns == 0)
        {
            foreach AllActors(class'PlayerStart', PS)
                AddZombieSpawn(PS);
        }
    }
}

function Killed(pawn killer, pawn victim, name damageType)
{
    local float UnitsAway;
    local int HealthBoost;

    // Call parent first to do normal death processing
    Super.Killed(killer, victim, DamageType);

    if (IsOnTeam(killer, 1) && !IsOnTeam(victim, 1))
    {
        // Let the zombie feast...
        if (bZombieLifeSteal) {
            UnitsAway = VSize(killer.Location - victim.Location) / MeleeDistance;
            HealthBoost = 30 * FMax(1.0 - UnitsAway, 0.0) + 0.5;
            killer.Health = Min(killer.Health + healthBoost, killer.Default.Health);
        }

        // Move the infected to red
        if (bZombieInfect)
            ChangeTeam(victim, 1);
    }
}

// Applies buffs based on the game state at the time of respawn
function bool RestartPlayer(pawn P)
{
    local bool bResult;
    bResult = Super.RestartPlayer(P);

    if (bResult) {
        if (IsOnTeam(P, 1))
            BecomeZombie(P);
        else
            BecomeHuman(P);
    }

    return bResult;
}

// Zombies get jack shite
function AddDefaultInventory(Pawn P)
{
    if (IsOnTeam(P, 1))
        GiveMelee(P);
    else
        Super.AddDefaultInventory(P);
}

// Return true if candidate is more than MeleeDistance away from every Pawn not on it's team
function bool IsForTeam(Pawn P, actor candidate, int team)
{
    local Pawn Other;
    foreach AllActors(class'Pawn', Other)
    {
        // Prevents counting self and vehicles etc
        if (Other.PlayerReplicationInfo == None || Other == P)
            continue;

        if (!IsOnTeam(Other, team) && VSize(Other.Location - candidate.Location) < MeleeDistance * 1.5)
            return false;
    }

    return true;
}

// avoid humans when spawning zombies and vice versa
function NavigationPoint PickSpawn(Pawn P, int team)
{
    local int tries;
    local NavigationPoint candidate;

    // attempt a few random picks
    for (tries = 0; tries < 7; tries++)
    {
        if (team == 1)
            candidate = ZombieSpawns[Rand(NumZombieSpawns)];
        else
            candidate = HumanSpawns[Rand(NumHumanSpawns)];

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

function EndGame(string Reason)
{
    Super.EndGame(Reason);

    // Restore defaults globally
    class'Pawn'.Default.Health = SavedHealth;
    class'Pawn'.Default.JumpZ  = SavedJumpZ;
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

    if (P != None)
        P.PlayerRestartState = 'PlayerWalking';

    //RestartPlayer(P);
    return P;
}

defaultproperties
{
    Z_BiasExp=0.18
    bZombieWeapons=true
    bZombieCrateWeapons=false
    bZombieLifeSteal=true
    bSpawnAnywhere=true
    bZombieInfect=true
    bInfectTransform=false
    MeleeDistance=600
    MeleeItems(2)=class'ZombieKnife'
    MeleeItems(1)=class'AdrenalineShot'
    MeleeItems(0)=class'RageArmour'
    GameName="Zombie Mode"
    StartUpTeamMessage="You are a"
    TeamColor(0)="Human"
    TeamColor(1)="Zombie"
    FriendlyFireScale=0.01
    MaxTeamSize=32
    bBalanceTeams=false
    bPlayersBalanceTeams=false
    bBalancing=true
    MapPrefix='ZM-'
    DefaultPlayerClass=class'ZombiePlayer'
    GameReplicationInfoClass=class'ZombieReplicationInfo'
    HUDType=class'ZombieHUD'
    ScoreBoardType=class'ZombieScoreBoard'
    DMMessageClass=class'ZombieMessageDM'
}
