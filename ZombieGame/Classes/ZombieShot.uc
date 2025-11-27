class ZombieShot extends AdrenalineShot;

function InjectDrug(Pawn Injectee)
{
    local int MaxHealth;
    local ZombiePlayerReplicationInfo ZPRI;
    local ZombieBotRepInfo ZBRI;

    ZPRI = ZombiePlayerReplicationInfo(Injectee.PlayerReplicationInfo);
    ZBRI = ZombieBotRepInfo(Injectee.PlayerReplicationInfo);

    if (ZPRI != None)
        MaxHealth = ZPRI.DefaultHealth;
    else if (ZBRI != None)
        MaxHealth = ZBRI.DefaultHealth;
    else
        MaxHealth = Injectee.default.health;

    if (Injectee.Health < MaxHealth)
    {
        UseAmmo(1);
        Injectee.Health = MaxHealth;
        Injectee.PlaySound(Injectee.HitSound2, SLOT_Talk, 0.6);
    }
}
