class ZombieHUD extends RageTeamHUD;

var() color HumanOutlineColor;

simulated function DrawHealth(canvas Canvas, int sX, int sY)
{
    local int RenderHeight;
    local float TextWidth, TextHeight;
    local TexRect HealthLevel;
    local int MaxHealth;

    if (RagePlayerOwner.IsA('ZombiePlayer'))
        MaxHealth = ZombiePlayer(RagePlayerOwner).MaxHealth;
    else
        MaxHealth = RagePlayerOwner.Default.Health;

    RenderHeight = (Health_Back.H * Max(RagePlayerOwner.Health, 0)) / MaxHealth;

    // Filled Health level
    Canvas.SetPos(sX, sY);
    Canvas.Style = ERenderStyle.STY_Translucent;
    Canvas.DrawColor = Colour_Sets[TeamIndex()];

    HealthLevel = Health_Back;
    HealthLevel.Y += Health_Back.H - RenderHeight;
    HealthLevel.H -= Health_Back.H - RenderHeight;
    RenderHeight *= RenderScale;

    Canvas.SetPos(sX, sY + (Health_Back.H * RenderScale) - RenderHeight);
    DrawTexRect(Canvas, HealthLevel, Health_Back.W * RenderScale, RenderHeight);

    // Outline
    Canvas.SetPos(sX, sY);
    Canvas.Style = ERenderStyle.STY_Alpha;
    Canvas.DrawColor = WhiteColor;
    DrawTexRect(
        Canvas,
        Health_Team[TeamIndex()],
        Health_Team[TeamIndex()].W * RenderScale,
        Health_Team[TeamIndex()].H * RenderScale
    );

    // Numerical Health level
    Canvas.Font = MyFonts.GetHUDMedFont(HUDSize);
    Canvas.TextSize(RagePlayerOwner.Health, TextWidth, TextHeight);
    Canvas.SetPos(
        sX + ((Health_Team[TeamIndex()].W + 8) * RenderScale * 0.5) - (TextWidth * 0.75),
        sY + (48 * RenderScale) - (TextHeight * 0.5)
    );

    Canvas.DrawText(RagePlayerOwner.Health);
}

simulated function DrawArmour(canvas Canvas, int sX, int sY)
{
    local int DrawArmour, RenderHeight, T;
    local float TextWidth, TextHeight;
    local TexRect ArmourLevel;
    local Inventory Inv;
    local RageArmour Armour;

    T = TeamIndex();
    DrawArmour = 0;

    for (Inv = RagePlayerOwner.Inventory; Inv != None; Inv = Inv.Inventory)
    {
        Armour = RageArmour(Inv);
        if (Armour != None)
        {
            DrawArmour += Armour.Charge;
            break;
        }
    }

    if (Armour == None)
        return;

    RenderHeight = (Armour_Back.H * DrawArmour) / Armour.Default.Charge;

    // Filled Armour level
    Canvas.SetPos(sX, sY);
    Canvas.Style = ERenderStyle.STY_Translucent;
    Canvas.DrawColor = Colour_Sets[T];
    ArmourLevel = Armour_Back;
    ArmourLevel.Y += Armour_Back.H - RenderHeight;
    ArmourLevel.H -= Armour_Back.H - RenderHeight;
    RenderHeight *= RenderScale;
    Canvas.SetPos (sX, sY + (Armour_Back.H * RenderScale) - RenderHeight);
    DrawTexRect(Canvas, ArmourLevel, (Armour_Back.W + 4) * RenderScale, RenderHeight);

    // Outline
    Canvas.SetPos(sX, sY);
    Canvas.Style = ERenderStyle.STY_Alpha ;
    Canvas.DrawColor = WhiteColor;
    DrawTexRect(Canvas, Armour_Team[T], Armour_Team[T].W * RenderScale, Armour_Team[T].H * RenderScale);

    // Numerical Armour level
    Canvas.Font = MyFonts.GetHUDMedFont(HUDSize);
    Canvas.TextSize(DrawArmour, TextWidth, TextHeight);
    Canvas.SetPos(
        sX + (Armour_Team[T].W * RenderScale * 0.5) - (TextWidth * 0.75),
        sY + (Armour_Team[T].H * RenderScale * 0.5) - (TextHeight * 0.5)
    );
    Canvas.DrawText(DrawArmour);
}

