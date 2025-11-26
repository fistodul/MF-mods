class TugPlayer extends RagePlayerX;

// Can't believe there wasn't one already there
function GlobalTakeDamage(int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, name damageType)
{
    local TugGame TG;
    TG = TugGame(Level.Game);

    if (
        TG.bKillTransform && instigatedBy != None &&
        instigatedBy.PlayerReplicationInfo != None && Health - Damage <= 0 &&
        PlayerReplicationInfo.Team != instigatedBy.PlayerReplicationInfo.Team
    )
    {
        Damage = 0;
        Health = Default.Health;
        TG.Killed(instigatedBy, self, damageType);
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
