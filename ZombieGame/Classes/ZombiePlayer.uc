class ZombiePlayer extends RagePlayerX;

var ZombieGame ZG;
var int MaxHealth;
var byte MaxCarry;

replication
{
    reliable if (Role < ROLE_Authority)
        BecomeHuman, BecomeZombie, RunAs, SetTo, SetToLooking, GetTo, GetToLooking, Teleport;
    reliable if (Role == ROLE_Authority)
        MaxHealth, MaxCarry;
}

function ZombieGame GetZombieGame()
{
    if (ZG == None)
    {
        ZG = ZombieGame(Level.Game);
        if (ZG == None)
            ZG = Spawn(Class'ZombieGame', self);
    }

    return ZG;
}

function String UntilSpace(string s)
{
    local int SpacePosition;
    SpacePosition = InStr(s, " ");

    if (SpacePosition != -1)
        Return Left(s, SpacePosition);

    Return s;
}

function Pawn GetPawn(string PlayerName)
{
    local Pawn P;
    for (P = Level.PawnList; P != None; P = P.NextPawn)
    {
        if (P.PlayerReplicationInfo != None && P.PlayerReplicationInfo.PlayerName ~= PlayerName)
            return P;
    }

    return None;
}

exec function RunAs(string command)
{
    local string PlayerName;
    local Pawn P;

	if (!bAdmin && (Level.Netmode != NM_Standalone))
		return;

    PlayerName = UntilSpace(command);
    P = GetPawn(PlayerName);

    if (P != None)
    {
        command = Mid(command, Len(PlayerName) + 1);
        P.ConsoleCommand(command);
    }
}

exec function SetTo(string command)
{
    local string temp;
    local Pawn P;

	if (!bAdmin && (Level.Netmode != NM_Standalone))
		return;

    temp = UntilSpace(command);
    P = GetPawn(temp);

    if (P != None)
    {
        command = Mid(command, Len(temp) + 1);
        temp = UntilSpace(command);
        command = Mid(command, Len(temp) + 1);

        // temp becomes the property and command the value
        P.SetPropertyText(temp, command);
    }
}

exec function GetTo(string command)
{
    local string property;
    local Pawn P;

	if (!bAdmin && (Level.Netmode != NM_Standalone))
		return;

    property = UntilSpace(command);
    P = GetPawn(property);

    if (P != None)
    {
        command = Mid(command, Len(property) + 1);
        ClientMessage(P.GetPropertyText(command));
    }
}

exec function SetToLooking(string command)
{
    local string property;
    local vector HitLocation, HitNormal;
    local Actor A;

	if (!bAdmin && (Level.Netmode != NM_Standalone))
		return;

    A = Trace(HitLocation, HitNormal, Location + Vector(Rotation) * 10000, Location);
    if (A != None)
    {
        property = UntilSpace(command);
        command = Mid(command, Len(property) + 1);

        A.SetPropertyText(property, command);
    }
}

exec function GetToLooking(string command)
{
    local vector HitLocation, HitNormal;
    local Actor A;

	if (!bAdmin && (Level.Netmode != NM_Standalone))
		return;

    A = Trace(HitLocation, HitNormal, Location + Vector(Rotation) * 10000, Location);
    if (A != None)
        ClientMessage(A.GetPropertyText(command));
}

exec function Teleport(string PlayerName)
{
    local Pawn P;
    local int tries;

    if (!bAdmin && (Level.Netmode != NM_Standalone))
        return;

    P = GetPawn(PlayerName);
    if (P != None)
    {
        // attempt a few random picks
        for (tries = 0; tries < 9; tries++)
        {
            if (SetLocation(P.Location + VRand() * vect(100, 100, 10)))
                break;
        }
    }
}

exec function BecomeHuman()
{
    if (!bAdmin && (Level.Netmode != NM_Standalone))
        return;

    GetZombieGame().BecomeHuman(self);
}

