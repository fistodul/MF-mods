class ZombieKnife_Thrown extends Knife_Thrown;

auto state Dangerous
{
    simulated function ProcessTouch(actor Other, vector HitLocation)
    {
        local int ActualDamage;
        local ZombiePlayer ZP;
        local ZombieBotBase ZB;

        if (other == None)
        {
            Bounce(Normal(Location-HitLocation), None); // Treat as a wall
            return;
        }

        if (bCanHitOwner == true || other != OwnerKnife.Owner)
        {
            ZP = ZombiePlayer(OwnerKnife.Owner);
            ZB = ZombieBotBase(OwnerKnife.Owner);

            if (ZP != None && ZP.bIsNemesis || ZB != None && ZB.bIsNemesis)
                ActualDamage = Damage * 2;
            else
                ActualDamage = Damage;

            // damage actor and stick in him
            if (Other.bIsPawn && Pawn(Other).bIsPlayer && !Other.IsA('EnginePhysical') && (HitLocation.Z - Other.Location.Z > 0.80 * Other.CollisionHeight)
                && (instigator.IsA('PlayerPawn') || (instigator.IsA('EngineBot') && !EngineBot(Instigator).bNovice)))
            {
                Other.TakeDamage (ActualDamage * 3, Instigator, HitLocation, Location * 0, 'decapitated');
            }
            else
                Other.TakeDamage(ActualDamage, Pawn(OwnerKnife.Owner), HitLocation,  Location * 0, MyDamageType );

            Velocity = Velocity * 0;
            GotoState('Safe');
        }
    }
}

defaultproperties
{
     TimeBeforeReturn=4.500000
     speed=1000.000000
     MaxSpeed=2250.000000
     Damage=158.000000
     MyDamageType=RageWeaponsDOTRocketLauncher
}