simulated function DrawGameSpecificStuff(canvas Canvas)
{
    local float sX, sY;
    local int CurTime, Minutes, Seconds;
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

simulated function DrawInventory(canvas Canvas, int sX, int sY)
{
    local RageWeapon Weap, aWeaps[12]; // Max of ten groups
    local int LeftToDraw, I;
    local float CurX;
    local Inventory Inv;
    local int WeapC;

    // Find all rage weaps
    for (Inv = RagePlayerOwner.Inventory; Inv != None; Inv = Inv.Inventory)
    {
        Weap = RageWeapon(Inv);
        if (Weap != none)
        {
            aWeaps[WeapC] = Weap;
            if (WeapC < 11)
                WeapC++;
            else
                break;
        }
    }

    // Draw the groups
    CurX = 0;
    Canvas.Style = ERenderStyle.STY_Alpha;

    if (RagePlayerOwner.IsA('ZombiePlayer'))
        LeftToDraw = ZombiePlayer(RagePlayerOwner).MaxCarry;
    else
        LeftToDraw = RagePlayerOwner.MaxCarry;

    for (I = 0; I < WeapC; I++)
    {
        Weap = aWeaps[I];
        if (Weap != None)
        {
            if (RagePlayerOwner.AmISelected(Weap))
                DrawWeapIcon(Canvas, Weap, sX + CurX, sY, 2);
            else
                DrawWeapIcon(Canvas, Weap, sX + CurX, sY, TeamIndex());

            CurX += Weap.CarrySize*BlockSize;
            // Make sure knife (carrysize 0) is shown
            if (Weap.CarrySize == 0)
                CurX += BlockSize;

            LeftToDraw -= Weap.CarrySize;
        }
    }

    // Draw remainging empty boxes
    Canvas.DrawColor = WhiteColor;
    if (LeftToDraw > 0)
        DrawEmptyIcon(Canvas, LeftToDraw, sX + CurX, sY);
}

simulated function DrawBox(canvas Canvas, float X, float Y, float W, float H)
{
    Canvas.SetPos(X, Y);
    Canvas.DrawTile(Texture'Rage.ScoreBoxes', W, H, 10, 100, 1, 1);
}

simulated function DrawNearestHumanOutline(canvas Canvas)
{
    local Pawn P, Target;
    local float MinDist, Dist, Proj, Scale, TanHalfFOV;
    local float CX, CY, W, H, L, X1, X2, Y1, Y2, TW, TH;
    local vector CamLoc, Rel;
    local rotator CamRot;
    local string S;

    if (TeamIndex() != 1 || RagePlayerOwner.Health <= 0)
        return;

    if (PlayerOwner.ViewTarget != None)
    {
        CamLoc = PlayerOwner.ViewTarget.Location;
        CamRot = PlayerOwner.ViewTarget.Rotation;
    }
    else
    {
        CamLoc = PlayerOwner.Location + vect(0,0,1) * PlayerOwner.EyeHeight;
        CamRot = PlayerOwner.ViewRotation;
    }

    MinDist = 999999.0;
    for (P = Level.PawnList; P != None; P = P.NextPawn)
    {
        if (P != PlayerOwner && P != PlayerOwner.ViewTarget && P.Health > 0 && P.PlayerReplicationInfo != None && P.PlayerReplicationInfo.Team == 0)
        {
            Dist = VSize(P.Location - CamLoc);
            if (Dist < MinDist)
            {
                MinDist = Dist;
                Target = P;
            }
        }
    }

    if (Target == None)
        return;

    Rel = (Target.Location - CamLoc) << CamRot;
    TanHalfFOV = Tan(FMax(PlayerOwner.DesiredFOV, PlayerOwner.DefaultFOV) * 0.008726646);
    Proj = (Canvas.ClipX * 0.5) / FMax(TanHalfFOV, 0.001);

    Canvas.Style = ERenderStyle.STY_Translucent;
    Canvas.DrawColor = HumanOutlineColor;
    Canvas.Font = MyFonts.GetSmallFont(Canvas.ClipX);
    S = int(MinDist / 50.0) $ "m";

    if (Rel.X > 1.0)
    {
        CX = (Canvas.ClipX * 0.5) + (Rel.Y / Rel.X) * Proj;
        CY = (Canvas.ClipY * 0.5) - (Rel.Z / Rel.X) * Proj;
        H = FClamp((Target.CollisionHeight * 2.2 / Rel.X) * Proj, 14.0, Canvas.ClipY * 0.8);
        W = FClamp(H * 0.5, 10.0, Canvas.ClipX * 0.8);
        X1 = CX - W * 0.5;  X2 = CX + W * 0.5;
        Y1 = CY - H * 0.5;  Y2 = CY + H * 0.5;

        if (X2 >= 0 && X1 <= Canvas.ClipX && Y2 >= 0 && Y1 <= Canvas.ClipY)
        {
            L = FClamp(FMin(W, H) * 0.3, 4.0, 16.0);
            DrawBox(Canvas, X1, Y1, L, 2); DrawBox(Canvas, X1, Y1, 2, L);
            DrawBox(Canvas, X2 - L, Y1, L, 2); DrawBox(Canvas, X2 - 2, Y1, 2, L);
            DrawBox(Canvas, X1, Y2 - 2, L, 2); DrawBox(Canvas, X1, Y2 - L, 2, L);
            DrawBox(Canvas, X2 - L, Y2 - 2, L, 2); DrawBox(Canvas, X2 - 2, Y2 - L, 2, L);
            DrawBox(Canvas, CX - 1, CY - 1, 3, 3);

            Canvas.TextSize(S, TW, TH);
            Canvas.SetPos(CX - TW * 0.5, Y2 + 2);
            Canvas.DrawText(S, false);
            return;
        }
    }

    // Off-screen indicator clamped to border
    CX = Canvas.ClipX * 0.5;
    CY = Canvas.ClipY * 0.5;
    Rel.Z = -Rel.Z;

    if (Rel.X <= 1.0)
        Rel.Z = (int(Rel.Z >= 0) * 2 - 1) * FMax(Abs(Rel.Y), 1.0);

    Scale = Sqrt(Rel.Y * Rel.Y + Rel.Z * Rel.Z);
    X1 = CX + (Rel.Y / Scale) * (CX - 48);
    Y1 = CY + (Rel.Z / Scale) * (CY - 48);

    DrawBox(Canvas, X1 - 4, Y1 - 4, 8, 8);
    Canvas.TextSize(S, TW, TH);
    Canvas.SetPos(X1 - TW * 0.5, Y1 + 6);
    Canvas.DrawText(S, false);
}

simulated function PostRender(canvas Canvas)
{
    Super.PostRender(Canvas);
    DrawNearestHumanOutline(Canvas);
}

defaultproperties
{
     HumanOutlineColor=(R=0,G=160,B=255,A=255)
     ScoreIcons(2)=(X=128,Y=128,W=64,H=64,t=Texture'Rage.ScoreIcons')
}
