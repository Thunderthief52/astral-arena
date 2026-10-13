#!/usr/bin/env python3
"""Cross-platform port of scripts/Build-ArenaScenery.ps1.

Reads toolkit/scenery/AA_Arena_Main.scenery.json and writes the engine-loaded
Scenery/_merged.lsf and Lights/_merged.lsf resources. The LSX text is produced
exactly as the PowerShell builder does; LSLib (via the small `conv` .NET tool in
this folder) converts it to LSF.

    python3 tools/scenery/build_scenery.py --conv <path to conv.dll>
"""
import argparse
import hashlib
import json
import math
import os
import subprocess
import sys
import uuid
from xml.sax.saxutils import quoteattr

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import navgrid  # noqa: E402

MODULE = "AstralArenaAdventure_29c48c80-8777-f7b5-6bb8-376c1c5d8db6"
NAMESPACE = uuid.UUID("29c48c80-8777-f7b5-6bb8-376c1c5d8db6")
POINT_LIGHT_TEMPLATE = "ae8105f5-0490-4d85-9ef7-b6beeedea3a3"


def deterministic_guid(name):
    data = NAMESPACE.bytes_le + ("AA_Arena_Main/" + name).encode("utf-8")
    digest = bytearray(hashlib.sha1(data).digest()[:16])
    digest[7] = (digest[7] & 0x0F) | 0x50
    digest[8] = (digest[8] & 0x3F) | 0x80
    return str(uuid.UUID(bytes_le=bytes(digest)))


def invariant(value):
    if isinstance(value, bool):
        raise TypeError("bool is not a number")
    if isinstance(value, int):
        return str(value)
    if float(value).is_integer() and abs(value) < 1e15:
        return str(int(value))
    return repr(float(value))


def yaw_quaternion(degrees):
    half = float(degrees) * math.pi / 360.0
    return " ".join(["0", invariant(math.sin(half)), "0", invariant(math.cos(half))])


class Writer:
    def __init__(self):
        self.lines = []
        self.depth = 0

    def open(self, node_id, key=None):
        extra = f' key="{key}"' if key else ""
        self.lines.append("\t" * self.depth + f'<node id="{node_id}"{extra}>')
        self.depth += 1

    def close(self):
        self.depth -= 1
        self.lines.append("\t" * self.depth + "</node>")

    def children(self):
        self.lines.append("\t" * self.depth + "<children>")
        self.depth += 1

    def end_children(self):
        self.depth -= 1
        self.lines.append("\t" * self.depth + "</children>")

    def attr(self, attr_id, attr_type, value):
        self.lines.append("\t" * self.depth + f'<attribute id="{attr_id}" type="{attr_type}" value={quoteattr(str(value))} />')


def layer_list(w, level, layer):
    w.open("LayerList"); w.children()
    w.open("Layers"); w.children()
    w.open("Object", key="MapKey")
    w.attr("MapKey", "FixedString", level)
    w.children()
    w.open("Layer"); w.attr("Object", "guid", layer); w.close()
    w.end_children(); w.close()
    w.end_children(); w.close()
    w.end_children(); w.close()


def transform(w, position, rotation="0 0 0 1", scale=1.0):
    w.open("Transform")
    w.attr("Scale", "float", invariant(scale))
    w.attr("Position", "fvec3", " ".join(invariant(v) for v in position))
    w.attr("RotationQuat", "fvec4", rotation)
    w.close()


def merged_lsx(write_objects):
    w = Writer()
    w.depth = 3
    write_objects(w)
    body = "\n".join(w.lines)
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n<save>\n'
        '\t<version major="4" minor="8" revision="0" build="500" lslib_meta="v1,bswap_guids,lsf_keys_adjacency" />\n'
        '\t<region id="Templates">\n\t\t<node id="Templates">\n\t\t\t<children>\n'
        + body + "\n\t\t\t</children>\n\t\t</node>\n\t</region>\n</save>\n"
    )


def scenery_objects(manifest):
    def write(w):
        for obj in manifest["objects"]:
            walk_through = obj.get("walkThrough") is True
            walk_on = obj.get("walkOn") is True
            decorative = obj.get("decorative") is True
            w.open("GameObjects")
            w.attr("MapKey", "FixedString", deterministic_guid("scenery/" + obj["id"]))
            w.attr("Name", "LSString", obj["name"])
            w.attr("LevelName", "FixedString", manifest["levelName"])
            w.attr("Type", "FixedString", "scenery")
            w.attr("TemplateName", "FixedString", obj["template"])
            # Toolkit-authored scenery serializes Flag as uint8; int32 makes BG3 discard it.
            w.attr("Flag", "uint8", "1")
            w.attr("CanClickThrough", "bool", "True" if (walk_through or decorative) else "False")
            if obj.get("cover") is not None:
                w.attr("CoverAmount", "uint8", str(obj["cover"]))
            w.attr("WalkOn", "bool", "True" if walk_on else "False")
            w.attr("WalkThrough", "bool", "True" if walk_through else "False")
            w.attr("IsDecorative", "bool", "True" if decorative else "False")
            w.attr("_OriginalFileVersion_", "int64", "144115207403209026")
            w.children()
            transform(w, obj["position"], yaw_quaternion(obj.get("yaw", 0)), obj.get("scale", 1.0))
            layer_list(w, manifest["levelName"], manifest["sceneryLayer"])
            w.end_children()
            w.close()
    return write


