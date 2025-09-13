class ZombieReplicationInfo extends RageTeamReplicationInfo;

var bool bZombieInfect;

simulated function String GetGoalMessage(PlayerPawn Player)
{
    if (bZombieInfect)
        return GoalStrings[1] $ FragLimit $ " times!";
    else
        return GoalStrings[0] $ FragLimit $ " times!";
}

defaultproperties
{
    bZombieInfect=true
    HumanString="*Player*"
    GoalStrings(0)="Survive the attack of the undead "
    GoalStrings(1)="Survive the attack of the undead or become one of them "
}
