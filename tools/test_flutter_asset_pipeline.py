#!/usr/bin/env python3
"""Tests for the deterministic Flutter asset pipeline."""

import json
import tempfile
import unittest
from pathlib import Path

from flutter_asset_pipeline import (
    ASSET_BLOCK_END,
    ASSET_BLOCK_START,
    CHECKSUM_MANIFEST,
    FlutterAssetPipeline,
)


class FlutterAssetPipelineTest(unittest.TestCase):
    def test_sync_materializes_sources_and_detects_parity_changes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository_root = Path(temporary_directory)
            self._write_sources(repository_root)
            pipeline = FlutterAssetPipeline(repository_root)

            pipeline.sync()

            flutter_assets = repository_root / "dart" / "assets"
            self.assertEqual(
                (flutter_assets / "sprites" / "cars" / "red.png").read_bytes(),
                b"red-car",
            )
            self.assertEqual(
                (flutter_assets / "attribution" / "SOURCES.md").read_text(),
                "audio attribution\n",
            )
            manifest = json.loads((flutter_assets / CHECKSUM_MANIFEST).read_text())
            self.assertEqual(manifest["schemaVersion"], 1)
            self.assertEqual(
                manifest["files"][0]["source"], "SOURCES.md",
            )
            self.assertEqual(pipeline.parity_problems(), [])

            (flutter_assets / "sprites" / "cars" / "red.png").write_bytes(b"modified")
            (flutter_assets / "obsolete.bin").write_bytes(b"obsolete")
            problems = pipeline.parity_problems()

            self.assertIn("SHA-256 mismatch: sprites/cars/red.png", problems)
            self.assertIn("unexpected Flutter asset: obsolete.bin", problems)

            pipeline.sync()
            self.assertEqual(pipeline.parity_problems(), [])

    @staticmethod
    def _write_sources(repository_root: Path) -> None:
        assets = repository_root / "assets"
        car = assets / "sprites" / "cars" / "red.png"
        car.parent.mkdir(parents=True)
        car.write_bytes(b"red-car")
        (assets / "tracks").mkdir()
        (assets / "tracks" / "track_01.tmx").write_text("<map />\n")
        (repository_root / "SOURCES.md").write_text("audio attribution\n")
        dart = repository_root / "dart"
        dart.mkdir()
        (dart / "pubspec.yaml").write_text(
            "flutter:\n  assets:\n"
            f"{ASSET_BLOCK_START}\n{ASSET_BLOCK_END}\n",
        )


if __name__ == "__main__":
    unittest.main()
