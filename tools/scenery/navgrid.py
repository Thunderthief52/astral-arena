"""Ties the level's AI grid to the exact scenery it was generated for.

The 2026 pillar bug happened because scenery changed after the AI grid was
generated and nothing noticed. The fingerprint covers every object that can
affect navigation (anything that is not walk-through) plus the terrain files.
"""
import hashlib
import json
import os
from pathlib import Path

MODULE = "AstralArenaAdventure_29c48c80-8777-f7b5-6bb8-376c1c5d8db6"
RECORD = os.path.join("toolkit", "scenery", "AA_Arena_Main.navgrid.json")


def level_dir(root):
    return os.path.join(root, "toolkit", "Data", "Mods", MODULE, "Levels", "AA_Arena_Main")


def scenery_fingerprint(manifest):
    relevant = []
    for obj in manifest["objects"]:
        if obj.get("walkThrough") is True:
            continue
        relevant.append([
            obj["id"], obj["template"], [coordinate(v) for v in obj["position"]],
            coordinate(obj.get("yaw", 0)), coordinate(obj.get("scale", 1)),
            bool(obj.get("walkOn")), bool(obj.get("decorative")), obj.get("cover", 0),
        ])
    relevant.sort()
    return hashlib.sha256(json.dumps(relevant, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


def coordinate(value):
    """Fixed decimal strings keep PowerShell/Python stamps identical."""
    value = round(float(value), 3)
    return format(value if value else 0, ".3f")


def terrain_files(root):
    level = Path(level_dir(root))
    return {
        path.relative_to(level).as_posix(): file_sha(path)
        for folder in ("Terrains", "TileConstructions")
        for path in sorted((level / folder).rglob("*")) if path.is_file()
    }


def file_sha(path):
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def text_sha(path):
    # Git may change text line endings between Windows and Linux checkouts.
    with open(path, encoding="utf-8-sig") as handle:
        return hashlib.sha256(handle.read().encode("utf-8")).hexdigest()


def aigrid_sha(root):
    return file_sha(os.path.join(level_dir(root), "Ai", "aigrid.data"))


def load_record(root):
    path = os.path.join(root, RECORD)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8-sig") as handle:
        return json.load(handle)


def stale_reason(root, manifest):
    record = load_record(root)
    if not record:
        return "no navigation grid has been recorded for this scenery"
    if record.get("formatVersion") != 2:
        return "the navigation record predates terrain-file verification"
    if record.get("sceneryFingerprint") != scenery_fingerprint(manifest):
        return "the scenery changed after the navigation grid was generated"
    if record.get("terrainFiles") != terrain_files(root):
        return "the terrain or ground construction changed after navigation generation"
    if not os.path.isfile(os.path.join(level_dir(root), "Ai", "aigrid.data")):
        return "Ai/aigrid.data is missing"
    if record.get("aigridSha256") != aigrid_sha(root):
        return "Ai/aigrid.data does not match the recorded Toolkit output"
    return None


def build_stale_reason(root):
    """Verify merged resources were compiled from this manifest, not an older one."""
    receipt_path = os.path.join(root, "toolkit", "scenery", "AA_Arena_Main.build.json")
    if not os.path.isfile(receipt_path):
        return "no scenery build receipt; rebuild merged scenery resources"
    with open(receipt_path, encoding="utf-8-sig") as handle:
        receipt = json.load(handle)
    expected = {
        "manifestSha256": os.path.join(root, "toolkit", "scenery", "AA_Arena_Main.scenery.json"),
        "scenerySha256": os.path.join(level_dir(root), "Scenery", "_merged.lsf"),
        "lightsSha256": os.path.join(level_dir(root), "Lights", "_merged.lsf"),
        "minimapSourceSha256": os.path.join(root, "toolkit", "levels", "AA_Arena_Main.minimap.lsx"),
        "minimapSha256": os.path.join(level_dir(root), "WorldMap", "MiniMap.lsf"),
    }
    for key, path in expected.items():
        digest = text_sha if key in ("manifestSha256", "minimapSourceSha256") else file_sha
        if not os.path.isfile(path) or receipt.get(key) != digest(path):
            return f"scenery build receipt mismatch: {key}; rebuild merged scenery resources"
    return None
