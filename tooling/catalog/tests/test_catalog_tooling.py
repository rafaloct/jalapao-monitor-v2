"""Testes isolados das ferramentas do catálogo editorial (issue #64).

Sem rede, sem backend, sem dados reais: usa o dataset versionado e fixtures
sintéticas. Rodar: python3 -m unittest discover -s tooling/catalog/tests -v
"""
import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOOLING = ROOT / "tooling" / "catalog"
DATASET_DIR = ROOT / "data" / "catalog" / "jalapao_serras_2026"
FIXTURES = Path(__file__).resolve().parent / "fixtures"
sys.path.insert(0, str(TOOLING))

import build_review_dataset  # noqa: E402
import reconcile_places  # noqa: E402
import validate_catalog  # noqa: E402

DATASET = json.loads((DATASET_DIR / "catalog_review_v1.json").read_text())
RECORDS = DATASET["records"]


def run_tool(script, *args):
    return subprocess.run(
        [sys.executable, str(TOOLING / script), *args],
        capture_output=True, text=True, cwd=ROOT,
    )


class TestDatasetIntegrity(unittest.TestCase):
    def test_80_records_unique_keys(self):
        keys = [r["external_key"] for r in RECORDS]
        self.assertEqual(len(keys), 80)
        self.assertEqual(len(set(keys)), 80)

    def test_map_numbers_1_to_62(self):
        nums = sorted(r["map_number"] for r in RECORDS if r["map_number"] is not None)
        self.assertEqual(nums, list(range(1, 63)))

    def test_all_draft_no_operational_data(self):
        for r in RECORDS:
            self.assertEqual(r["editorial_state"], "draft")
            self.assertIsNone(r["operational_binding"])
            self.assertIsNone(r["visit_authorized"])
            self.assertIsNone(r["location"]["latitude"])
            self.assertIsNone(r["location"]["longitude"])
            self.assertIsNone(r["location"]["google_place_id"])

    def test_photo_rights_explicit(self):
        licensed = [r for r in RECORDS if r["media"]["photo_status"] == "foto_licenciada"]
        self.assertEqual(len(licensed), 16)
        for r in licensed:
            photo = r["media"]["photo"]
            for field in ("author", "license", "url"):
                self.assertTrue(photo.get(field), f"{r['external_key']} sem {field}")
        pending = [r for r in RECORDS if r["media"]["photo_status"] == "galeria_institucional_uso_pendente"]
        self.assertEqual(len(pending), 5)
        for r in pending:
            self.assertIsNone(r["media"]["photo"])

    def test_source_sha256_preserved(self):
        self.assertEqual(
            DATASET["generated_from"]["sha256"],
            "8000419b79b040b7c934a4eb059d7991f4878ad85290db29336ef741272d5a23",
        )

    def test_jsonl_parity(self):
        lines = (DATASET_DIR / "catalog_review_v1.jsonl").read_text().splitlines()
        self.assertEqual(len(lines), 80)
        for i, line in enumerate(lines):
            self.assertEqual(json.loads(line), RECORDS[i])


class TestValidator(unittest.TestCase):
    def test_real_dataset_passes(self):
        r = run_tool("validate_catalog.py")
        self.assertEqual(r.returncode, 0, r.stderr)

    def _tampered(self, mutate):
        dataset = copy.deepcopy(DATASET)
        mutate(dataset)
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            json.dump(dataset, f, ensure_ascii=False)
            return f.name

    def _assert_fails(self, dataset_path):
        r = run_tool("validate_catalog.py", "--dataset", dataset_path)
        self.assertEqual(r.returncode, 1)
        self.assertIn("bloqueado", r.stderr)

    def test_fails_on_non_draft(self):
        self._assert_fails(self._tampered(lambda d: d["records"][0].update(editorial_state="published")))

    def test_fails_on_operational_binding(self):
        self._assert_fails(
            self._tampered(lambda d: d["records"][0].update(operational_binding={"place_id": "x"}))
        )

    def test_fails_on_unverified_coordinates(self):
        self._assert_fails(
            self._tampered(lambda d: d["records"][0]["location"].update(latitude=-10.5, longitude=-46.1))
        )

    def test_fails_on_photo_without_review(self):
        def mutate(d):
            r = next(x for x in d["records"] if x["media"]["photo_status"] == "galeria_institucional_uso_pendente")
            r["media"]["photo"] = {"url": "https://example.invalid/x.jpg", "author": None, "license": None}
        self._assert_fails(self._tampered(mutate))

    def test_fails_on_extra_field_closed_schema(self):
        self._assert_fails(self._tampered(lambda d: d["records"][0].update(publish_now=True)))

    def test_fails_on_duplicate_key(self):
        self._assert_fails(self._tampered(lambda d: d["records"][1].update(external_key=d["records"][0]["external_key"])))

    def test_no_apply_option(self):
        r = run_tool("validate_catalog.py", "--apply")
        self.assertNotEqual(r.returncode, 0)


class TestReconciler(unittest.TestCase):
    def test_candidates_synthetic(self):
        places = reconcile_places.load_places(str(FIXTURES / "places_export_sanitized.json"))
        cands = reconcile_places.reconcile(RECORDS, places)
        by_place = {c["place_id"]: c for c in cands}
        self.assertIn("pl-sintetico-1", by_place)  # match exato por alias canônico
        self.assertIn("pl-sintetico-2", by_place)  # 'Dunas' -> 'Dunas do Jalapão'
        self.assertNotIn("pl-sintetico-4", by_place)
        for c in cands:
            self.assertEqual(c["action"], "manual_review_required")

    def test_rejects_export_with_extra_fields(self):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            json.dump([{"id": "x", "name": "y", "status": "active", "owner_name": "PII"}], f)
            path = f.name
        with self.assertRaises(ValueError):
            reconcile_places.load_places(path)

    def test_read_only_no_writes(self):
        fixture = FIXTURES / "places_export_sanitized.json"
        before = fixture.read_bytes()
        r = run_tool("reconcile_places.py", str(fixture))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(fixture.read_bytes(), before)
        report = json.loads(r.stdout)
        self.assertIn("verificação manual", report["disclaimer"])

    def test_no_apply_option(self):
        r = run_tool("reconcile_places.py", str(FIXTURES / "places_export_sanitized.json"), "--apply")
        self.assertNotEqual(r.returncode, 0)


class TestBuilder(unittest.TestCase):
    def test_no_apply_option(self):
        r = run_tool("build_review_dataset.py", "--apply")
        self.assertNotEqual(r.returncode, 0)

    def test_sha_guard(self):
        self.assertEqual(build_review_dataset.EXPECTED_SHA256, DATASET["generated_from"]["sha256"])


if __name__ == "__main__":
    unittest.main()
