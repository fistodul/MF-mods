class TugBotBase extends RageBot;

// The same function as in TugPlayer except this time it IS global
function TakeDamage(int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, name damageType)
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

	Super.TakeDamage (Damage, instigatedBy, hitlocation, momentum, damageType);
}

defaultproperties
{
    bGoodDriver=True
}
