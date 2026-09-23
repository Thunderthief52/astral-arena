#!/usr/bin/env python3
"""Build the Astral Arena Adventure PAK without Divine.exe or the BG3 Toolkit.

The checked-in Toolkit level, the Script Extender runtime, and the menu
localization are packaged exactly as scripts/Build-Pak.ps1 lays them out. The
only files not tracked in git are the Toolkit-generated GUI/metadata.lsf and
mod_publish_logo.png; they are copied from an existing Adventure PAK.

    python3 tools/pak/build_pak.py --version 0.4.0-alpha.1 \
        --assets-from "%LOCALAPPDATA%/Larian Studios/Baldur's Gate 3/Mods/AstralArenaAdventure_29c48c80-8777-f7b5-6bb8-376c1c5d8db6.pak"
"""
import argparse
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loca  # noqa: E402
import lspk  # noqa: E402

MODULE = "AstralArenaAdventure_29c48c80-8777-f7b5-6bb8-376c1c5d8db6"
REQUIRED = [
    f"Mods/{MODULE}/meta.lsx",
    f"Mods/{MODULE}/Levels/AA_Arena_Main/meta.lsf",
    f"Mods/{MODULE}/Levels/AA_Arena_Main/Scenery/_merged.lsf",
    f"Mods/{MODULE}/Levels/AA_Arena_Main/Lights/_merged.lsf",
    f"Mods/{MODULE}/ScriptExtender/Lua/AstralArena/Server/Controller.lua",
    f"Mods/{MODULE}/ScriptExtender/Lua/AstralArena/Server/Bg3Adapter.lua",
    f"Mods/{MODULE}/GUI/metadata.lsf",
    f"Mods/{MODULE}/mod_publish_logo.png",
    "Localization/English/AstralArena_English.loca",
]
TOOLKIT_ARTWORK = ["GUI/metadata.lsf", "mod_publish_logo.png"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--assets-from", required=True, help="existing Adventure PAK providing Toolkit artwork")
    parser.add_argument("--out", help="output PAK path (default dist/AstralArena-<version>.pak)")
    args = parser.parse_args()

    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    stage = os.path.join(root, "build", "pak-" + args.version)
    out = args.out or os.path.join(root, "dist", f"AstralArena-{args.version}.pak")
    if os.path.exists(stage):
        shutil.rmtree(stage)
    module_stage = os.path.join(stage, "Mods", MODULE)

    toolkit_module = os.path.join(root, "toolkit", "Data", "Mods", MODULE)
    shutil.copytree(toolkit_module, module_stage)
    shutil.copytree(
        os.path.join(root, "src", "Mods", "AstralArena", "ScriptExtender"),
        os.path.join(module_stage, "ScriptExtender"),
    )
    # Editor-only scenery sources must never ship; BG3 only loads _merged.lsf.
    for kind in ("Scenery", "Lights"):
        folder = os.path.join(module_stage, "Levels", "AA_Arena_Main", kind)
        for name in os.listdir(folder):
            if name != "_merged.lsf":
                raise SystemExit(f"refusing to ship loose {kind} resource: {name}")

    loca_path = os.path.join(stage, "Localization", "English", "AstralArena_English.loca")
    os.makedirs(os.path.dirname(loca_path))
    loca.compile_loca(os.path.join(root, "src", "Localization", "English", "AstralArena_English.xml"), loca_path)

    _, entries, data = lspk.read_pak(args.assets_from)
    by_name = {entry["name"]: entry for entry in entries}
    for relative in TOOLKIT_ARTWORK:
        name = f"Mods/{MODULE}/{relative}"
        if name not in by_name:
            raise SystemExit(f"asset PAK is missing {name}")
        target = os.path.join(module_stage, *relative.split("/"))
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "wb") as handle:
            handle.write(lspk.entry_bytes(by_name[name], data))

    os.makedirs(os.path.dirname(out), exist_ok=True)
    lspk.cmd_create(stage, out)

    _, built, built_data = lspk.read_pak(out)
    names = {entry["name"] for entry in built}
    missing = [name for name in REQUIRED if name not in names]
    if missing:
        raise SystemExit("built PAK is missing: " + ", ".join(missing))
    for entry in built:
        lspk.entry_bytes(entry, built_data)  # every entry must decompress
    print(f"verified {len(built)} entries")


if __name__ == "__main__":
    main()
