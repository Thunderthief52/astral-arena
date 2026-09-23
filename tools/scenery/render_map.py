#!/usr/bin/env python3
"""Renders a labelled top-down map of AA_Arena_Main from the scenery manifest."""
import json
import os
import subprocess
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "arena-map.png")
manifest = json.load(open(os.path.join(ROOT, "toolkit", "scenery", "AA_Arena_Main.scenery.json")))
geometry = json.loads(subprocess.check_output(["luajit", os.path.join(ROOT, "tools", "scenery", "dump_geometry.lua")], cwd=ROOT))

INK, MUTED, SURFACE = "#0b0b0b", "#52514e", "#fcfcfb"
GROUND, PARTY, ENEMY, SOLID, SOFT = "#e9e6dc", "#2a78d6", "#eb6834", "#4a3aa7", "#1baf7a"

fig, ax = plt.subplots(figsize=(11, 10.5), dpi=130)
fig.patch.set_facecolor(SURFACE)
ax.set_facecolor(SURFACE)
lo, hi = manifest["walkableGround"]["minimum"], manifest["walkableGround"]["maximum"]
ax.add_patch(Rectangle(lo, hi[0] - lo[0], hi[1] - lo[1], facecolor=GROUND, edgecolor=MUTED, linewidth=1.5, zorder=0))
ax.text(lo[0] + 2, hi[1] - 4, "Walkable ground (flat) 199 m × 185 m", color=MUTED, fontsize=9, va="top")

for zone, label in zip(manifest["combatClearZones"], ["Astral Flats (L3, L5)", "Crescent Ruin (L8)", "Echelon Steps (L10, L12)"]):
    (x0, z0), (x1, z1) = zone["minimum"], zone["maximum"]
    ax.add_patch(Rectangle((x0, z0), x1 - x0, z1 - z0, facecolor="none", edgecolor=MUTED, linestyle=(0, (4, 3)), linewidth=1, zorder=1))
    ax.text((x0 + x1) / 2, z1 + 2.5, label, ha="center", va="bottom", fontsize=10, color=INK, weight="bold")

for site in geometry["sites"]:
    ox, oz = site["offset"][0], site["offset"][2]
    ax.scatter([ox + dx for dx, _ in site["party"]], [oz + dz for _, dz in site["party"]], s=55, color=PARTY, edgecolor=SURFACE, linewidth=1.5, zorder=4)
    ex = [ox + dx for layout in geometry["layouts"] for dx, _ in layout["enemies"]]
    ez = [oz + dz for layout in geometry["layouts"] for _, dz in layout["enemies"]]
    ax.scatter(ex, ez, s=18, color=ENEMY, alpha=0.55, linewidth=0, zorder=3)
    ax.annotate("", xy=(ox + 44, oz), xytext=(ox + 2, oz), arrowprops=dict(arrowstyle="<->", color=MUTED, lw=1), zorder=2)
    ax.text(ox + 23, oz + 1.5, "45–49 m", ha="center", fontsize=8, color=MUTED)

for obj in manifest["objects"]:
    x, z = obj["position"][0], obj["position"][2]
    solid = obj.get("walkThrough") is not True
    if obj["id"] == "staging-platform":
        ax.scatter([x], [z], s=260, facecolor="none", edgecolor=MUTED, linewidth=1, zorder=2)
    elif solid:
        ax.scatter([x], [z], s=30, marker="s", color=SOLID, zorder=2)
    else:
        ax.scatter([x], [z], s=14, marker="^", color=SOFT, zorder=2)
ax.text(3, -6, "Staging court\n(start here)", ha="center", va="top", fontsize=9, color=INK)

from matplotlib.lines import Line2D
handles = [
    Line2D([], [], marker="o", color=PARTY, linestyle="", markersize=7, label="Your party start"),
    Line2D([], [], marker="o", color=ENEMY, linestyle="", markersize=6, alpha=0.6, label="Possible enemy starts (12 formations)"),
    Line2D([], [], marker="s", color=SOLID, linestyle="", markersize=6, label="Solid ruins, cliffs, statues (backdrop, unreachable)"),
    Line2D([], [], marker="^", color=SOFT, linestyle="", markersize=6, label="Grass and banners (walk-through dressing)"),
]
ax.legend(handles=handles, loc="upper center", bbox_to_anchor=(0.5, -0.05), ncol=2, frameon=False, fontsize=9, labelcolor=MUTED)
ax.set_xlim(-128, 128); ax.set_ylim(-104, 112)
ax.set_aspect("equal")
ax.set_xticks([]); ax.set_yticks([])
for spine in ax.spines.values():
    spine.set_visible(False)
ax.set_title("Astral Arena — top-down map (0.4.0-alpha.2)", color=INK, fontsize=13, loc="left")
fig.tight_layout()
fig.savefig(out, facecolor=SURFACE)
print(out)
