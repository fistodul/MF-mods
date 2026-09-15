class KOHHUD extends RageTeamHUD;

var TexRect TimerIcon_Team[3];
var string PointLetters[6];
var color BarBackColor;

simulated function DrawGameSpecificStuff(canvas Canvas)
{
    Super(RageHUD).DrawGameSpecificStuff(Canvas);

    if (
        (PlayerOwner == None) || (RagePlayerOwner == None) || (PlayerOwner.GameReplicationInfo == None) ||
        (RagePlayerOwner.PlayerReplicationInfo == None) ||
        ((PlayerOwner.bShowMenu || PlayerOwner.bShowScores) && (Canvas.ClipX < 640))
    )
        return;

    DrawKOHHUD(Canvas);
}

simulated function DrawKOHScoreBar(Canvas Canvas, float X, float Y, float W, float H, byte Box, String Text, float ScoreLevel, bool bPulse)
{
    local float XL, YL;
    local color TeamCol;

    if (Box < 2)
        TeamCol = Colour_Sets[Box];
    else
        TeamCol = WhiteColor;

    // 1. Dark translucent background panel
    Canvas.Style = ERenderStyle.STY_Translucent;
    Canvas.DrawColor = BarBackColor;
    Canvas.SetPos(X, Y);
    Canvas.DrawTile(Texture'Engine.WhiteTexture', W, H, 0, 0, 1, 1);

    // 2. Filled progress bar (pure team color)
    if (ScoreLevel > 0.0)
    {
        if (ScoreLevel > 1.0)
            ScoreLevel = 1.0;

        Canvas.Style = ERenderStyle.STY_Translucent;
        Canvas.DrawColor = TeamCol;
        Canvas.DrawColor.A = 190;
        Canvas.SetPos(X, Y);
        Canvas.DrawTile(Texture'Engine.WhiteTexture', W * ScoreLevel, H, 0, 0, 1, 1);
    }

    // 3. Crisp border outline
    Canvas.Style = ERenderStyle.STY_Translucent;
    Canvas.DrawColor = TeamCol;
    Canvas.DrawColor.A = 220;
    // Top & Bottom border
    Canvas.SetPos(X, Y);
    Canvas.DrawTile(Texture'Engine.WhiteTexture', W, 1, 0, 0, 1, 1);
    Canvas.SetPos(X, Y + H - 1);
    Canvas.DrawTile(Texture'Engine.WhiteTexture', W, 1, 0, 0, 1, 1);
    // Left & Right border
    Canvas.SetPos(X, Y);
    Canvas.DrawTile(Texture'Engine.WhiteTexture', 1, H, 0, 0, 1, 1);
    Canvas.SetPos(X + W - 1, Y);
    Canvas.DrawTile(Texture'Engine.WhiteTexture', 1, H, 0, 0, 1, 1);

    // 4. Centered score or time text
    Canvas.Style = ERenderStyle.STY_Translucent;
    if (bPulse)
    {
        if (MiscAnimCounter <= 0.5)
            Canvas.DrawColor = UnitColor * ((1.0 - MiscAnimCounter) * 255);
        else
            Canvas.DrawColor = UnitColor * (MiscAnimCounter * 255);
    }
    else
        Canvas.DrawColor = WhiteColor;

    Canvas.Font = MyFonts.GetHUDMedFont(HUDSize);
    Canvas.StrLen(Text, XL, YL);
    Canvas.SetPos(X + ((W - XL) * 0.5), Y + ((H - YL) * 0.5));
    Canvas.DrawText(Text, false);
}

