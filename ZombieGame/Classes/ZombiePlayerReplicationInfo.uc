class ZombiePlayerReplicationInfo extends PlayerReplicationInfo;

var byte InitialTeam;

replication
{
    reliable if (Role == ROLE_Authority)
        InitialTeam;
}
