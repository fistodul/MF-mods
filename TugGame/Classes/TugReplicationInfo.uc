class TugReplicationInfo extends RageTeamReplicationInfo;

simulated function String GetGoalMessage(PlayerPawn Player)
{
    return GoalStrings[0];
}

defaultproperties
{
    GoalStrings(0)="Convert each player to your team!"
}