simulated function DrawKOHHUD(canvas Canvas)
{
    local KOHReplicationInfo GRI;
    local float ColX, BarW, BarH, BarX, sY, IconSize, BottomY, IconY, XL, YL;
    local int j, k, CurTime, Minutes, Seconds, TeamOwnedPoints, TargetScore;
    local float ScoreRatio;
    local string ScoreString, TimeString, Letter;
    local byte PointOwner, IconIdx;
    local bool bTeamScoring;

    GRI = KOHReplicationInfo(PlayerOwner.GameReplicationInfo);
    if (GRI == None)
        return;

    TargetScore = Max(GRI.GoalTeamScore, 1);

    // Geometry layout:
    // Right margin column for stacked capture point indicators
    ColX = Canvas.ClipX - (BlockSize * 0.85);
    BarW = BlockSize * 2.0;
    BarH = BlockSize * 0.5;
    BarX = ColX - BarW - (BlockSize * 0.2);
    sY = Canvas.ClipY - (BlockSize * 0.75);

    // 1. Draw Team Score Bars (Blue = Team 0, Red = Team 1)
    for (j = 0; j < 2; j++)
    {
        if (GRI.Teams[j] != None)
        {
            TeamOwnedPoints = 0;
            for (k = 0; k < GRI.NumTimers; k++)
            {
                if (GRI.TimerTeams[k] == GRI.Teams[j].TeamIndex)
                    TeamOwnedPoints++;
            }

            bTeamScoring = (TeamOwnedPoints > 0);
            ScoreRatio = GRI.Teams[j].Score / float(TargetScore);
            ScoreString = string(int(GRI.Teams[j].Score)) $ " / " $ string(GRI.GoalTeamScore);

            DrawKOHScoreBar(Canvas, BarX, sY, BarW, BarH, GRI.Teams[j].TeamIndex, ScoreString, ScoreRatio, bTeamScoring);
            sY -= BlockSize * 0.75;
        }
    }

    // 2. Draw Match Time Limit countdown bar if active
    if (GRI.TimeLimit > 0)
    {
        CurTime = GRI.RemainingTime;
        Minutes = CurTime / 60;
        Seconds = CurTime - (Minutes * 60);

        if (Seconds < 10)
            TimeString = Minutes $ ":0" $ Seconds;
        else
            TimeString = Minutes $ ":" $ Seconds;

        DrawKOHScoreBar(Canvas, BarX, sY, BarW, BarH, 2, TimeString, 0.0, false);
        sY -= BlockSize * 0.75;
    }

    // 3. Draw Decoupled Capture Point Icons (stacked from bottom upwards)
    IconSize = BlockSize * 0.7;
    BottomY = Canvas.ClipY - (BlockSize * 0.85);

    for (k = 0; k < GRI.NumTimers && k < 6; k++)
    {
        IconY = BottomY - (k * (BlockSize * 0.72));
        PointOwner = GRI.TimerTeams[k];

        if (PointOwner == 0)
            IconIdx = 0; // Blue holdout icon
        else if (PointOwner == 1)
            IconIdx = 1; // Red holdout icon
        else
            IconIdx = 2; // Neutral grey icon

        // Draw Holdout Icon badge
        Canvas.Style = ERenderStyle.STY_Alpha;
        Canvas.DrawColor = WhiteColor;
        Canvas.SetPos(ColX, IconY);
        DrawTexRect(Canvas, ScoreIcons[IconIdx], IconSize, IconSize);

        // Draw Point Letter ('A', 'B', 'C', 'D', 'E', 'F') centered on badge
        Letter = PointLetters[k];
        Canvas.Font = MyFonts.GetHUDMedFont(HUDSize);
        Canvas.StrLen(Letter, XL, YL);
        Canvas.Style = ERenderStyle.STY_Translucent;
        Canvas.DrawColor = WhiteColor;
        Canvas.SetPos(ColX + ((IconSize - XL) * 0.5), IconY + ((IconSize - YL) * 0.5));
        Canvas.DrawText(Letter, false);
    }
}

simulated function DrawMiniMapObjects(canvas Canvas, float PlayerPosX, float PlayerPosY)
{
    local MinimapObjectReplicationInfo TimerItem;
    local MinimapInfo minimap;
    local int i, Team, TimerTeam;
    local float colour;

    Super.DrawMiniMapObjects(Canvas, PlayerPosX, PlayerPosY);

    MiniMap = RagePlayer(PlayerOwner).MiniMap;
    if (MiniMap == None)
        return;

    Team = TeamIndex();

    for (i = 0; i < MiniMap.GetNumItems(Team); ++i)
    {
        TimerItem = MiniMap.GetItem(i, Team);
        if (TimerItem == None)
            continue;

        if (TimerItem.Type == 'Player' || TimerItem.Type == 'Bot')
            continue;

        if (TimerItem.Type == 'TimerNeutral' || TimerItem.Type == 'TimerRed' || TimerItem.Type == 'TimerBlue')
        {
            if (MiscAnimCounter <= 0.5)
                colour = MiscAnimCounter * 255;
            else
                colour = (1.0 - MiscAnimCounter) * 255;

            Canvas.DrawColor = WhiteColor;
            Canvas.DrawColor.A = 255 - colour;

            if (TimerItem.Type == 'TimerBlue')
                TimerTeam = 0;
            else if (TimerItem.Type == 'TimerRed')
                TimerTeam = 1;
            else
                TimerTeam = 2;

            Canvas.Style = ERenderStyle.STY_Alpha;
            Canvas.SetPos(
                (TimerItem.X - MiniMap.MapLeft) * MiniMap.PixelsToMapUnits * MapScale - mapx * MapScale - MinimapIconSize * RenderScale * 0.5,
                (TimerItem.Y - MiniMap.MapTop) * MiniMap.PixelsToMapUnits * MapScale - mapy * MapScale - MinimapIconSize * RenderScale * 0.5
            );

            DrawTexRect(Canvas, TimerIcon_Team[TimerTeam], MinimapIconSize * RenderScale, MinimapIconSize * RenderScale);
            GameObjectItem = TimerItem;
        }
    }
}

defaultproperties
{
     BarBackColor=(R=15,G=15,B=20,A=180)
     PointLetters(0)="A"
     PointLetters(1)="B"
     PointLetters(2)="C"
     PointLetters(3)="D"
     PointLetters(4)="E"
     PointLetters(5)="F"
     TimerIcon_Team(0)=(X=160,Y=160,W=32,H=32,t=Texture'Rage.MinimapNewIcons')
     TimerIcon_Team(1)=(X=128,Y=160,W=32,H=32,t=Texture'Rage.MinimapNewIcons')
     TimerIcon_Team(2)=(X=96,Y=160,W=32,H=32,t=Texture'Rage.MinimapNewIcons')
     ScoreIcons(0)=(X=192,W=64,H=64,t=Texture'Rage.ScoreIcons')
     ScoreIcons(1)=(X=192,Y=64,W=64,H=64,t=Texture'Rage.ScoreIcons')
     ScoreIcons(2)=(X=192,Y=128,W=64,H=64,t=Texture'Rage.ScoreIcons')
     ScoreIcons(3)=(X=128,Y=128,W=64,H=64,t=Texture'Rage.ScoreIcons')
}
