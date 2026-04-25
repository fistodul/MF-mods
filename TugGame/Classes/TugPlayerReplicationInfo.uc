class TugPlayerReplicationInfo extends PlayerReplicationInfo;

var byte InitialTeam;

replication
{
    reliable if (Role == ROLE_Authority)
        InitialTeam;
}

defaultproperties
{
    InitialTeam=255
}
