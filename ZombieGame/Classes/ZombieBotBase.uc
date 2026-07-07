class ZombieBotBase extends RageBot;

var int MaxHealth;

replication
{
    reliable if (Role == ROLE_Authority)
        MaxHealth;
}

// Zombies get jack shite
function AddLoadoutInventory()
{
    //local ZombieGame ZG;
    //ZG = ZombieGame(Level.Game);

    if (/*ZG != None && ZG.zombieWeapons > 3 || */PlayerReplicationInfo.Team != 1)
        Super.AddLoadoutInventory();
}

function Died(pawn Killer, name damageType, vector HitLocation)
{
    local ZombieGame ZG;
    ZG = ZombieGame(Level.Game);

    if (
        ZG != None && ZG.bZombieInfect && ZG.bKillTransform &&
        Killer != None && Killer.PlayerReplicationInfo != None &&
        PlayerReplicationInfo.Team != 1 && Killer.PlayerReplicationInfo.Team == 1
    ) {
        Health = MaxHealth;
        ZG.Killed(Killer, self, damageType);
        return;
    }

    Super.Died(Killer, damageType, HitLocation);
}

defaultproperties
{
    bGoodDriver=True
    PreferedTeam=0
    PlayerReplicationInfoClass=Class'ZombieBotRepInfo'
}
