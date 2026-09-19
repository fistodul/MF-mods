//=============================================================================
// SeekerMineThrown - Thrown 2x Scaled Seeker Mine Projectile
//=============================================================================
class SeekerMineThrown extends TripBombThrown;

var bool bDeployed;

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    SetTimer(0.5, false);
}

function Timer()
{
    DeployMine();
}

simulated function DeployMine()
{
    local SeekerMine Mine;

    if (bDeployed)
        return;

    bDeployed = true;

    if (Role == ROLE_Authority)
    {
        Mine = Spawn(class'SeekerMine', Instigator,, Location, Rotation);
        if (Mine != None)
        {
            Mine.InitPlacer(Instigator);
            Mine.Velocity = Velocity * 0.4;
        }
    }

    Destroy();
}

simulated function HitWall(vector HitNormal, actor Wall)
{
    if (Wall.IsA('LoadoutBlocker'))
        Destroy();
    else
        DeployMine();
}

simulated function Landed(vector HitNormal)
{
    DeployMine();
}

defaultproperties
{
     speed=1200.000000
     MaxSpeed=3000.000000
     DrawScale=2.000000
     CollisionRadius=16.000000
     CollisionHeight=16.000000
}
