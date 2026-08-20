//=============================================================================
// CoopMode by Animeman for Akvari - 2026
//=============================================================================
class CoopMode extends RageCTF;

var config int weapons;

simulated function PreBeginPlay()
{
    Super.PreBeginPlay();
    MinPlayers = 100;
    CoopReplicationInfo(GameReplicationInfo).weapons = weapons;
}

event PlayerPawn Login
(
    string Portal,
    string Options,
    out string Error,
    class<PlayerPawn> SpawnClass
) {
    local PlayerPawn P;
    P = Super.Login(Portal, Options, Error, Class'CoopPlayer');

    if (P != None)
    {
        if (SpawnClass != None)
        {
            P.TeamSkin0 = SpawnClass.default.TeamSkin0;
            P.TeamSkin1 = SpawnClass.default.TeamSkin1;
            P.TeamSkin2 = SpawnClass.default.TeamSkin2;
            P.TeamSkin3 = SpawnClass.default.TeamSkin3;
            P.TeamSkinCaptain = SpawnClass.default.TeamSkinCaptain;
            P.TeamSkinName = SpawnClass.default.TeamSkinName;
            P.TeamMeshName = SpawnClass.default.TeamMeshName;
            P.MenuName = SpawnClass.default.MenuName;
            P.Mesh = SpawnClass.default.Mesh;
        }

        if (P.PlayerReplicationInfo != None)
            P.static.SetMultiSkin(P, P.TeamSkinName, P.PlayerReplicationInfo.Team);
        else
            P.static.SetMultiSkin(P, P.TeamSkinName, 0);
    }

    return P;
}

defaultproperties
{
     weapons=3
     FragLimit=3
     TimeLimit=0
     DefaultPlayerClass=Class'CoopMode.CoopPlayer'
     MapPrefix="COOP-"
     BeaconName="COOP"
     GameName="Coop mode"
     GameReplicationInfoClass=Class'CoopMode.CoopReplicationInfo'
}
