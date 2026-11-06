# Terrain build workflow

The Toolkit needs individual scenery/light files; BG3 needs `_merged.lsf` files
in the PAK. Keep those outputs separate. Do not use a saved Adventure to validate
a replacement navigation grid: the save can retain its previous grid.

## Author and bake

1. Close BG3 and the Toolkit. Edit `toolkit/scenery/AA_Arena_Main.scenery.json`.
2. Run `scripts/Sync-ToolkitProject.ps1`. It backs up the installed project under
   `build/toolkit-sync-backups`, exports individual objects into a separate build
   folder and synchronizes the editor project. It does not stamp navigation.
3. Open AA_Arena_Main in the Toolkit, reload the changed resources, run
   **AI Grid → Generate → Full Generate**, wait for completion and use the
   **AI Grid Save** control.
4. Copy the saved runtime `Data/Mods/<module>/Levels/AA_Arena_Main/Ai` and editor
   `Data/Editor/Mods/<module>/Levels/AA_Arena_Main/Ai` files back into their
   corresponding `toolkit/Data` source directories.
5. Only after that actual bake, run
   `python tools/scenery/record_navgrid.py "Full Generate and AI Grid Save; describe geometry and observed cell count"`.

For editor export without touching the runtime resources:

```powershell
.\scripts\Build-ArenaScenery.ps1 -EditorOnly -EditorOutputPath .\build\editor-scenery
```

This authoring path intentionally allows unbaked geometry. Normal builds reject
it until the saved grid and navigation stamp match.

## Build and check

```powershell
.\scripts\Build-Pak.ps1
.\scripts\Validate-ToolkitProject.ps1
lua tests/run.lua
lua tests/engine_smoke.lua
python -m unittest discover -s tests -p test_navigation_build.py
```

The Windows PAK builder first validates navigation and rebuilds merged resources.
The stamp covers solid-object templates, positions, rotations, scales and
navigation flags, every terrain/ground-construction file, and the saved grid.
A separate build receipt checks the compiled scenery and lights against the
manifest. Changing geometry, replacing a grid, or packaging old compiled resources
fails the build. A stamp proves matching inputs, not usable traversal.

The Python PAK builder requires the same current navigation and build receipt.
Install its dependencies with `python -m pip install -r tools/pak/requirements.txt`.
If merged resources need rebuilding on that platform, use
`tools/scenery/build_scenery.py --conv <conv.dll>` first. Its
`--editor-only --per-object <directory>` mode produces only editor objects.

When gameplay checks resume, install the normal versioned PAK and create a fresh
disposable Adventure. Test both stair-to-platform connections, descent, cover
collision and line of sight. Earlier saved checkpoints cannot certify a new bake.
Temporary measurement probes are not accepted by `Install-Pak.ps1` and are never
included in normal build output.
