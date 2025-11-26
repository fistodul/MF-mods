class ZombieBotRepInfo expands RageBotRepInfo;

var int DefaultHealth;

replication
{
    reliable if (Role == ROLE_Authority)
        DefaultHealth;
}
