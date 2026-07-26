class ZombieShot extends AdrenalineShot;

function InjectDrug(Pawn Injectee)
{
    local ZombiePlayer ZP;
    local ZombieBotBase ZB;
    local int MaxHealth;

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
