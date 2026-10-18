---
trigger: model_decision
description: "Building or changing maps from scripts: the maptool pipeline, T3D export/import rules, MobileForcesEd macros and editor command quirks. Read before touching any .umf; zones, game-mode actors and testing are in map-content.md."
---

# Maps & the editor

> Part of the Mobile Forces agent guide. Section numbers are shared across `.agents/rules/`; the index is in the root `AGENTS.md`. Sections 10E-H (zones, water, game modes, testing) are in `map-content.md`.

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
- Actor properties that reference objects (`AmbientSound=Sound'levelSFX.LappingWater01'`, textures, meshes) also only resolve against loaded packages. Otherwise the import drops them silently and keeps the actor. `OBJ LOAD FILE=..\Sounds\<pkg>.uax` first, then check with `upkg.py info <map>` that the map now imports `<pkg>`.
- Give every imported actor a unique name (e.g. a 900+ range). Clashes break the import.
- Static mesh terrain is not BSP: CSG never cuts it. Hide it under a floor by editing the triangle `Vertex` lines in the T3D (`Vertex <i> x y z nx ny nz u v`, local units × `DrawScale`).

### D. Editor Commands
Verified in `MobileForcesEd` (list them with a UTF-16 string scan of `System/Editor.dll`):
- `MAP LOAD FILE=`, `MAP IMPORTADD FILE=`, `MAP REBUILD`, `LIGHT APPLY`, `PATHS DEFINE`, `MAP SAVE FILE=`.
- `ACTOR SELECT NONE | ALL | INSIDE | INVERT | OFCLASS CLASS=X | OFSUBCLASS CLASS=X`, then `ACTOR DELETE`. There's no select-by-name: `INSIDE` uses the builder brush's volume, so `MAP IMPORTADD` a T3D holding only a builder brush (its first brush) around one actor, then select and delete; check nothing else has its `Location` inside. `INSIDE` skips brushes, and `BRUSH MOVETO` doesn't move the volume it tests, so a base-map brush can't be deleted by script, only reshaped with `MAP SELECT FIRST`/`LAST` + `MAP BRUSH PUT`.
- `MAP SELECT FIRST | LAST | ADDS | SUBTRACTS | ...` selects brushes by CSG order. `MAP BRUSH PUT` copies the builder brush's polygons and position into the selected brushes. Together they reshape a base-map brush in place, keeping its CSG order (e.g. lowering the world subtract `Brush1`, which `MAP SELECT FIRST` picks). `MAP SENDTO FIRST | LAST` moves the selected brushes to either end of the order, so any brush can be reached: send the N brushes after it to the front one by one (`MAP SELECT LAST`, `MAP SENDTO FIRST`), `PUT` into the now-last one, then send the N back (`MAP SELECT FIRST`, `MAP SENDTO LAST`), which restores the order exactly (`BR-thebigisland`'s waterfall, Brush915). Clear the selection (`ACTOR SELECT NONE`) before each `MAP SELECT`. `PUT` snaps the location to the 16 grid; the builder brush must be `Brush0`/`CSG_Active` as `t3d.builder_brush` writes it (a renamed copy of an exported brush crashed in `PrepBrush`).
- `OBJ LOAD FILE=` loads a package.
- `PATHS BUILD` crashes (`Owner->CollisionRadius==Owner->CollisionHeight`, `UnCollisionMesh.cpp`) while auto-placing path nodes. Use `PATHS DEFINE`, which only links existing navigation points.
- `CLASS LOAD FILE=x.uc PACKAGE=MyLevel NAME=x` imports a class into the map (both `PACKAGE=` and `NAME=` are required), but the following `SCRIPT MAKE` crashes (`SaveStream` in `FTransaction`) for a subclass of a native class such as `Rage.Ball`. Map-embedded script is out for those.
- `SET LevelInfo <prop>` doesn't persist. Zone settings belong in a `ZoneInfo` actor placed in the zone (10E).
- `LIGHT APPLY` logs `Node side limit reached` on long thin polygons; it's harmless.
- The editor log is buffered: when the map file appears, the save is done, but `Editor.log` may still stop mid-build.
