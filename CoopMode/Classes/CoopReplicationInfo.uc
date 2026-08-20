class CoopReplicationInfo extends RageCTFReplicationInfo;

var byte weapons;

replication
{
    reliable if (Role == ROLE_Authority)
        weapons;
}

defaultproperties
{
}
