class ZombieKnife extends RageKnife;

var int SlashDamage; // damage applied for melee slash

function AltFire(float Value)
{
    FireBeginTime = Level.TimeSeconds;
    if (bKnifeThrown != true && Pawn(owner) != None && Pawn(owner).CanFire())
    {
        ThrowPower = 0; // start at 0; minimum is enforced at throw time by the speed formula
        GotoState('AltFiring');

        bPointing = true;
        bCanClientFire = true;
        ClientAltFire(Value);
    }
}

state AltFiring
{
    function BeginState()
    {
        local float EnemyDist;

        Disable('AnimEnd'); // prevent ThrowUpCatch wind-up ending early and calling Finish()
        Disable('Tick');    // re-enabled by inherited Begin: after FinishAnim() completes

        if (Pawn(Owner).IsA('Bot') || Pawn(Owner).IsA('RBot'))
        {
            if (Pawn(Owner).Enemy != None)
            {
                EnemyDist = VSize(Pawn(Owner).Enemy.Location - Owner.Location);
                ThrowPower = FClamp(EnemyDist / 75.0, 3.0, 10.0);
            }
            else
                ThrowPower = 7.0;

            ThrowKnife();
            Pawn(Owner).bAltFire = 0;
            Pawn(Owner).PlayAltFiring();
            Enable('AnimEnd');
        }
    }

    function Tick(float Delta)
    {
        ThrowPower += Delta * 8; // 0->10 in ~1.25s
        if (ThrowPower > 10)
            ThrowPower = 10;

        if (Pawn(Owner).bAltFire == 0)
        {
            ThrowKnife(); // speed formula handles any ThrowPower >= 0 gracefully
            Enable('AnimEnd');
            Disable('Tick');
            Pawn(Owner).PlayAltFiring();
        }
    }

    function AnimEnd()
    {
        Finish();
        Disable('AnimEnd');
    }
}

simulated function PostRender(canvas Canvas)
{
    Super.PostRender(Canvas);

    if (Pawn(Owner) != None && Pawn(Owner).bAltFire != 0 && !bKnifeThrown) // only while charging
        DrawPowerGuage(Canvas, int(ThrowPower));
}

function float RateSelf(out int bUseAltMode)
{
    local Pawn P;
    local float EnemyDist;
    local bool bEnemyInVehicle;

    if (bKnifeThrown)
        return -2.0;

    P = Pawn(Owner);
    bEnemyInVehicle = (P.Enemy.VehicleIn != None || P.Enemy.IsA('Vehicle'));

    if (bEnemyInVehicle) // throw knife to blow up vehicle
    {
        EnemyDist = VSize(P.Enemy.Location - P.Location);
        if (EnemyDist >= 100 && EnemyDist <= 1800)
        {
            bUseAltMode = 1;
            return 2.0;
        }

        return -1.0;
    }

    return Super.RateSelf(bUseAltMode);
}

function Slash()
{
    local vector HitLocation, HitNormal, EndTrace, X, Y, Z, Start;
    local actor Other;
    local int ActualDamage;
    local ZombiePlayer ZP;
    local ZombieBotBase ZB;

    Owner.MakeNoise(Pawn(Owner).SoundDampening);
    GetAxes(Pawn(owner).ViewRotation, X, Y, Z);

    Start = Owner.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z;
    AdjustedAim = pawn(owner).AdjustAim(1000000, Start, AimError, False, False);
    EndTrace = Owner.Location + (Range * vector(AdjustedAim));
    Other = Pawn(Owner).TraceShot(HitLocation, HitNormal, EndTrace, Start);

    if (Other == None || Other == Owner || Other == self)
        return;

    if (PlayerPawn(Owner) != None)
        PlayerPawn(Owner).ShakeView(ShakeTime, ShakeMag, ShakeVert);

    ZP = ZombiePlayer(Owner);
    ZB = ZombieBotBase(Owner);

    if (ZP != None && ZP.bIsNemesis || ZB != None && ZB.bIsNemesis)
        ActualDamage = SlashDamage * 2;
    else
        ActualDamage = SlashDamage;

    Other.TakeDamage(ActualDamage, Pawn(Owner), HitLocation, 38000 * X + 24000 * Z, MyDamageType);
    LastHit = None;
}

function ThrowKnife()
{
    local vector X, Y, Z;
    local ZombieKnife_Thrown TKnife; // kept track of so it can be collected

    GetAxes(Pawn(Owner).ViewRotation, X, Y, Z);
    ProjectileSpeed = 1000.0 + (FClamp(ThrowPower, 0.0, 10.0) * FClamp(ThrowPower, 0.0, 10.0)) * 15.0; // 1000 (tap) -> 2500 (full charge)

    TKnife = ZombieKnife_Thrown(ProjectileFire(ProjectileClass, ProjectileSpeed, bAltWarnTarget));
    TKnife.OwnerKnife = self;

    ClientThrowKnife();
}

defaultproperties
{
     SlashDamage=67
     Range=100.000000
     ProjectileClass=Class'ZombieGame.ZombieKnife_Thrown'
}
