class ZombieKnife_Thrown extends Knife_Thrown;

auto state Dangerous
{
    simulated function ProcessTouch(actor Other, vector HitLocation)
    {
        if (other == None)
        {
            Bounce(Normal(Location-HitLocation), None); // Treat as a wall
            return;
        }

        if (bCanHitOwner == true || other != OwnerKnife.Owner)
        {
            // damage actor and stick in him
            if (Other.bIsPawn && Pawn(Other).bIsPlayer && !Other.IsA('EnginePhysical') && (HitLocation.Z - Other.Location.Z > 0.80 * Other.CollisionHeight)
                && (instigator.IsA('PlayerPawn') || (instigator.IsA('EngineBot') && !EngineBot(Instigator).bNovice)))
            {
                Other.TakeDamage (Damage * 3, Instigator, HitLocation, Location * 0, 'decapitated');
            }
            else
                Other.TakeDamage(Damage, Pawn(OwnerKnife.Owner), HitLocation,  Location * 0, MyDamageType );

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
