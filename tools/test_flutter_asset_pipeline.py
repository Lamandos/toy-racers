#!/usr/bin/env python3
"""Tests for the deterministic Flutter asset pipeline."""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from flutter_asset_pipeline import (
    ASSET_BLOCK_END,
    ASSET_BLOCK_START,
    CHECKSUM_MANIFEST,
    AssetPipelineError,
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
            self.assertEqual(
                (flutter_assets / "metadata" / CHECKSUM_MANIFEST).read_bytes(),
                b"nested manifest",
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

    def test_sync_replaces_empty_directory_conflict(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository_root = Path(temporary_directory)
            self._write_sources(repository_root)
            source = repository_root / "assets" / "ui" / "icon"
            source.parent.mkdir()
            source.write_bytes(b"icon")

            conflicting_directory = repository_root / "dart" / "assets" / "ui" / "icon"
            conflicting_directory.mkdir(parents=True)
            (conflicting_directory / "old.png").write_bytes(b"stale")

            pipeline = FlutterAssetPipeline(repository_root)
            pipeline.sync()

            self.assertEqual((conflicting_directory).read_bytes(), b"icon")
            self.assertFalse((conflicting_directory / "old.png").exists())
            self.assertEqual(pipeline.parity_problems(), [])

    def test_expected_pubspec_quotes_yaml_significant_asset_paths(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository_root = Path(temporary_directory)
            self._write_sources(repository_root)
            assets = repository_root / "assets"
            (assets / "player #1.png").write_bytes(b"hash")
            (assets / "player: one.png").write_bytes(b"mapping")
            (assets / 'player "one".png').write_bytes(b"quoted")

            pipeline = FlutterAssetPipeline(repository_root)
            pipeline.sync()
            pubspec = (repository_root / "dart" / "pubspec.yaml").read_text()

            self.assertIn('    - "assets/player #1.png"', pubspec)
            self.assertIn('    - "assets/player: one.png"', pubspec)
            self.assertIn('    - "assets/player \\"one\\".png"', pubspec)
            self.assertEqual(pipeline.parity_problems(), [])

    def test_check_staged_detects_partially_staged_asset_pipeline(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository_root = Path(temporary_directory)
            self._write_sources(repository_root)
            pipeline = FlutterAssetPipeline(repository_root)
            pipeline.sync()

            subprocess.run(["git", "init"], cwd=repository_root, check=True, capture_output=True)
            subprocess.run(["git", "add", "-A"], cwd=repository_root, check=True)
            source = repository_root / "assets" / "sprites" / "cars" / "red.png"
            source.write_bytes(b"staged source differs")
            pipeline.sync()
            subprocess.run(
                ["git", "add", "assets/sprites/cars/red.png"],
                cwd=repository_root,
                check=True,
            )

            self.assertTrue(pipeline.check())
            self.assertFalse(pipeline.check_staged())

    def test_sync_rejects_file_prefix_of_attribution_destination(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository_root = Path(temporary_directory)
            self._write_sources(repository_root)
            (repository_root / "assets" / "attribution").write_bytes(b"conflict")

            with self.assertRaisesRegex(AssetPipelineError, "generated asset paths collide"):
                FlutterAssetPipeline(repository_root).sync()

    def test_sync_rejects_manifest_directory_prefix(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository_root = Path(temporary_directory)
            self._write_sources(repository_root)
            conflicting_asset = (
                repository_root / "assets" / CHECKSUM_MANIFEST / "nested.bin"
            )
            conflicting_asset.parent.mkdir(parents=True)
            conflicting_asset.write_bytes(b"conflict")

            with self.assertRaisesRegex(AssetPipelineError, "generated asset paths collide"):
                FlutterAssetPipeline(repository_root).sync()

    def test_sync_rejects_case_insensitive_generated_path_collisions(self) -> None:
        cases = (
            (Path("Flutter_Asset_Manifest.json"), b"conflict"),
            (Path("attribution") / "sources.md", b"conflict"),
        )
        for relative_path, content in cases:
            with self.subTest(relative_path=relative_path):
                with tempfile.TemporaryDirectory() as temporary_directory:
                    repository_root = Path(temporary_directory)
                    self._write_sources(repository_root)
                    conflicting_asset = repository_root / "assets" / relative_path
                    conflicting_asset.parent.mkdir(parents=True, exist_ok=True)
                    conflicting_asset.write_bytes(content)

                    with self.assertRaisesRegex(
                        AssetPipelineError, "generated asset paths collide"
                    ):
                        FlutterAssetPipeline(repository_root).sync()

    @staticmethod
    def _write_sources(repository_root: Path) -> None:
        assets = repository_root / "assets"
        car = assets / "sprites" / "cars" / "red.png"
        car.parent.mkdir(parents=True)
        car.write_bytes(b"red-car")
        (assets / "tracks").mkdir()
        (assets / "tracks" / "track_01.tmx").write_text("<map />\n")
        nested_manifest = assets / "metadata" / CHECKSUM_MANIFEST
        nested_manifest.parent.mkdir()
        nested_manifest.write_bytes(b"nested manifest")
        (repository_root / "SOURCES.md").write_text("audio attribution\n")
        dart = repository_root / "dart"
        dart.mkdir()
        (dart / "pubspec.yaml").write_text(
            "flutter:\n  assets:\n"
            f"{ASSET_BLOCK_START}\n{ASSET_BLOCK_END}\n",
        )


if __name__ == "__main__":
    unittest.main()
