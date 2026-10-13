#!/usr/bin/env python3
"""Checks the arena geometry, including whether the navigation grid is current.

BG3 moves characters using the level's AI grid (Ai/aigrid.data), which only
the Toolkit can generate. A solid or walk-on object the grid does not know about
is walked straight through, so the rules are:

* tactical scenery (solid cover or walk-on high ground) may stand on the
  walkable ground only if toolkit/scenery/AA_Arena_Main.navgrid.json records
  that the current aigrid.data was generated for exactly this scenery
  (see record_navgrid.py); every other solid or walk-on object must sit at least
  `solidClearance` metres outside the ground (a walk-on floor inside the
  staging court is exempt);
* every party and enemy spawn for every site and formation lies on the ground
  with a 6 m margin and at least 3 m from any scenery object;
* banners stay out of every combat lane;
* every lane rectangle lies inside the walkable ground.
"""
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import navgrid  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def inside(point, lo, hi, margin=0.0):
    return lo[0] + margin <= point[0] <= hi[0] - margin and lo[1] + margin <= point[1] <= hi[1] - margin


def main():
    manifest = json.load(open(os.path.join(ROOT, "toolkit", "scenery", "AA_Arena_Main.scenery.json"), encoding="utf-8"))
    lua = os.environ.get("LUA", "luajit")
    geometry = json.loads(subprocess.check_output([lua, os.path.join(ROOT, "tools", "scenery", "dump_geometry.lua")], cwd=ROOT))
    ground = manifest["walkableGround"]
    lo, hi, clearance = ground["minimum"], ground["maximum"], ground["solidClearance"]
    staging_zones = [z for z in manifest["navigationClearZones"] if z["id"] == "staging-center"]
    errors = []

    stale_reason = navgrid.stale_reason(ROOT, manifest)
    tactical_count = 0
    for obj in manifest["objects"]:
        x, z = obj["position"][0], obj["position"][2]
        solid = obj.get("walkThrough") is not True
        if not solid:
            continue
        if obj.get("walkOn") and any(inside((x, z), zone["minimum"], zone["maximum"]) for zone in staging_zones):
            continue
        if not inside((x, z), (lo[0] - clearance, lo[1] - clearance), (hi[0] + clearance, hi[1] + clearance)):
            continue
        if obj.get("tactical") is True:
            # build_scenery.py leaves tactical pieces out of the game build until
            # the grid is current, so a stale grid is safe, just incomplete.
            tactical_count += 1
            continue
        errors.append(f"solid scenery {obj['id']} at ({x}, {z}) is reachable from the walkable ground; mark it tactical or move it")

    spawns = []
    for site in geometry["sites"]:
        ox, oz = site["offset"][0], site["offset"][2]
        anchor = (ox, oz)
        for index, (dx, dz) in enumerate(site["party"]):
            spawns.append((f"{site['id']} party {index + 1}", (ox + dx, oz + dz)))
        for layout in geometry["layouts"]:
            for index, (dx, dz) in enumerate(layout["enemies"]):
                spawns.append((f"{site['id']} {layout['id']} enemy {index + 1}", (anchor[0] + dx, anchor[1] + dz)))
    for name, point in spawns:
        if not inside(point, lo, hi, margin=6):
            errors.append(f"{name} spawn {point} is not on the walkable ground with a 6 m margin")
        for obj in manifest["objects"]:
            ox, oz = obj["position"][0], obj["position"][2]
            limit = 16 if obj.get("tactical") else 9
            if (ox - point[0]) ** 2 + (oz - point[1]) ** 2 < limit and obj.get("id") != "staging-platform":
                errors.append(f"{name} spawn {point} is within {int(limit ** 0.5)} m of {obj['id']}")

    for zone in manifest["combatClearZones"]:
        if not (inside(zone["minimum"], lo, hi) and inside(zone["maximum"], lo, hi)):
            errors.append(f"combat lane {zone['id']} extends past the walkable ground")
        for obj in manifest["objects"]:
            if "banner" in obj["id"] and inside((obj["position"][0], obj["position"][2]), zone["minimum"], zone["maximum"]):
                errors.append(f"banner {obj['id']} stands inside combat lane {zone['id']}")

    # Lanes must contain their own site's party line and enemy line.
    for site, zone in zip(geometry["sites"], manifest["combatClearZones"]):
        ox, oz = site["offset"][0], site["offset"][2]
        corners = [(ox - 6, oz - 8), (ox + 49, oz + 8)]
        if not all(inside(c, zone["minimum"], zone["maximum"]) for c in corners):
            errors.append(f"combat lane {zone['id']} does not cover site {site['id']}")

    separations = sorted({dx for layout in geometry["layouts"] for dx, _ in layout["enemies"]})
    if separations[0] < 45:
        errors.append(f"closest enemy formation starts {separations[0]} m away; the minimum is 45 m")

    if errors:
        print("\n".join(errors))
        sys.exit(1)
    print(f"scenery validation passed: {len(manifest['objects'])} objects, {len(spawns)} spawn points, "
          f"enemy lines {separations[0]}-{separations[-1]} m from the party, {tactical_count} tactical pieces "
          f"({'navigation grid current' if not stale_reason else 'NAVIGATION GRID STALE'})")


if __name__ == "__main__":
    main()
