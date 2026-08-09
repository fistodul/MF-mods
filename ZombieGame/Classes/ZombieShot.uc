class ZombieShot extends AdrenalineShot;

var ZombieGame ZG;

function ZombieGame GetZombieGame()
{
    if (ZG == None)
    {
        ZG = ZombieGame(Level.Game);
        if (ZG == None)
            ZG = Spawn(Class'ZombieGame', self);
    }

    return ZG;
}

function InjectDrug(Pawn Injectee)
{
    local ZombiePlayer ZP;
    local ZombieBotBase ZB;
    local int MaxHealth;
    local vector HitLocation;

    if (Pawn(Owner).PlayerReplicationInfo.Team != Injectee.PlayerReplicationInfo.Team)
    {
        if (GetZombieGame().bZombieInfect && Injectee.Health <= 100)
        {
            if (GetZombieGame().bKillTransform)
                GetZombieGame().MovedTeam(Pawn(Owner), Injectee);
            else
                Injectee.Died(Pawn(Owner), MyDamageType, HitLocation);

            UseAmmo(1);
        }

        return;
    }

    ZP = ZombiePlayer(Injectee);
    ZB = ZombieBotBase(Injectee);

    if (ZP != None)
        MaxHealth = ZP.MaxHealth;
    else if (ZB != None)
        MaxHealth = ZB.MaxHealth;
    else
        MaxHealth = Injectee.Default.Health;

    if (Injectee.Health < MaxHealth)
    {
        UseAmmo(1);
        Injectee.Health = MaxHealth;
        Injectee.PlaySound(Injectee.HitSound2, SLOT_Talk, 0.6);
    }
}
