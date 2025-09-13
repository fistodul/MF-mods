class TugPlayer extends RagePlayerX;

state PlayerWalking
{
    function TakeDamage(int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, name damageType)
    {
        local TugGame TG;
        TG = TugGame(Level.Game);

        if (
            TG.bKillTransform && instigatedBy != none && Health - Damage <= 0 &&
            PlayerReplicationInfo.Team != instigatedBy.PlayerReplicationInfo.Team
        )
        {
            Damage = 0;
            TG.Killed(instigatedBy, self, damageType);
        }

        Super.TakeDamage(Damage, instigatedBy, hitlocation, momentum, damageType);
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
    TeamSkinName="RagePlayerGfx.MFTeamA"
    TeamMeshName="RageGfx.RagePlayer1Mesh"
    MenuName="Assault Trooper"
    Mesh=SkeletalMesh'RageGfx.RagePlayer1Mesh'
}
