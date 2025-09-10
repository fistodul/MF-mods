class ZombieHUD extends RageTeamHUD;

simulated function DrawHealth(canvas Canvas, int sX, int sY)
{
	local int RenderHeight;
	local float TextWidth, TextHeight;
	local TexRect HealthLevel;

	RenderHeight = (Health_Back.H * Max(RagePlayerOwner.Health, 0)) / RagePlayerOwner.Default.Health;

	// Filled Health level
	Canvas.SetPos (sX, sY);
	Canvas.Style = ERenderStyle.STY_Translucent;
	Canvas.DrawColor = Colour_Sets[TeamIndex()];

	HealthLevel = Health_Back;
	HealthLevel.Y += Health_Back.H - RenderHeight;
	HealthLevel.H -= Health_Back.H - RenderHeight;
	RenderHeight *= RenderScale;

	Canvas.SetPos (sX, sY + (Health_Back.H * RenderScale) - RenderHeight);
	DrawTexRect(Canvas, HealthLevel, Health_Back.W * RenderScale, RenderHeight);

	// Outline
	Canvas.SetPos (sX, sY);
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
