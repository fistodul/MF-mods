class ZombiePlayer extends RagePlayerX;

simulated function ETryLoadoutResult TryLoadoutZone()
{
    local ZombieGame ZG;
    ZG = ZombieGame(Level.Game);

    if (ZG == None || PlayerReplicationInfo.Team != 1 || ZG.bZombieWeapons > 2)
        return Super.TryLoadoutZone();
    else
        return Loadout_None;
}

simulated function ETryLoadoutResult TryLoadoutCrate()
{
    local ZombieGame ZG;
    ZG = ZombieGame(Level.Game);

    if (ZG == None || PlayerReplicationInfo.Team != 1 || ZG.bZombieWeapons > 1)
        return Super.TryLoadoutCrate();
    else
        return Loadout_None;
}

// Can't believe there wasn't one already there
function GlobalTakeDamage(int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, name damageType)
{
    local ZombieGame ZG;
    local ZombieReplicationInfo ZRI;

    ZG = ZombieGame(Level.Game);
    ZRI = ZombieReplicationInfo(GameReplicationInfo);

    if (ZG != None && ZRI != None)
    {
        if (damageType == 'RunDown' && PlayerReplicationInfo.Team == 1)
            Damage /= 10;

        ClientMessage("bZombieInfect: " $ ZRI.bZombieInfect);
        ClientMessage("bKillTransform: " $ ZRI.bKillTransform);

        if (
            ZRI.bZombieInfect && ZRI.bKillTransform && PlayerReplicationInfo.Team != 1 &&
            instigatedBy != None && instigatedBy.PlayerReplicationInfo != None &&
            Health - Damage <= 0 && instigatedBy.PlayerReplicationInfo.Team == 1
        )
        {
            Damage = 0;
            ZG.Killed(instigatedBy, self, damageType);
        }
    }
}

/*state InCarState
{
    function TakeDamage(int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, name damageType)
    {
        GlobalTakeDamage(Damage, instigatedBy, hitlocation, momentum, damageType);
        Super.TakeDamage(Damage, instigatedBy, hitlocation, momentum, damageType);
    }
}*/

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
        local ZombieGame ZG;
        ZG = ZombieGame(Level.Game);

        if (ZG == None || PlayerReplicationInfo.Team != 1 || ZG.bZombieWeapons > 0)
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
