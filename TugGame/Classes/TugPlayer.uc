class TugPlayer extends RagePlayerX;

function Died(pawn Killer, name damageType, vector HitLocation)
{
    local TugGame TG;
    local TugReplicationInfo TRI;

    TG = TugGame(Level.Game);
    TRI = TugReplicationInfo(GameReplicationInfo);

    if (
        TG != None && TRI.bKillTransform && Killer != None && 
        Killer.PlayerReplicationInfo != None && Killer.PlayerReplicationInfo.Team == 1
    )
    {
        Health = Default.Health;
        TG.Killed(Killer, self, damageType);
        return;
    }

	Super.Died(Killer, damageType, HitLocation);
}

defaultproperties
{
    Footstep1=Sound'RagePlayerSounds.(All).stone01'
    Footstep2=Sound'RagePlayerSounds.(All).stone02'
    Footstep3=Sound'RagePlayerSounds.(All).stone03'
    TeamSkin1=1
    TeamSkin2=2
    TeamSkin3=3
    TeamSkinName="RagePlayerGfx.MFTeamA"
    TeamMeshName="RageGfx.RagePlayer1Mesh"
    MenuName="Assault Trooper"
    Mesh=SkeletalMesh'RageGfx.RagePlayer1Mesh'
}
