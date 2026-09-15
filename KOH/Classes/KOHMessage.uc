class KOHMessage extends RageMessageCriticalEvent;

var localized string PointNames[6];
var localized string SwitchedMsg;
var localized string BlueTeamMsg;
var localized string RedTeamMsg;

var sound CapturedSound[2];

static function string GetString(
    optional int Switch,
    optional PlayerReplicationInfo RelatedPRI_1,
    optional PlayerReplicationInfo RelatedPRI_2,
    optional Object OptionalObject
) {
    local string PName;
    local KOHTimer aTimer;
    aTimer = KOHTimer(OptionalObject);

    if (aTimer != None && aTimer.PointIndex >= 0 && aTimer.PointIndex < 6)
        PName = Default.PointNames[aTimer.PointIndex];
    else if (Switch >= 0 && Switch < 6)
        PName = Default.PointNames[Switch];
    else
        PName = "Point";

    if (RelatedPRI_1 != None)
    {
        if (RelatedPRI_1.Team == 1)
            return RelatedPRI_1.PlayerName @ Default.SwitchedMsg @ PName @ "for" @ Default.RedTeamMsg;
        else
            return RelatedPRI_1.PlayerName @ Default.SwitchedMsg @ PName @ "for" @ Default.BlueTeamMsg;
    }

    return "";
}

static simulated function ClientReceive(
    PlayerPawn P,
    optional int Switch,
    optional PlayerReplicationInfo RelatedPRI_1,
    optional PlayerReplicationInfo RelatedPRI_2,
    optional Object OptionalObject
) {
    local Sound SoundToPlay;
    local Actor SoundPlayer;

    Super.ClientReceive(P, Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject);

    if (RelatedPRI_1 == None)
        return;

    if (RelatedPRI_1.Team == 1)
        SoundToPlay = Default.CapturedSound[1];
    else
        SoundToPlay = Default.CapturedSound[0];

    if (SoundToPlay == None)
        return;

    if (P.ViewTarget != None)
        SoundPlayer = P.ViewTarget;
    else
        SoundPlayer = P;

    if (RPlayer(P) == None || RPlayer(P).AnnouncerVolume == 0)
        return;

    SoundPlayer.PlaySound(SoundToPlay, SLOT_None, 16.0, true);
    if (RPlayer(P).AnnouncerVolume == 1)
        return;
    SoundPlayer.PlaySound(SoundToPlay, SLOT_Interface, 16.0, true);
    if (RPlayer(P).AnnouncerVolume == 2)
        return;
    SoundPlayer.PlaySound(SoundToPlay, SLOT_Misc, 16.0, true);
    if (RPlayer(P).AnnouncerVolume == 3)
        return;
    SoundPlayer.PlaySound(SoundToPlay, SLOT_Talk, 16.0, true);
}

defaultproperties
{
     PointNames(0)="Point A"
     PointNames(1)="Point B"
     PointNames(2)="Point C"
     PointNames(3)="Point D"
     PointNames(4)="Point E"
     PointNames(5)="Point F"
     SwitchedMsg="captured"
     BlueTeamMsg="Blue Team"
     RedTeamMsg="Red Team"
     CapturedSound(0)=Sound'Announcer.Blue_switches'
     CapturedSound(1)=Sound'Announcer.Red_switches'
}