exec function BecomeZombie()
{
    if (!bAdmin && (Level.Netmode != NM_Standalone))
        return;

    GetZombieGame().BecomeZombie(self);
}

simulated function ETryLoadoutResult TryLoadoutZone()
{
    local ZombieReplicationInfo ZRI;
    ZRI = ZombieReplicationInfo(GameReplicationInfo);

    if (ZRI == None || PlayerReplicationInfo.Team != 1 || ZRI.zombieWeapons > 3)
        return Super.TryLoadoutZone();
    else
        return Loadout_None;
}

simulated function ETryLoadoutResult TryLoadoutCrate()
{
    local ZombieReplicationInfo ZRI;
    ZRI = ZombieReplicationInfo(GameReplicationInfo);

    if (ZRI == None || PlayerReplicationInfo.Team != 1 || ZRI.zombieWeapons > 2)
        return Super.TryLoadoutCrate();
    else
        return Loadout_None;
}

// Can't believe there wasn't one already there
function GlobalTakeDamage(int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, name damageType)
{
    if (damageType == 'RunDown' && PlayerReplicationInfo.Team == 1)
        Damage /= 10;
}

function Died(pawn Killer, name damageType, vector HitLocation)
{
    local ZombieReplicationInfo ZRI;
    ZRI = ZombieReplicationInfo(GameReplicationInfo);

    if (
        ZRI != None && ZRI.bZombieInfect && ZRI.bKillTransform && Killer != None &&
        Killer != self && Killer.PlayerReplicationInfo != None &&
        PlayerReplicationInfo.Team != 1 && Killer.PlayerReplicationInfo.Team == 1
    )
    {
        Health = MaxHealth;
        GetZombieGame().Killed(Killer, self, damageType);
        return;
    }

    Super.Died(Killer, damageType, HitLocation);
}

simulated function bool CanIPickup(Inventory Weap)
{
    local int Count;
    local Inventory Inv;

    if (Weap == none || (Weap.CarrySize + CurrentCarry) > MaxCarry)
        return false;

    // Check how many of these i am allowed
    for (Inv = Inventory; Inv != None; Inv = Inv.Inventory)
    {
        if (Inv.Class == Weap.Class)
            Count++;
    }

    if (Count >= Weap.MaxCanCarry)
        return false;

    return true;
}

state PlayerSwimming
{
    function TakeDamage(int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, name damageType)
    {
        GlobalTakeDamage(Damage, instigatedBy, hitlocation, momentum, damageType);
        Super.TakeDamage(Damage, instigatedBy, hitlocation, momentum, damageType);
    }
}

state PlayerWalking
{
    function TakeDamage(int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, name damageType)
    {
        GlobalTakeDamage(Damage, instigatedBy, hitlocation, momentum, damageType);
        Super.TakeDamage(Damage, instigatedBy, hitlocation, momentum, damageType);
    }

    exec function TryLoadout()
    {
        local ZombieReplicationInfo ZRI;
        ZRI = ZombieReplicationInfo(GameReplicationInfo);

        if (ZRI == None || PlayerReplicationInfo.Team != 1 || ZRI.zombieWeapons > 0)
            Super.TryLoadout();
        else
            ClientMessage("Nice try, zombie!");
    }
}

defaultproperties
{
    PlayerReplicationInfoClass=Class'ZombiePlayerReplicationInfo'
    MaxCarry=6
    Footstep1=Sound'RagePlayerSounds.(All).stone01'
    Footstep2=Sound'RagePlayerSounds.(All).stone02'
    Footstep3=Sound'RagePlayerSounds.(All).stone03'
    TeamSkin1=1
    TeamSkin2=2
    TeamSkin3=3
    TeamSkinCaptain=2
    TeamSkinName="RagePlayerGfx.MFTeamB"
    TeamMeshName="RageGfx.RagePlayer2Mesh"
    MenuName="Covert Trooper"
    Mesh=SkeletalMesh'RageGfx.RagePlayer2Mesh'
}
