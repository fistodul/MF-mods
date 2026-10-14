---
trigger: model_decision
description: RageHUD crosshair ownership (bOwnsCrossHair), Canvas drawing, 3D-to-2D target markers, and weapon HUD icon BMP format and layout. Read before drawing HUD overlays or adding a weapon icon.
---

# HUD, crosshair & weapon icons

> Part of the Mobile Forces agent guide. Section numbers are shared across `.agents/rules/`; the index is in the root `AGENTS.md`.

---

## 4. HUD, Crosshair & Weapon Icons

### A. The `bOwnsCrossHair` Mechanism
In `RageHUD.uc`:
```unrealscript
if ( !PlayerOwner.bBehindView && (RagePlayerOwner.Weapon != None) && (Level.LevelAction == LEVACT_None) )
{
    Canvas.DrawColor = WhiteColor;
    RagePlayerOwner.Weapon.PostRender(Canvas);

    if ( !RagePlayerOwner.Weapon.bOwnsCrossHair && RagePlayerOwner.Weapon.GetStateName() != 'DownWeapon' )
        DrawCrossHair(Canvas, 0,0 );
}
```
- `bOwnsCrossHair` is an actor variable that **does not replicate automatically**.
- If a weapon draws its own crosshair or terminal overlay (FLIR, missile camera, sniper scope), set `bOwnsCrossHair` in `PostRender` every frame. Don't rely on the weapon's `Tick`, which RageWeapon's client states can shadow (see **7F**):
  ```unrealscript
  bOwnsCrossHair = ActiveMissile != None;
  ```

### B. Canvas Rendering Conventions
- Always set `Canvas.Style` explicitly (`STY_Normal`, `STY_Translucent`, `STY_Modulated`, `STY_Alpha`).
- Use `Canvas.SmallFont`, `Canvas.MedFont`, or `RageHUD.MyFonts.GetHUDMedFont(HUDSize)`.
- Use `<<` (un-rotate vector) to project world points into local camera space for 3D HUD markers:
  ```unrealscript
  Rel = (TargetLoc - CamLoc) << CamRot;
  if (Rel.X > 50.0) // In front of camera
  {
      ScreenX = (Canvas.ClipX * 0.5) + (Rel.Y / Rel.X) * Proj;
      ScreenY = (Canvas.ClipY * 0.5) - (Rel.Z / Rel.X) * Proj;
  }
  ```

### C. HUD Weapon Icons (`WeaponIcon`) & The 20px Bottom Badge Rule
Mobile Forces draws inventory weapon icons using `RageHUD.DrawTexRect(Canvas, WeapIcon, RenderWidth, BlockSize)`.

1. **Importing the Icon Texture**:
   Icons are 64×64 textures imported via `#exec`:
   ```unrealscript
   #exec TEXTURE IMPORT NAME=MyWeaponIcon FILE=Textures\my_icon.bmp GROUP=Icons MIPS=OFF Flags=2
   ```
2. **Exact Bitmap Specifications**:
   - **File format**: Windows 3.x **8-bit Paletted BMP** (or PCX), 64×64 pixels (exact size 5,174 bytes for 64×64 BMP).
   - **Masking (`Flags=2`)**: Palette index `0` is the transparent mask color. Palette index `0` **MUST** be pure black `RGB(0, 0, 0)`.
   - **Foreground Colors**: Visible pixels must map to palette indices `1..255` (a grayscale ramp from near-black up to pure white). On the HUD, `RageHUD` multiplies the texture intensity by the HUD theme color (`Canvas.DrawColor`), so grayscale gives clean 3D relief.
3. **The 20px Bottom Clearance Trap**:
   - In `RageHUD`, each inventory slot draws a blue ammo quantity badge (e.g. `"1"`, `"2"`, `"3"`) over the **bottom ~20 pixels** of the slot, and slot hotkeys (`"0"`, `"9"`) at the top edge.
   - **Rule**: The visual icon artwork must be placed between `y = 4..43` (vertical center at `y ~ 24`), with **20-21 pixels of transparent clearance at the bottom** and **12-14 pixels of margin on the left/right** (`x = 13..50`).
   - If an icon is centered at `(32, 32)` spanning the entire 64×64 canvas, it will collide with the bottom quantity badge and top key numbers!
4. **Linking in `defaultproperties`**:
   ```unrealscript
   defaultproperties
   {
       WeaponIcon=(X=0,Y=0,W=64,H=64,t=Texture'MyPackage.Icons.MyWeaponIcon')
   }
   ```
