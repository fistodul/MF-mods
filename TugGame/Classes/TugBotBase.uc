class TugBotBase extends RageBot;

// The same function as in ZombiePlayer except this time it IS global
function TakeDamage(int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, name damageType)
{
    local TugGame TG;
    TG = TugGame(Level.Game);

    if (ZG != None)
    {
        if (damageType == 'RunDown' && PlayerReplicationInfo.Team == 1)
            Damage /= 10;

        if (
            ZG.bZombieInfect && ZG.bKillTransform && PlayerReplicationInfo.Team != 1 &&
            instigatedBy != None && instigatedBy.PlayerReplicationInfo != None &&
            Health - Damage <= 0 && instigatedBy.PlayerReplicationInfo.Team == 1
        )
        {
            Damage = 0;
            ZG.Killed(instigatedBy, self, damageType);
        }
    }

	Super.TakeDamage (Damage, instigatedBy, hitlocation, momentum, damageType);
}

defaultproperties
{
    bGoodDriver=True
}
