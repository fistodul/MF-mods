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

function float RateSelf(out int bUseAltMode)
{
    local int MaxHealth;
    local ZombiePlayer ZP;
    local ZombieBotBase ZB;
    local Pawn P;

    if (GetAmmoCount() <= 0)
        return -100.0;

    ZP = ZombiePlayer(Owner);
    ZB = ZombieBotBase(Owner);
    P = Pawn(Owner);

    if (ZP != None)
        MaxHealth = ZP.MaxHealth;
    else if (ZB != None)
        MaxHealth = ZB.MaxHealth;
    else
        MaxHealth = P.Default.Health;

    // If bot is badly injured, inject self
    if (P.Health < (MaxHealth * 0.45))
    {
        bUseAltMode = 0;
        return 0.95;
    }

    // If in melee range, try to inject enemy
    if (
        P.Enemy != None && GetZombieGame().bZombieInfect && P.VehicleIn != None &&
        VSize(P.Enemy.Location - P.Location) <= (Range + 30.0) && P.Enemy.Health <= 100
    ) {
        bUseAltMode = 1;
        return 1.0;
    }

    return -1.0;
}

function InjectDrug(Pawn Injectee)
{
    local Pawn O;
    local ZombiePlayer ZP;
    local ZombieBotBase ZB;
    local int MaxHealth;
    local vector HitLocation;

    if (Injectee == None || Injectee.PlayerReplicationInfo == None)
        return;

    O = Pawn(Owner);
    if (O.PlayerReplicationInfo.Team != Injectee.PlayerReplicationInfo.Team)
    {
        if (GetZombieGame().bZombieInfect && Injectee.Health <= 100)
        {
            UseAmmo(1);
            GetZombieGame().MovedTeam(O, Injectee);
            O.PlayerReplicationInfo.Score += 2.0;

            if (!GetZombieGame().bKillTransform)
                Injectee.Died(O, MyDamageType, HitLocation);
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

defaultproperties
{
     AIRating=-1.000000
}
