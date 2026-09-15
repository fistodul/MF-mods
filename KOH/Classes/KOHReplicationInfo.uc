class KOHReplicationInfo extends RageGameRepInfo;

var KOHTimer TimerList[6];
var byte TimerTeams[6];
var int NumTimers;

replication
{
    reliable if (Role == ROLE_Authority)
        TimerList, TimerTeams, NumTimers;
}

defaultproperties
{
     NumTimers=3
     TimerTeams(0)=255
     TimerTeams(1)=255
     TimerTeams(2)=255
     TimerTeams(3)=255
     TimerTeams(4)=255
     TimerTeams(5)=255
     GoalStrings(0)="Capture and hold Points to reach %k Points to Win"
     GoalStrings(1)="Hold most Points for %o to Win"
     GoalStrings(2)="Capture and hold Points to reach %k Points in %o to Win"
}
