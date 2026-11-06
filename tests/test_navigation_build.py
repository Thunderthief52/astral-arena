"""Run with python -m unittest discover -s tests -p test_navigation_build.py."""
import copy
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools" / "scenery"))
import navgrid


class NavigationBuildTests(unittest.TestCase):
    def setUp(self):
        scratch = REPO / "build"
        scratch.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=scratch, prefix="nav-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.level = Path(navgrid.level_dir(self.root))
        self.manifest = {"objects": [{
            "id": "stairs", "template": "template", "position": [39.5, 0, -51],
            "yaw": 0, "scale": 1.0, "walkOn": True, "cover": 0,
        }]}
        self.manifest_path = self.root / "toolkit/scenery/AA_Arena_Main.scenery.json"
        self.manifest_path.parent.mkdir(parents=True)
        self.manifest_path.write_text(json.dumps(self.manifest))
        for name in ("Ai/aigrid.data", "Terrains/ground.data", "TileConstructions/floor.lsf", "Scenery/_merged.lsf", "Lights/_merged.lsf"):
            path = self.level / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"fixture " + name.encode())
        self.record_path = self.root / navgrid.RECORD
        self.record_path.write_text(json.dumps({
            "formatVersion": 2,
            "sceneryFingerprint": navgrid.scenery_fingerprint(self.manifest),
            "terrainFiles": navgrid.terrain_files(self.root),
            "aigridSha256": navgrid.aigrid_sha(self.root),
        }))
        self.receipt_path = self.manifest_path.with_name("AA_Arena_Main.build.json")
        self.receipt_path.write_text(json.dumps({
            "manifestSha256": navgrid.text_sha(self.manifest_path),
            "scenerySha256": navgrid.file_sha(self.level / "Scenery/_merged.lsf"),
            "lightsSha256": navgrid.file_sha(self.level / "Lights/_merged.lsf"),
        }))

    def test_unchanged_bake_and_compilation_are_current(self):
        self.assertIsNone(navgrid.stale_reason(self.root, self.manifest))
        self.assertIsNone(navgrid.build_stale_reason(self.root))

    def test_all_collision_affecting_object_changes_require_a_new_bake(self):
        for key, value in {
            "position": [39.5, 2.7, -43.5], "yaw": 180, "scale": 1.2,
            "walkOn": False, "walkThrough": True, "decorative": True,
            "cover": 1, "template": "replacement",
        }.items():
            with self.subTest(key=key):
                changed = copy.deepcopy(self.manifest)
                changed["objects"][0][key] = value
                self.assertIn("scenery changed", navgrid.stale_reason(self.root, changed))

    def test_ground_mutation_and_added_or_removed_files_invalidate_the_bake(self):
        ground = self.level / "Terrains/ground.data"
        original = ground.read_bytes()
        ground.write_bytes(b"modified ground")
        self.assertIn("terrain or ground", navgrid.stale_reason(self.root, self.manifest))
        ground.write_bytes(original)
        added = self.level / "Terrains/extra.data"
        added.write_bytes(b"new ground")
        self.assertIn("terrain or ground", navgrid.stale_reason(self.root, self.manifest))
        added.unlink()
        ground.unlink()
        self.assertIn("terrain or ground", navgrid.stale_reason(self.root, self.manifest))

    def test_replaced_or_missing_grid_is_rejected(self):
        grid = self.level / "Ai/aigrid.data"
        grid.write_bytes(b"other bake")
        self.assertIn("does not match", navgrid.stale_reason(self.root, self.manifest))
        grid.unlink()
        self.assertIn("missing", navgrid.stale_reason(self.root, self.manifest))

    def test_old_or_missing_records_are_rejected(self):
        record = json.loads(self.record_path.read_text())
        del record["formatVersion"]
        self.record_path.write_text(json.dumps(record))
        self.assertIn("predates", navgrid.stale_reason(self.root, self.manifest))
        self.record_path.unlink()
        self.assertIn("no navigation grid", navgrid.stale_reason(self.root, self.manifest))

    def test_stale_merged_resources_and_manifest_are_rejected(self):
        for target in (self.manifest_path, self.level / "Scenery/_merged.lsf", self.level / "Lights/_merged.lsf"):
            with self.subTest(target=target.name):
                original = target.read_bytes()
                target.write_bytes(original + b" changed")
                self.assertIn("mismatch", navgrid.build_stale_reason(self.root))
                target.write_bytes(original)
        self.receipt_path.unlink()
        self.assertIn("no scenery build receipt", navgrid.build_stale_reason(self.root))

    def test_text_checkout_line_endings_do_not_invalidate_compiled_scenery(self):
        self.manifest_path.write_bytes((json.dumps(self.manifest) + "\n").encode())
        lf_hash = navgrid.text_sha(self.manifest_path)
        self.manifest_path.write_bytes(self.manifest_path.read_bytes().replace(b"\n", b"\r\n"))
        self.assertEqual(lf_hash, navgrid.text_sha(self.manifest_path))

    def test_windows_guard_matches_python_and_rejects_stale_inputs(self):
        shell = shutil.which("pwsh") or shutil.which("powershell")
        if not shell:
            self.skipTest("PowerShell is unavailable")
        result = subprocess.run([
            shell, "-NoProfile", "-File", str(REPO / "tests/navigation_build_spec.ps1"),
            "-RepositoryRoot", str(self.root),
            "-ExpectedFingerprint", navgrid.scenery_fingerprint(self.manifest),
        ], capture_output=True, text=True)
        if "running scripts is disabled" in result.stderr:
            self.skipTest("Windows script execution policy blocks the PowerShell test")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
