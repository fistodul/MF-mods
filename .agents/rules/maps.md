---
trigger: model_decision
description: Building or changing maps from scripts (T3D export/import, driving MobileForcesEd macros), editor command quirks, zones, fog, sky and ceiling, and what Battle Royale needs from a map. Read before touching any .umf.
---

# Maps & the editor

> Part of the Mobile Forces agent guide. Section numbers are shared across `.agents/rules/`; the index is in the root `AGENTS.md`.

---

## 10. Maps & the Editor

### A. Pipeline (`.agents/tools/maptool/`)
There is no headless editor: a commandlet can't run editor commands (`GEditor` is missing, and `Actor.ConsoleCommand` crashes). The tool drives the real editor instead:
1. `python mfed.py export <map>.umf <dir>` exports `<dir>/MyLevel.t3d` with brush polygons, actors and embedded static meshes. `python t3d.py <dir>/MyLevel.t3d` surveys it: brushes with CSG op and bounds, mesh bounds, zones, spawns. `t3d.py` also gives a mesh's world triangles and the ground height under a point, for placing actors on terrain.
2. A small Python script writes the T3D to import, using `t3d.py`'s writers: `brush_actor` with `cube_polys` / `hexa_polys` / `prism_polys` (boxes, rotated blocks, cylinders, frustums), `simple_actor`, `import_actor` (copies an actor from another map's export, moved and renamed), `builder_brush` and `write_t3d`. Name new actors in an unused range (e.g. 900+).
3. Write a macro (`EXEC` file) of editor commands, for example:
   ```text
   MAP LOAD FILE=..\Maps\BR-thebigisland.umf
   OBJ LOAD FILE=..\Textures\rage_warehouse.utx
   MAP IMPORTADD FILE=..\MapBuild\add.t3d
   ACTOR SELECT NONE
   MAP REBUILD
   LIGHT APPLY
   PATHS DEFINE
   MAP SAVE FILE=..\Maps\BR-thebigisland.umf
   ```
4. `python mfed.py run <macro.txt> <out>.umf <t3d...>` stages the files in `<game>/MapBuild`, starts `MobileForcesEd.exe`, types `EXEC` into its command bar and waits for the saved map. The script is Python, but it drives the editor through Win32 calls (`ctypes`), so it needs a Windows Python: native, or under Wine (untested).
5. Verify by exporting the result again: brush order, zone numbers of spawns and ZoneInfos, actor counts. A new or changed map must be sent to servers and clients like any `.u`.

`BR-thebigisland` was built this way: one map as the base, with two other maps imported on top and moved into the sky.

### B. Paths
- The space in "Mobile Forces" breaks UCC and editor arguments. Start them by their 8.3 short path with that as the working directory (`mfed.py` does). Invoking UCC by its long path fails with `Failed to find object 'Class Any.Forces\System\UCC.exe"'`.
- The editor truncates `FILE=` values at ~64 characters. Use paths relative to `System` (`..\MapBuild\x.t3d`).
- Write macros with Python or a quoted heredoc, never `printf`: `printf` turns `\b` in `..\MapBuild\brBall.uc` into a backspace.

### C. T3D Import Rules
- The editor loads the edited map into package **`MyLevel`**. References in an imported T3D are `Model'MyLevel.X'` / `StaticMesh'MyLevel.X'`, whatever the map file is called.
- The **first brush** in an imported T3D replaces the editor's builder brush and is never CSG'd. Lead with a dummy one, or use it on purpose (10D).
- CSG follows actor order, and imported actors fill free slots left by deleted actors. Emit non-brush actors first, then brushes, so the new brushes land after the base map's.
- Brush polygons only take **bare** texture names, resolved against packages that are already loaded. `Texture=rage_warehouse.ground.ware_ground_1` silently leaves the face untextured: the engine's default brick, which looks deliberate. `OBJ LOAD FILE=..\Textures\<pkg>.utx` before the import. Static mesh triangles do take package-qualified names.
- Give every imported actor a unique name (e.g. a 900+ range). Clashes break the import.
- Static mesh terrain is not BSP: CSG never cuts it. Hide it under a floor by editing the triangle `Vertex` lines in the T3D (`Vertex <i> x y z nx ny nz u v`, local units × `DrawScale`).