def light_objects(manifest):
    def write(w):
        for light in manifest["lights"]:
            w.open("GameObjects")
            w.attr("Enabled", "bool", "True")
            w.attr("Flag", "int32", "1")
            w.attr("Color", "fvec3", " ".join(invariant(v) for v in light["color"]))
            w.attr("Gain", "float", invariant(light["gain"]))
            w.attr("Intensity", "float", invariant(light["intensity"]))
            w.attr("Radius", "float", invariant(light["radius"]))
            w.attr("ScatteringScale", "float", invariant(light["scattering"]))
            w.attr("LevelName", "FixedString", manifest["levelName"])
            w.attr("MapKey", "FixedString", deterministic_guid("light/" + light["id"]))
            w.attr("Name", "LSString", light["name"])
            w.attr("TemplateName", "FixedString", POINT_LIGHT_TEMPLATE)
            w.attr("Type", "FixedString", "light")
            w.attr("_OriginalFileVersion_", "int64", "144115207403209014")
            w.children()
            layer_list(w, manifest["levelName"], manifest["lightingLayer"])
            transform(w, light["position"])
            w.end_children()
            w.close()
    return write


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--conv", required=True, help="path to the built conv.dll (LSLib converter)")
    parser.add_argument("--lsx-only", action="store_true")
    parser.add_argument("--per-object", metavar="DIR",
                        help="also write Toolkit editor files (one <MapKey>.lsf per object) under DIR/Scenery and DIR/Lights")
    args = parser.parse_args()
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    manifest = json.load(open(os.path.join(root, "toolkit", "scenery", "AA_Arena_Main.scenery.json"), encoding="utf-8"))
    for collection in ("objects", "lights"):
        ids = [entry["id"] for entry in manifest[collection]]
        names = [entry["name"] for entry in manifest[collection]]
        if len(set(ids)) != len(ids) or len(set(names)) != len(names):
            raise SystemExit(f"duplicate {collection} id or name in the scenery manifest")
    level_root = os.path.join(root, "toolkit", "Data", "Mods", MODULE, "Levels", manifest["levelName"])
    # Tactical cover only ships to the game once the AI grid was rebuilt for it;
    # otherwise characters would walk straight through it again.
    game_manifest = dict(manifest)
    stale = navgrid.stale_reason(root, manifest)
    if stale:
        held = [obj["id"] for obj in manifest["objects"] if obj.get("tactical")]
        game_manifest["objects"] = [obj for obj in manifest["objects"] if not obj.get("tactical")]
        if held:
            print(f"holding back {len(held)} tactical pieces from the game build: {stale}")
    for folder, writer in (("Scenery", scenery_objects(game_manifest)), ("Lights", light_objects(game_manifest))):
        out_dir = os.path.join(level_root, folder)
        os.makedirs(out_dir, exist_ok=True)
        lsx = os.path.join(out_dir, "_merged.lsx")
        with open(lsx, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(merged_lsx(writer))
        if args.lsx_only:
            continue
        subprocess.run(["dotnet", args.conv, lsx, os.path.join(out_dir, "_merged.lsf")], check=True)
        os.remove(lsx)
    if args.per_object:
        write_per_object(manifest, args.per_object, args.conv)
    print(f"built {len(manifest['objects'])} scenery objects and {len(manifest['lights'])} lights")


def write_per_object(manifest, out_root, conv):
    """The Toolkit editor loads one file per object; the game loads _merged.lsf."""
    jobs = []
    for folder, collection, prefix, builder in (
        ("Scenery", "objects", "scenery/", scenery_objects),
        ("Lights", "lights", "light/", light_objects),
    ):
        out_dir = os.path.join(out_root, folder)
        os.makedirs(out_dir, exist_ok=True)
        for entry in manifest[collection]:
            single = dict(manifest)
            single[collection] = [entry]
            key = deterministic_guid(prefix + entry["id"])
            lsx = os.path.join(out_dir, key + ".lsx")
            with open(lsx, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(merged_lsx(builder(single)))
            jobs.append((lsx, os.path.join(out_dir, key + ".lsf")))
    for lsx, lsf in jobs:
        subprocess.run(["dotnet", conv, lsx, lsf], check=True, stdout=subprocess.DEVNULL)
        os.remove(lsx)
    print(f"wrote {len(jobs)} Toolkit editor files under {out_root}")


if __name__ == "__main__":
    main()
