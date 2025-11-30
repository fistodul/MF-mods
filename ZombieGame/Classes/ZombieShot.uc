class ZombieShot extends AdrenalineShot;

function InjectDrug(Pawn Injectee)
{
    local int MaxHealth;

    if (Injectee.IsA('ZombiePlayer'))
        MaxHealth = ZombiePlayer(Injectee).MaxHealth;
    else if (Injectee.IsA('ZombieBotBase'))
        MaxHealth = ZombieBotBase(Injectee).MaxHealth;
    else
        MaxHealth = Injectee.Default.Health;

    if (Injectee.Health < MaxHealth)
    {
        UseAmmo(1);
        Injectee.Health = MaxHealth;
        Injectee.PlaySound(Injectee.HitSound2, SLOT_Talk, 0.6);
    }
}
