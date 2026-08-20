class CoopPlayer extends RagePlayerX;

simulated function ETryLoadoutResult TryLoadoutZone()
{
    local CoopReplicationInfo CRI;
    CRI = CoopReplicationInfo(GameReplicationInfo);

    if (CRI == None || CRI.weapons > 3)
        return Super.TryLoadoutZone();

    return Loadout_None;
}

simulated function ETryLoadoutResult TryLoadoutCrate()
{
    local CoopReplicationInfo CRI;
    CRI = CoopReplicationInfo(GameReplicationInfo);

    if (CRI == None || CRI.weapons > 2)
        return Super.TryLoadoutCrate();

    return Loadout_None;
}

state PlayerWalking
{
    exec function TryLoadout()
    {
        local CoopReplicationInfo CRI;
        CRI = CoopReplicationInfo(GameReplicationInfo);

        if (CRI == None || CRI.weapons > 0)
            Super.TryLoadout();
        else
            ClientMessage("Nice try, human!");
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
}
