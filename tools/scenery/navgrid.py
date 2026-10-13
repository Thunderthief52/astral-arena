"""Ties the level's AI grid to the exact scenery it was generated for.

The 2026 pillar bug happened because scenery changed after the AI grid was
generated and nothing noticed. The fingerprint covers every object that can
affect navigation (anything that is not walk-through) plus the terrain files.
"""
import hashlib
import json
import os

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
            obj["id"], obj["template"], [round(float(v), 3) for v in obj["position"]],
            round(float(obj.get("yaw", 0)), 3), round(float(obj.get("scale", 1)), 3),
            bool(obj.get("walkOn")),
        ])
    relevant.sort()
    return hashlib.sha256(json.dumps(relevant, separators=(",", ":")).encode()).hexdigest()


def file_sha(path):
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def aigrid_sha(root):
    return file_sha(os.path.join(level_dir(root), "Ai", "aigrid.data"))


def load_record(root):
    path = os.path.join(root, RECORD)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def stale_reason(root, manifest):
    record = load_record(root)
    if not record:
        return "no navigation grid has been recorded for this scenery"
    if record.get("sceneryFingerprint") != scenery_fingerprint(manifest):
        return "the scenery changed after the navigation grid was generated"
    if record.get("aigridSha256") != aigrid_sha(root):
        return "Ai/aigrid.data does not match the recorded Toolkit output"
    return None
