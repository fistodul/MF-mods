class TugHUD extends RageTeamHUD;

simulated function DrawGameSpecificStuff(canvas Canvas)
{
    local float sX, sY;
    local int CurTime;
    local int Minutes;
    local int Seconds;
    local string Countdown;

    // First let super draw team scores / game object icon
    Super.DrawGameSpecificStuff(Canvas);

    // align X with the right-most team back
    sX = Canvas.ClipX - (TeamBack.W * RenderScale) - BlockSize;

    // place the timer just above the team back area
    sY = Canvas.ClipY - (TeamBack.H * RenderScale) - (BlockSize * 0.75);

    // compute time string
    CurTime = PlayerOwner.GameReplicationInfo.RemainingTime;
    Minutes = CurTime / 60;
    Seconds = CurTime - (Minutes * 60);

    if (Seconds < 10)
        Countdown = Minutes $ ":0" $ Seconds;
    else
        Countdown = Minutes $ ":" $ Seconds;

    // Draw the timer AFTER the super so it appears on top
    DrawScoreBar(Canvas, sX, sY, BlockSize * 2, BlockSize * 0.5, 2, 2, Countdown, 0, false);
}

defaultproperties
{
    ScoreIcons(2)=(X=128,Y=128,W=64,H=64,t=Texture'Rage.ScoreIcons')
}
