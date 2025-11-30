class ZombieHUD extends RageTeamHUD;

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

    Canvas.DrawText (RagePlayerOwner.Health);
}

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

simulated function DrawInventory ( canvas Canvas, int sX, int sY )
{
	local RageWeapon Weap;
	local RageWeapon WeapT;
	local int LeftToDraw, I;
	local float CurX;
	local Inventory Inv;
	local RageWeapon aWeaps[12]; // Max of ten groups
	local int WeapC;
	local bool bSwapped;

	// Find all rage weaps
	for (Inv = RagePlayerOwner.Inventory; Inv != None; Inv = Inv.Inventory)
	{
		Weap = RageWeapon(Inv);
		if ( Weap != none )
		{
			aWeaps[WeapC] = Weap;
			if(WeapC < 11)
				WeapC++;
			else
				break;
		}
	}

	// Draw the groups
	CurX = 0;
	LeftToDraw = ZombiePlayer(RagePlayerOwner).MaxCarry;
	Canvas.Style = ERenderStyle.STY_Alpha;

	for (I = 0; I < WeapC; I++)
	{
		Weap = aWeaps[I];
		if (Weap != None)
		{
			if (RagePlayerOwner.AmISelected(Weap))
				DrawWeapIcon(Canvas, Weap, sX+CurX, sY, 2);
			else
				DrawWeapIcon(Canvas, Weap, sX+CurX, sY, TeamIndex());

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

defaultproperties
{
    ScoreIcons(2)=(X=128,Y=128,W=64,H=64,t=Texture'Rage.ScoreIcons')
}
