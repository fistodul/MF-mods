//=============================================================================
// SeekerMines - Autonomous Seeker Mine Weapon
//=============================================================================
class SeekerMines extends TripBombs;

var int MaxActiveMines;

// Redirect primary fire to alt-fire (throw) so both buttons do the same thing.
function Fire(float Value)
{
    AltFire(Value);
}

simulated function bool ClientFire(float Value)
{
    return ClientAltFire(Value);
}

// Override Tick in AltFiring to release on EITHER fire button (base only checks bAltFire).
state AltFiring
{
    function Tick(float Delta)
    {
        ThrowPower += Delta * 5;
        if (ThrowPower > 10)
            ThrowPower = 10;

        if (Pawn(Owner).bAltFire == 0 && Pawn(Owner).bFire == 0 && EngineBot(Owner) == None)
        {
            if (ThrowPower < 3)
                ThrowPower += 3;
            LaunchBomb();
        }
    }
}

// Client-side mirror of AltFiring.Tick for the same dual-button release.
state ClientFirePowerUp
{
    simulated function Tick(float Delta)
    {
        ThrowPower += Delta * 5;
        if (ThrowPower > 10)
            ThrowPower = 10;

        if (Pawn(Owner).bAltFire == 0 && Pawn(Owner).bFire == 0)
            ClientThrowTripBomb();
    }
}

function int CountActiveMines()
{
    local Pawn P;
    local SeekerMine Mine;
    local int Count;

    for (P = Level.PawnList; P != None; P = P.NextPawn)
    {
        Mine = SeekerMine(P);
        if (Mine != None && Mine.Placer == Owner)
            Count++;
    }
    return Count;
}

// Launch a SeekerMineThrown instead of TripBombThrown, with higher base velocity.
function ThrowTripBomb()
{
    local vector X, Y, Z;

    if (CountActiveMines() >= MaxActiveMines)
    {
        Pawn(Owner).ClientMessage("Max active Seeker Mines reached: " $ MaxActiveMines);
        return;
    }

    UseAmmo(1);
    GetAxes(Pawn(Owner).ViewRotation, X, Y, Z);

    ProjectileSpeed = 800 + ThrowPower * 180;
    ProjectileFire(class'SeekerMineThrown', ProjectileSpeed, bAltWarnTarget);
    ClientThrowTripBomb();
}

// Always transition to Idle instead of calling Super.Finish().
// RageWeapon.Finish() calls Global.Fire(0) when bFire is held, which
// breaks for charge-and-throw weapons when called from state Active.
// Idle.Begin naturally handles both cases:
//   - Empty clip: SwitchToBestWeapon -> PutDown -> DownWeapon -> destroy/switch
//   - Loaded: if bFire held -> Fire -> AltFire -> AltFiring
function Finish()
{
    GotoState('Idle');
}

simulated function ClientFinish()
{
    if (!AmmoInClip())
    {
        if (PlayerPawn(Owner) != None)
            PlayerPawn(Owner).SwitchToBestWeapon();
        return;
    }

    Super.ClientFinish();
}

defaultproperties
{
     MaxActiveMines=3
     MaxClipAmmo=1
     PickupMessage="Loaded up Seeker Mines."
     ItemName="Seeker Mine"
}
