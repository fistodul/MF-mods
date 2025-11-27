class TugBotBase extends RageBot;

function Died(pawn Killer, name damageType, vector HitLocation)
{
    local TugGame TG;
    TG = TugGame(Level.Game);

    if (
        TG != None && TG.bKillTransform && Killer != None && 
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
    bGoodDriver=True
}
