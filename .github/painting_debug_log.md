# Painting Debug Log

This page records the sequence of issues and attempted fixes for the vehicle preview painting system.

## Summary (as of 2026-03-29)

### Problem 1: Brush shape PR/preview was square only
- Symptoms: shape from UI did not apply; always painted square/quadratic/flat.
- Attempt: Added shape selector in `vehicle_select.gd` and `player_vehicle_library.gd` (`circle`, `square`, `star`, `smoke`).
- Outcome: UI selection worked, but overlay still displayed square in final scene.

### Problem 2: Decal assignment property errors
- `Invalid assignment of property or key 'material_override' on Decal`.
- Fixed: replaced with `decal_node.material` (then `decal_node.decal_material`).
- Outcome: compile clean, still maybe no visual effect due to engine compatibility.

### Problem 3: DecalMaterial not available at runtime
- Error: `Identifier "DecalMaterial" not declared` / `ClassDB.instance not found`.
- Attempt: dynamic fallback via `ClassDB.class_exists("DecalMaterial")` -> `ClassDB.instantiate("DecalMaterial")` else `StandardMaterial3D`.
- Outcome: error gone; still no functional paint output.

### Problem 4: Painting path disabled in code
- `_paint_at_viewport_point` had camera_brush logic commented out (manual decal path used instead).
- Fix: re-enable camera brush, call `_request_overlay_refresh()` on each paint hit.
- Outcome: logs now show paint hits, but visual still missing.

### Problem 5: overlay atlas may not be applied recursively
- `OverlayAtlasManager.apply()` call path had early returns when `selected_vehicle_decals` present; removed.

## Current state
- Raycast hits detected and logged.
- CameraBrush transform + drawing toggled.
- OverlayAtlasManager.apply is called.
- No script errors.
- Rendering still not updating in-game.

## Next steps
1. Confirm `OverlayAtlasManager` is present and has valid atlas texture RID.
2. Confirm meshes have UV2 and proper layers (21).
3. Add temporary debug warnings in `OverlayAtlasManager._construct_atlas_and_apply_materials`.
4. If necessary, fallback to direct texture painting on mesh `material_overlay` by changing `camera_brush`->`MeshInstance3D.material_overlay` directly to isolate.
5. Keep log updated with each attempt.

## 2026-03-30 implementation start

### Hypothesis
- The GPU path was stale after refresh because the brush only learned atlas textures at ready time, while preview refreshes rebuild the atlas later.
- We also need a structured log level so test runs can print the full paint lifecycle while normal play stays quieter.

### Changes in progress
- Added paint log levels and a `get_paint_debug_snapshot()` helper in `scripts/reading/vehicle_select.gd`.
- Added counters for overlay refreshes and paint hits, plus `last_paint_hit` for test visibility.
- Re-synced the brush atlas textures after preview refresh and after overlay refresh.
- Extended the vehicle select scene-runner test to assert brush readiness, overlay refresh counts, and the last paint hit snapshot.

### 2026-03-30 tightening pass
- Cached brush-shape textures in `VehicleSelectPaintHelpers` so paint hits stop recreating the brush shape every frame.
- Removed the duplicate global mouse paint path from `_unhandled_input()` to reduce double-hit and double-miss logging.
- Expanded paint-miss logging to include preview container size, viewport size, preview mesh count, and camera readiness.

### 2026-03-30 regression coverage
- Added a vehicle-select smoke regression test that asserts `MainVBox`, the paint controls, and the initial paint snapshot readiness flags.
- This should catch future `_ready()`/scene-tree wiring regressions immediately during GDUnit runs.

### 2026-03-30 projection fix
- Changed preview decal projection to use `cull_mask = -1` instead of setting the decal node layer, so the decal can actually project onto the vehicle meshes.
- Made the debug paint spheres semi-transparent so they act like a visual marker instead of blocking the view of the paint result.

### Expected outcome
- If the first fix is correct, logs should show a complete sequence from preview refresh -> overlay apply -> atlas rebind -> paint hit.
- If not, the verbose log and snapshot should let us distinguish ray-hit failure from atlas/brush binding failure quickly.
