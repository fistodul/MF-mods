class ZombiePlayer extends RagePlayerX;

exec function BecomeHuman()
{
    local ZombieGame ZG;
    ZG = ZombieGame(Level.Game);

    if(ZG == None || !bGreatDane)
		return;

    ZG.BecomeHuman(self);
}

exec function BecomeZombie()
{
    local ZombieGame ZG;
    ZG = ZombieGame(Level.Game);

    if(ZG == None || !bGreatDane)
		return;

    ZG.BecomeZombie(self);
}

simulated function ETryLoadoutResult TryLoadoutZone()
{
    local ZombieReplicationInfo ZRI;
    ZRI = ZombieReplicationInfo(GameReplicationInfo);

    if (ZRI == None || PlayerReplicationInfo.Team != 1 || ZRI.zombieWeapons > 2)
        return Super.TryLoadoutZone();
    else
        return Loadout_None;
}

simulated function ETryLoadoutResult TryLoadoutCrate()
{
    local ZombieReplicationInfo ZRI;
    ZRI = ZombieReplicationInfo(GameReplicationInfo);

    if (ZRI == None || PlayerReplicationInfo.Team != 1 || ZRI.zombieWeapons > 1)
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
    local ZombieGame ZG;
    local ZombieReplicationInfo ZRI;

    ZG = ZombieGame(Level.Game);
    ZRI = ZombieReplicationInfo(GameReplicationInfo);

    if (
        ZG != None && ZRI.bZombieInfect && ZRI.bKillTransform && Killer != None &&
        Killer != self && Killer.PlayerReplicationInfo != None &&
        PlayerReplicationInfo.Team != 1 && Killer.PlayerReplicationInfo.Team == 1
    )
    {
        Health = ZombiePlayerReplicationInfo(PlayerReplicationInfo).DefaultHealth;
        ZG.Killed(Killer, self, damageType);
        return;
    }

	Super.Died(Killer, damageType, HitLocation);
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
    PlayerReplicationInfoClass=Class'ZombiePlayerReplicationInfo'
}
