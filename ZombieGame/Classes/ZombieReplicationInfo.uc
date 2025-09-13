class ZombieReplicationInfo extends RageTeamReplicationInfo;

var bool bZombieInfect;

simulated function String GetGoalMessage(PlayerPawn Player)
{
    local String EnemyTeamName;
    
    if (bZombieInfect && FragLimit > 0)
        return GoalStrings[1] $ FragLimit $ " times!";

    if (Player.PlayerReplicationInfo.Team == 1)
		EnemyTeamName = Class'ZombieScoreBoard'.Default.TeamName[0];
	else
		EnemyTeamName = Class'ZombieScoreBoard'.Default.TeamName[1];

    return "Kill " $ FragLimit $ " " $ EnemyTeamName $ " " $ "in " $ TimeLimit $ " minutes to Win!";
}

defaultproperties
{
    bZombieInfect=true
    HumanString="*Player*"
    GoalStrings(1)="Survive the attack of the undead or become one of them "
}