### D. Editor Commands
Verified in `MobileForcesEd` (list them with a UTF-16 string scan of `System/Editor.dll`):
- `MAP LOAD FILE=`, `MAP IMPORTADD FILE=`, `MAP REBUILD`, `LIGHT APPLY`, `PATHS DEFINE`, `MAP SAVE FILE=`.
- `ACTOR SELECT NONE | ALL | INSIDE | INVERT | OFCLASS CLASS=X | OFSUBCLASS CLASS=X`, then `ACTOR DELETE`. There's no select-by-name: `INSIDE` uses the builder brush's volume, so `MAP IMPORTADD` a T3D holding only a builder brush (its first brush) around one actor, then select and delete; check nothing else has its `Location` inside. `INSIDE` skips brushes, and `BRUSH MOVETO` doesn't move the volume it tests, so a base-map brush can't be deleted by script, only reshaped with `MAP SELECT FIRST`/`LAST` + `MAP BRUSH PUT`.
- `MAP SELECT FIRST | LAST | ADDS | SUBTRACTS | ...` selects brushes by CSG order. `MAP BRUSH PUT` copies the builder brush's polygons and position into the selected brushes. Together they reshape a base-map brush in place, keeping its CSG order (e.g. lowering the world subtract `Brush1`, which `MAP SELECT FIRST` picks).
- `OBJ LOAD FILE=` loads a package.
- `PATHS BUILD` crashes (`Owner->CollisionRadius==Owner->CollisionHeight`, `UnCollisionMesh.cpp`) while auto-placing path nodes. Use `PATHS DEFINE`, which only links existing navigation points.
- `CLASS LOAD FILE=x.uc PACKAGE=MyLevel NAME=x` imports a class into the map (both `PACKAGE=` and `NAME=` are required), but the following `SCRIPT MAKE` crashes (`SaveStream` in `FTransaction`) for a subclass of a native class such as `Rage.Ball`. Map-embedded script is out for those.
- `SET LevelInfo <prop>` doesn't persist. Zone settings belong in a `ZoneInfo` actor placed in the zone (10E).
- `LIGHT APPLY` logs `Node side limit reached` on long thin polygons; it's harmless.
- The editor log is buffered: when the map file appears, the save is done, but `Editor.log` may still stop mid-build.

### E. Zones, Fog, Sky & Ceiling
- A `ZoneInfo` in a zone replaces the `LevelInfo`'s zone settings for that zone entirely. Copy what the base map set in its `LevelInfo` (fog, ambient) into the new `ZoneInfo`.
- **The renderer stops drawing at `DistanceFogEnd`, even with `bDistanceFog=False`.** `ZoneInfo`'s default of 8000 makes distant land vanish. A short fog end in a zone you can see out of (through a door or window) leaves hall-of-mirrors smearing beyond it. Keep the end longer than any line of sight (corner to corner of the world box).
- Zone portals: a sheet brush or volume brush with `PolyFlags=603979785` and polygon `Flags=603980041`. Water volumes: `PolyFlags=603979788` with a translucent water texture, plus a `RageWaterZone` inside. `ZoneVelocity` on a water zone makes a current; Z+1800 lifts a swimming player at a good pace.
- Don't wrap open-air areas in invisible zone-portal volumes. They caused hall-of-mirrors smearing around them. Traces also stop at non-solid portal faces, so the Battle Royale mod (10F) dropped items on them and spawned players inside geometry.
- The sky is any surface with `Flags=128` (FakeBackdrop), drawn from the `SkyZoneInfo` room. To lower a ceiling, lower the world subtract brush itself (10D). An extra solid slab is a real surface that spawning traces hit.
- Fall damage (`Pawn.TakeFallingDamage`): `100 * ((V + 750) / 450)^2` for landing speed `V` past 750 (dead at 1200). `ZoneTerminalVelocity` caps falling speed per zone (default 2500): 740 lands without damage, 830 costs 3 HP. Zone gravity alone doesn't save a long fall.
- Swimming: `WaterSpeed` 200 and `UnderWaterTime` 20 s, then 5 damage every 2 s. That's 4000 units of swimming per breath at best.
- Terrain meshes are one-sided heightfields, and an island's mesh usually sits on a flat seabed plate. Moved or scaled up the water column, that plate floats as a visible sheet. Hide it under the sea floor, or cover it with BSP from just above it (32 units, against z-fighting) down into the floor. `BR-thebigisland`'s mini island sits on a round reef (`prism_polys` frustum).
- Ladders (stock pattern, used by ~50 maps): a hidden `LadderClimber` (`CollisionHeight` = half the climb, `ClimbSpeed=0.5`, `Rotation` facing the wall) about 45 units off a vertical wall, with `Ladder` navigation points just below its bottom and above its top. A touching player switches to `PHYS_Ladder`. The visible ladder is a static mesh, e.g. `mf-Ghetto`'s `Ladder` (1040 tall, 20 off the wall; copy it with `import_actor`). Sloped terrain needs a vertical BSP pillar behind the ladder.
- Air pocket (verified): carve a chamber below the water and reach it by tunnels from the water zone. Put a horizontal sheet brush across the chamber at the water line (polygon `Flags=603989516` with a water texture, `PolyFlags=603979788`), and a `ZoneInfo` above it. The sheet seals off a dry zone where players surface and breathe. Add a ledge only a few units above the water, and light it so the way up can be seen from the tunnels.

### F. Battle Royale Maps (`battleRoyale`, map prefix `BR-`)
- Item scatter traces up from the map's `Sunlight` to the ceiling (`upperLimit`), then along ±X and ±Y at that height for the world limits. Items and non-air spawns trace straight down from the ceiling; air spawns drop 500 below it. Keep the `Sunlight` (`LightType=LT_None` if it shouldn't light) below the ceiling, and keep its four horizontal traces clear of geometry and zone portals.
- The safe zone centres on a `RageDominationTimer`. Keep its default `CondGameType`: outside Domination it is then hidden and inert, while `CondGameType=None` logs `Accessed None` in its `PostBeginPlay`.
- The `battleRoyale` package can't be rebuilt: its model and texture sources aren't in the repo.
