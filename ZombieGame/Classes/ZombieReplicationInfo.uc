class ZombieReplicationInfo extends RageTeamReplicationInfo;

var bool bZombieInfect;
var bool bKillTransform;
var byte zombieWeapons;

replication
{
    reliable if (Role == ROLE_Authority)
        bZombieInfect, bKillTransform, zombieWeapons;
}

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
    HumanString="*Player*"
    GoalStrings(1)="Survive the attack of the undead or become one of them "
}
