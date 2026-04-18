class ZombieBotRepInfo expands RageBotRepInfo;

var byte InitialTeam;

replication
{
    reliable if (Role == ROLE_Authority)
        InitialTeam;
}
