class ZombieKnife extends RageKnife;

var int SlashDamage; // damage applied for melee slash

function AltFire( float Value )
{
    FireBeginTime = Level.TimeSeconds;
    if (bKnifeThrown != true && Pawn(owner) != None && Pawn(owner).CanFire())
    {
        ThrowPower = 9;
        GotoState('AltFiring');

        bPointing=True;
        bCanClientFire = true;
        ClientAltFire(Value);
    }
}

state AltFiring
{
    function Tick (float Delta)
    {
        // Charge up throwing power
        ThrowPower += Delta * 2;
        if (ThrowPower > 15)
            ThrowPower = 15;

        if (pawn(Owner).bAltFire == 0)
        {
            // Throw knife when button is released
            ThrowKnife ();
            Enable('AnimEnd');
            Disable('Tick');
            pawn(Owner).PlayAltFiring(); // Play the pawns altfiring animation now (knife throw)
        }
    }
}

function Slash()
{
    local vector HitLocation, HitNormal, EndTrace, X, Y, Z, Start;
    local actor Other;

    Owner.MakeNoise(Pawn(Owner).SoundDampening);
    GetAxes(Pawn(owner).ViewRotation, X, Y, Z);

    Start = Owner.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z;
    AdjustedAim = pawn(owner).AdjustAim(1000000, Start, AimError, False, False);
    EndTrace = Owner.Location + (Range * vector(AdjustedAim));
    Other = Pawn(Owner).TraceShot(HitLocation, HitNormal, EndTrace, Start);

    if ((Other == None) || (Other == Owner) || (Other == self))
        return;

    if (PlayerPawn(Owner) != None)
        PlayerPawn(Owner).ShakeView(ShakeTime, ShakeMag, ShakeVert);

    Other.TakeDamage(SlashDamage, Pawn(Owner), HitLocation, 40000 * X + 24000 * Z, MyDamageType);
    LastHit = None;
}

function ThrowKnife ()
{
    local vector X, Y, Z;
    local ZombieKnife_Thrown TKnife; // Thrown knife kept track of so it can be collected

    GetAxes(Pawn(Owner).ViewRotation, X, Y, Z);
    ProjectileSpeed = ThrowPower * 150;

    TKnife = ZombieKnife_Thrown(ProjectileFire(ProjectileClass, ProjectileSpeed, bAltWarnTarget));
    TKnife.OwnerKnife = self;

    ClientThrowKnife();
}

defaultproperties
{
    SlashDamage=75
    Range=100
    ProjectileClass=Class'ZombieKnife_Thrown'
}
