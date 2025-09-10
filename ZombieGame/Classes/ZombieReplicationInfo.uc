class ZombieReplicationInfo extends RageTeamReplicationInfo;

simulated function String GetGoalMessage(PlayerPawn Player)
{
    return GoalStrings[0];
}

defaultproperties
{
    HumanString="*Player*"
    GoalStrings(0)="Survive the attack of the undead or become one of them."
}
