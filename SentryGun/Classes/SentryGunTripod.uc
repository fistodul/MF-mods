//=============================================================================
// SentryGunTripod - Stand base for SentryGunTurret
//=============================================================================
class SentryGunTripod extends Actor;

defaultproperties
{
     RemoteRole=ROLE_SimulatedProxy
     DrawType=DT_Mesh
     Mesh=Mesh'RageWeapons.TripodMeshTemp'
     CollisionRadius=0.000000
     CollisionHeight=0.000000
     bCollideActors=False
     bCollideWorld=False
     bBlockActors=False
     bBlockPlayers=False
     bDontBlockOwner=True
}
