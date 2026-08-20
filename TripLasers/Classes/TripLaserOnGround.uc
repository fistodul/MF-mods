//=============================================================================
// TripLaserOnGround
//=============================================================================

class TripLaserOnGround extends TripBombOnGround;

//=============================================================================

var byte PlacedTeam; // Team frozen at placement time, immune to mid-game team changes

// Returns true if Other is the placer, a confirmed teammate, or a non-empty vehicle with ONLY friendly occupants
function bool IsFriendly(Actor Other)
{
    local Pawn P;
    local Vehicle V;
    local int i;
    local bool bFoundFriendly;

    if (Other == None)
        return false;

    // Ignore other trip lasers so they don't trigger each other
    if (Other.IsA('TripLaser') || Other.IsA('TripLaserOnGround') || Other.IsA('TripLaserThrown'))
        return true;

    V = Vehicle(Other);
    if (V != None)
    {
        bFoundFriendly = false;
        for (i = 0; i < V.NumSeats; i++)
        {
            if (V.aSeatsOccupant[i] != None)
            {
                if (Level.Game.bTeamGame)
                {
                    if (V.aSeatsOccupant[i].PlayerReplicationInfo.Team != PlacedTeam)
                        return false;
                    bFoundFriendly = true;
                }
                else
                {
                    if (V.aSeatsOccupant[i] != Instigator)
                        return false;
                    bFoundFriendly = true;
                }
            }
        }

        return bFoundFriendly;
    }

    P = Pawn(Other);
    if (P != None)
    {
        if (Level.Game.bTeamGame)
            return P.PlayerReplicationInfo.Team == PlacedTeam;
        else
            return P == Instigator;
    }

    return false;
}

simulated function Touch(actor Other)
{
    if (!Other.IsA('LevelInfo') && !Other.bWorldGeometry && Pawn(Other) != None && !IsFriendly(Other))
    {
        Other.TakeDamage(280, Instigator, Location, vect(0, 0, 0), 'RageWeaponsDOTTripBombs');
        Destroy();
    }
}

event TakeDamage(int Damage, Pawn InstigatedBy, Vector HitLocation, Vector Momentum, name damageType)
{
    Destroy();
}

function PostBeginPlay()
{
    PlacedTeam = Instigator.PlayerReplicationInfo.Team;
    Super.PostBeginPlay();
}

simulated function Tick(float Delta)
{
    local EnginePhysical Veh, XNextPhysic;
    local Pawn P, XNextPawn;
    local vector Dif;
    local float Dist, MaxDist;
    local EngineBot Bot;

    MaxDist = CollisionRadius * 1.5;
    // Damage vehicle with enemies
    for (Veh = Level.VehicleList; Veh != None; Veh = XNextPhysic)
    {
        XNextPhysic = Veh.NextPhysical;

        Dif = Location-Veh.Location;
        Dist = VSize(Dif);
        if (Dist < MaxDist && !IsFriendly(Veh))
        {
            Veh.TakeDamage(280, Instigator, Location, vect(0, 0, 0), 'RageWeaponsDOTTripBombs');
            Destroy();
            return;
        }
    }

    // Tell bots to fear mines
    MaxDist = CollisionRadius * 2.5;
    BotFearC -= Delta;
    if (BotFearC <= 0)
    {
        BotFearC = 2.25;
        for (P = Level.PawnList; P != None; P = XNextPawn)
        {
            XNextPawn = P.nextPawn;
            Bot = EngineBot(P);
            if (Bot != None)
            {
                Dif = Location - Bot.Location;
                Dist = VSize(Dif);
                if (Dist < MaxDist && (!Bot.bNovice || FRand() < (0.3 * Bot.Skill)))
                    Bot.FearThisSpot(self);
            }
        }
    }
}

defaultproperties
{
}
