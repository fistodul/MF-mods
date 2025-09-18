class ZombieKnife_Thrown extends Knife_Thrown;

auto state Dangerous
{
    simulated function ProcessTouch(actor Other, vector HitLocation)
    {
        if (other != None)
        {
            if (bCanHitOwner == true || other != OwnerKnife.Owner)
            {
                // damage actor and stick in him            
                if (Other.bIsPawn && Pawn(Other).bIsPlayer && !Other.IsA('EnginePhysical') && (HitLocation.Z - Other.Location.Z > 0.80 * Other.CollisionHeight) 
                    && (instigator.IsA('PlayerPawn') || (instigator.IsA('EngineBot') && !EngineBot(Instigator).bNovice)))
                {
                    Other.TakeDamage (Damage * 3, Instigator, HitLocation, Location * 0, 'decapitated');
                }
                else
                {
                    //DamageAmount = Damage * Speed / MaxSpeed;
                    Other.TakeDamage(Damage, Pawn(OwnerKnife.Owner), HitLocation,  Location * 0, MyDamageType );
                }

                Velocity = Velocity * 0;
                GotoState('Safe');
            }
        }
        else
        {
            // Treat as a wall
            Bounce(Normal(Location-HitLocation), none);
        }
    }
}

defaultproperties
{
    Damage=158
    MaxSpeed=2250
    speed=1000
    TimeBeforeReturn=4.5
    MyDamageType=RageWeaponsDOTRocketLauncher
}
