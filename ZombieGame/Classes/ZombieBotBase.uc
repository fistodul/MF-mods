class ZombieBotBase extends RageBot;

var int MaxHealth;

replication
{
    reliable if (Role == ROLE_Authority)
        MaxHealth;
}

// Zombies get jack shite
/*function AddLoadoutInventory()
{
    local ZombieGame ZG;
    ZG = ZombieGame(Level.Game);

    if (ZG != None && ZG.zombieWeapons > 3 || PlayerReplicationInfo.Team != 1)
        Super.AddLoadoutInventory();
}*/

// The same function as in ZombiePlayer except this time it IS global
function TakeDamage(int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, name damageType)
{
    if (damageType == 'RunDown' && PlayerReplicationInfo.Team == 1)
        Damage /= 10;

	Super.TakeDamage(Damage, instigatedBy, hitlocation, momentum, damageType);
}

function Died(pawn Killer, name damageType, vector HitLocation)
{
    local ZombieGame ZG;
    ZG = ZombieGame(Level.Game);

    if (
        ZG != None && ZG.bZombieInfect && ZG.bKillTransform &&
        Killer != None && Killer.PlayerReplicationInfo != None &&
        PlayerReplicationInfo.Team != 1 && Killer.PlayerReplicationInfo.Team == 1
    )
    {
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
}
