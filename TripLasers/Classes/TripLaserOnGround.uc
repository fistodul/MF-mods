//=============================================================================
// TripLaserOnGround
//=============================================================================

class TripLaserOnGround extends TripBombOnGround;

var byte PlacedTeam; // Team frozen at placement time, immune to mid-game team changes

function bool GetPlacedTeam(Actor A, out byte OutTeam)
{
    local string S;

    if (A == None)
        return false;

    S = A.GetPropertyText("PlacedTeam");
    if (S != "")
    {
        OutTeam = byte(int(S));
        return true;
    }

    if (A.IsA('StationaryPawn'))
    {
        OutTeam = StationaryPawn(A).Team;
        return true;
    }

    return false;
}

function bool IsPawnFriendly(Pawn P)
{
    if (P == None || P.Health <= 0)
        return true;

    if (P.PlayerReplicationInfo != None)
    {
        if (Level.Game.bTeamGame)
            return P.PlayerReplicationInfo.Team == PlacedTeam;
        return P == Instigator;
    }

    return true;
}

// Returns true if Other is the placer, a confirmed teammate, or a non-empty vehicle with ONLY friendly occupants
function bool IsFriendly(Actor Other)
{
    local Vehicle V;
    local int i;
    local bool bFoundFriendly;
    local byte OtherTeam;

    if (Other == None || Other == Self)
        return true;

    // Check generic PlacedTeam / Team attribute (TripLaser, SeekerMine, SentryGunTurret, etc.)
    if (GetPlacedTeam(Other, OtherTeam))
    {
        if (Level.Game.bTeamGame)
            return OtherTeam == PlacedTeam;
        return Other.Instigator == Instigator;
    }

    V = Vehicle(Other);
    if (V != None)
    {
        bFoundFriendly = false;
        for (i = 0; i < V.NumSeats; i++)
        {
            if (V.aSeatsOccupant[i] != None)
            {
                if (!IsPawnFriendly(V.aSeatsOccupant[i]))
                    return false;
                bFoundFriendly = true;
            }
        }
        return bFoundFriendly;
    }

    if (Other.IsA('Pawn'))
        return IsPawnFriendly(Pawn(Other));

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
    local Pawn P;
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
        for (P = Level.PawnList; P != None; P = P.nextPawn)
        {
            Bot = EngineBot(P);
            if (Bot != None && !IsFriendly(P))
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
