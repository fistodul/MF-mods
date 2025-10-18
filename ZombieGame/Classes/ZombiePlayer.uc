class ZombiePlayer extends RagePlayerX;

simulated function ETryLoadoutResult TryLoadoutZone()
{
    local ZombieGame ZG;
    ZG = ZombieGame(Level.Game);

    if (PlayerReplicationInfo.Team != 1 || ZG.bZombieWeapons > 2)
        return Super.TryLoadoutZone();
    else
        return Loadout_None;
}

simulated function ETryLoadoutResult TryLoadoutCrate()
{
    local ZombieGame ZG;
    ZG = ZombieGame(Level.Game);

    if (PlayerReplicationInfo.Team != 1 || ZG.bZombieWeapons > 1)
        return Super.TryLoadoutCrate();
    else
        return Loadout_None;
}

state PlayerWalking
{
    function TakeDamage(int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, name damageType)
    {
        local ZombieGame ZG;
        ZG = ZombieGame(Level.Game);

        if (damageType == 'RunDown' && PlayerReplicationInfo.Team == 1)
            Damage /= 10;

        if (
            ZG.bZombieInfect && ZG.bKillTransform && PlayerReplicationInfo.Team != 1 &&
            instigatedBy != none && instigatedBy.PlayerReplicationInfo != none && 
            Health - Damage <= 0 && instigatedBy.PlayerReplicationInfo.Team == 1
        )
        {
            Damage = 0;
            ZG.Killed(instigatedBy, self, damageType);
        }

        Super.TakeDamage(Damage, instigatedBy, hitlocation, momentum, damageType);
    }

    exec function TryLoadout()
    {
        local ZombieGame ZG;
        ZG = ZombieGame(Level.Game);

        if (PlayerReplicationInfo.Team != 1 || ZG.bZombieWeapons > 0)
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
    PlayerReplicationInfoClass=class'ZombiePlayerReplicationInfo'
}
