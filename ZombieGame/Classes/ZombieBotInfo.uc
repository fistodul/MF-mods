class ZombieBotInfo extends RageBotInfo;

function RageSetupBot(RageBot NewBot)
{
    Super.RageSetupBot(NewBot);
    //if (NewBot.PlayerReplicationInfo.Team == 1)
    NewBot.FavoriteWeapon = Class'ZombieKnife';
}

defaultproperties
{
     aAvailableBots(0)=Class'ZombieGame.ZombieBot0'
     aAvailableBots(1)=Class'ZombieGame.ZombieBot1'
     aAvailableBots(2)=Class'ZombieGame.ZombieBot2'
     aAvailableBots(3)=Class'ZombieGame.ZombieBot3'
     aAvailableBots(4)=Class'ZombieGame.ZombieBot4'
     aAvailableBots(5)=Class'ZombieGame.ZombieBot5'
     aAvailableBots(6)=Class'ZombieGame.ZombieBot6'
     aAvailableBots(7)=Class'ZombieGame.ZombieBot7'
     aAvailableBots(8)=Class'ZombieGame.ZombieBot8'
     aAvailableBots(9)=Class'ZombieGame.ZombieBot9'
     aAvailableBots(10)=Class'ZombieGame.ZombieBot10'
     aAvailableBots(11)=Class'ZombieGame.ZombieBot11'
     aAvailableBots(12)=Class'ZombieGame.ZombieBot12'
     aAvailableBots(13)=Class'ZombieGame.ZombieBot13'
     aAvailableBots(14)=Class'ZombieGame.ZombieBot14'
     aAvailableBots(15)=Class'ZombieGame.ZombieBot15'
     aAvailableBots(16)=Class'ZombieGame.ZombieBot16'
     aAvailableBots(17)=Class'ZombieGame.ZombieBot17'
     aAvailableBots(18)=Class'ZombieGame.ZombieBot18'
     aAvailableBots(19)=Class'ZombieGame.ZombieBot19'
     aAvailableBots(20)=Class'ZombieGame.ZombieBot20'
     aAvailableBots(21)=Class'ZombieGame.ZombieBot21'
     aAvailableBots(22)=Class'ZombieGame.ZombieBot22'
     aAvailableBots(23)=Class'ZombieGame.ZombieBot23'
     aAvailableBots(24)=Class'ZombieGame.ZombieBot24'
     aAvailableBots(25)=Class'ZombieGame.ZombieBot25'
     aAvailableBots(26)=Class'ZombieGame.ZombieBot26'
     aAvailableBots(27)=Class'ZombieGame.ZombieBot27'
     aAvailableBots(28)=Class'ZombieGame.ZombieBot28'
     aAvailableBots(29)=Class'ZombieGame.ZombieBot29'
     aAvailableBots(30)=Class'ZombieGame.ZombieBot30'
     aAvailableBots(31)=Class'ZombieGame.ZombieBot31'
}
