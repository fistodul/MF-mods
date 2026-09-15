class KOHTimer extends NavigationPoint;

var byte Team;              // 255 = Neutral, 0 = Blue, 1 = Red
var int PointIndex;         // 0 to 5 (Point A, B, C, D, E, F)
var string PointName;       // "Point A", "Point B", etc.
var float TeamTimes[2];     // Accumulation time for each team, in seconds
var byte LightHue0;
var byte LightHue1;
var Mesh TeamMesh[3];

replication
{
    reliable if (Role == ROLE_Authority)
        Team, PointIndex, PointName, TeamTimes;
}

function PostBeginPlay()
{
    Super.PostBeginPlay();

    LightType = LT_None;
    Mesh = TeamMesh[2];

    if (Level.MiniMap != None)
    {
        MinimapInfo(Level.MiniMap).TrackItem(Self, PointName, 'TimerNeutral', 0);
        MinimapInfo(Level.MiniMap).TrackItem(Self, PointName, 'TimerNeutral', 1);
    }
}

function name GetTimerTrackType(byte InTeam)
{
    if (InTeam == 0)
        return 'TimerBlue';
    else if (InTeam == 1)
        return 'TimerRed';

    return 'TimerNeutral';
}

function Touch(Actor Other)
{
    local Pawn aPawn;

    aPawn = Pawn(Other);
    if (aPawn != None &&
        aPawn.bIsPlayer &&
        (aPawn.Health > 0) &&
        !aPawn.IsInState('FeigningDeath') &&
        Level.Game.IsA('KOHGame'))
    {
        if (aPawn.PlayerReplicationInfo.Team != Team)
        {
            // Remove previous minimap tracking
            if (Level.MiniMap != None)
            {
                MinimapInfo(Level.MiniMap).StopTrackingItem(Self, 0, GetTimerTrackType(Team));
                MinimapInfo(Level.MiniMap).StopTrackingItem(Self, 1, GetTimerTrackType(Team));
            }

            // Switch to capturing player's team
            Team = aPawn.PlayerReplicationInfo.Team;

            // Notify gametype for scoring and messages
            KOHGame(Level.Game).ScoreTimer(aPawn, Self);

            // Update lighting and 3D device mesh
            LightType = LT_Steady;
            if (Team == 0)
            {
                LightHue = LightHue0;
                Mesh = TeamMesh[0];
            }
            else if (Team == 1)
            {
                LightHue = LightHue1;
                Mesh = TeamMesh[1];
            }

            // Update minimap with newly captured status
            if (Level.MiniMap != None)
            {
                MinimapInfo(Level.MiniMap).TrackItem(Self, PointName, GetTimerTrackType(Team), 0);
                MinimapInfo(Level.MiniMap).TrackItem(Self, PointName, GetTimerTrackType(Team), 1);
            }
        }
    }
}

defaultproperties
{
     Team=255
     PointIndex=0
     PointName="Point A"
     LightHue0=170
     LightHue1=0
     TeamMesh(0)=DeviceMesh'RageGame.RageDomTimerBlueMesh'
     TeamMesh(1)=DeviceMesh'RageGame.RageDomTimerRedMesh'
     TeamMesh(2)=DeviceMesh'RageGame.RageDomTimerMesh'
     CarParkImportance=32
     bStatic=False
     bHidden=False
     bNoDelete=False
     bAlwaysRelevant=True
     CondGameType=Class'KOH.KOHGame'
     DrawType=DT_DeviceMesh
     Mesh=DeviceMesh'RageGame.RageDomTimerMesh'
     SoundRadius=255
     SoundVolume=255
     CollisionRadius=60.000000
     CollisionHeight=60.000000
     bCollideActors=True
     LightType=LT_Steady
     LightEffect=LE_Interference
     LightBrightness=255
     LightHue=170
     LightRadius=10
     NetUpdateFrequency=4.000000
}
