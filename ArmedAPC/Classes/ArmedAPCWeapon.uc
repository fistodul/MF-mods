//=============================================================================
// ArmedAPCWeapon - Held by an ArmedAPC gunner. It can't be put down, so the
// gunner can't switch to their own weapons, and it draws the turret's aim.
//=============================================================================
class ArmedAPCWeapon extends VehicleWeapon;

// Stay in Idle2: the Active and Idle states would let PutDown through
function BringUp() {}

function bool PutDown()
{
	Pawn(Owner).PendingWeapon = None;
	return false;
}

// The Reload key, through RagePlayer.cs_Reload
function Reload()
{
	local ArmedAPC APC;

	APC = ArmedAPC(AssociatedVehicle);
	// Not when full or already reloading
	if (APC.ClipAmmo > 0 && APC.ClipAmmo < APC.MaxClipAmmo)
		APC.ReloadTurret();
}

// Crosshair where the barrel points, and the clip
simulated event PostRender(Canvas Canvas)
{
	local PlayerPawn PP;
	local ArmedAPC APC;
	local RageHUD HUD;
	local vector Start, Dir, HitLocation, HitNormal, ScreenPos;
	local float Scale;

	PP = PlayerPawn(Owner);
	APC = ArmedAPC(PP.VehicleIn);
	HUD = RageHUD(PP.myHUD);
	if (APC == None || HUD == None)
		return;

	APC.GetMuzzle(Start, Dir);
	if (APC.Trace(HitLocation, HitNormal, Start + Dir * APC.MaxRange, Start, false) == None)
		HitLocation = Start + Dir * APC.MaxRange;

	// Projecting a point behind the view would put it on screen mirrored
	if ((HitLocation - PP.Location) dot vector(PP.ViewRotation) <= 0)
		return;

	// On clients this weapon is a simulated proxy, which skips non-simulated natives like Project
	ScreenPos = HUD.Project(Canvas, HitLocation);
	Scale = Canvas.ClipX / 640;

	// Drawn like RageHUD.DrawCrossHair
	Canvas.Style = ERenderStyle.STY_Subtractive;
	Canvas.DrawColor = HUD.GreyColor;
	DrawCrossHair(Canvas, HUD, ScreenPos, Scale);
	Canvas.Style = ERenderStyle.STY_Translucent;
	if (HUD.TeamIndex() == 1)
		Canvas.DrawColor = HUD.RedColor;
	else
		Canvas.DrawColor = HUD.BlueColor;
	DrawCrossHair(Canvas, HUD, ScreenPos, Scale);
	DrawCrossHair(Canvas, HUD, ScreenPos, Scale);

	Canvas.Style = ERenderStyle.STY_Normal;
	Canvas.Font = HUD.MyFonts.GetHUDMedFont(HUD.HUDSize);
	Canvas.SetPos(ScreenPos.X - 16 * Scale, ScreenPos.Y + 20 * Scale);
	if (APC.ClipAmmo > 0)
		Canvas.DrawText(APC.ClipAmmo);
	else
		Canvas.DrawText("RELOADING");
}

simulated function DrawCrossHair(Canvas Canvas, RageHUD HUD, vector ScreenPos, float Scale)
{
	Canvas.SetPos(ScreenPos.X - 16 * Scale, ScreenPos.Y - 16 * Scale);
	Canvas.DrawTile(HUD.CrosshairGraphic[HUD.Crosshair], 32 * Scale, 32 * Scale, 1, 1, 30, 30);
}

defaultproperties
{
     bOwnsCrosshair=True
     DeathMessage="%k gunned down %o from an APC turret."
     PickupMessage="Manning the APC turret"
}
