#!/usr/bin/env python3
"""Record that the current Ai/aigrid.data was regenerated in the BG3 Toolkit
for the current scenery manifest. Run only after a Toolkit AI grid rebuild."""
import datetime
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import navgrid  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
manifest = json.load(open(os.path.join(ROOT, "toolkit", "scenery", "AA_Arena_Main.scenery.json"), encoding="utf-8"))
record = {
    "sceneryFingerprint": navgrid.scenery_fingerprint(manifest),
    "aigridSha256": navgrid.aigrid_sha(ROOT),
    "aigridBytes": os.path.getsize(os.path.join(navgrid.level_dir(ROOT), "Ai", "aigrid.data")),
    "recordedUtc": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
    "note": " ".join(sys.argv[1:]) or "regenerated in the BG3 Toolkit",
}
with open(os.path.join(ROOT, navgrid.RECORD), "w", encoding="utf-8") as handle:
    json.dump(record, handle, indent=2)
    handle.write("\n")
print(json.dumps(record, indent=2))
