class ZombieBotBase extends RageBot;

var int MaxHealth;
var bool bIsNemesis;
var float regenerationRate;
var float regenerationAccumulator;

replication
{
    reliable if (Role == ROLE_Authority)
        MaxHealth;
}

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    regenerationAccumulator = 0.0;
}

function bool AddInventory(inventory NewItem)
{
    local bool Ret;
    local RageWeapon RW;

    Ret = Super.AddInventory(NewItem);

    if (bIsNemesis && PlayerReplicationInfo.Team != 1)
    {
        RW = RageWeapon(NewItem);
        if (RW != None && (RW.MaxClips > 1 || RW.MaxClipAmmo > 1))
        {
            RW.MaxClipAmmo = 9999;
            RW.GiveFullAmmo();
        }
    }

    return Ret;
}

// Zombies get jack shite
function AddLoadoutInventory()
{
    local ZombieGame ZG;
    ZG = ZombieGame(Level.Game);

    if (ZG != None)
    {
        if (ZG.zombieWeapons > 3 || PlayerReplicationInfo.Team != 1)
            Super.AddLoadoutInventory();
        ZG.TransformItems(self);
    }
    else if (PlayerReplicationInfo.Team != 1)
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
     bAlwaysRelevant=True
     bIsNemesis=False
     regenerationRate=1.500000
     bGoodDriver=True
     PreferedTeam=0
}
