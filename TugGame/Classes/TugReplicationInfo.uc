class TugReplicationInfo extends RageTeamReplicationInfo;

var bool bKillTransform;

simulated function String GetGoalMessage(PlayerPawn Player)
{
    return GoalStrings[0] $ FragLimit $ " times!";
}

defaultproperties
{
    GoalStrings(0)="Convert each player to your team "
}
