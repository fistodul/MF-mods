//=============================================================================
// ArmedAPCRocket - ArmedAPC with a rocket launcher turret.
//=============================================================================
class ArmedAPCRocket extends ArmedAPC;

defaultproperties
{
     TurretTurnRate=20000.000000
     TurretMesh=LodMesh'RageWeapons.RocketLauncherPickupCarryMesh'
     FireInterval=0.800000
     MaxClipAmmo=4
     ReloadTime=5.000000
     Spread=0.010000
     ProjectileClass=Class'RageWeapons.Rocket'
     FireSound=Sound'WeaponSFX_RocketLauncher.Fire'
     ReloadSound=Sound'WeaponSFX_RocketLauncher.Reload'
}
