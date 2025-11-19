class ZombiePlayerReplicationInfo expands PlayerReplicationInfo;

var int DefaultHealth;

replication
{
    reliable if (Role == ROLE_Authority)
        DefaultHealth;
}
