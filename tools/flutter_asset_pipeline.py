#!/usr/bin/env python3
"""Materialize and verify the Flutter mirror of Toy Racers runtime assets."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from tempfile import TemporaryDirectory

ASSET_BLOCK_START = "    # BEGIN GENERATED FLUTTER ASSETS"
ASSET_BLOCK_END = "    # END GENERATED FLUTTER ASSETS"
CHECKSUM_MANIFEST = "flutter_asset_manifest.json"
ATTRIBUTION_SOURCE = "SOURCES.md"
ATTRIBUTION_DESTINATION = PurePosixPath("attribution/SOURCES.md")


class AssetPipelineError(Exception):
    """Raised when the generated Flutter asset mirror is not safe to update."""


@dataclass(frozen=True)
class AssetEntry:
    """A source file and its path in the Flutter asset mirror."""

    source: Path
    source_path: str
    destination: PurePosixPath


class FlutterAssetPipeline:
    """Maintains `dart/assets` as a generated mirror of canonical assets."""

    def __init__(self, repository_root: Path) -> None:
        self.repository_root = repository_root.resolve()
        self.canonical_assets = self.repository_root / "assets"
        self.flutter_project = self.repository_root / "dart"
        self.flutter_assets = self.flutter_project / "assets"
        self.pubspec = self.flutter_project / "pubspec.yaml"

    def sync(self) -> None:
        """Copy canonical files, remove stale generated files, and update pubspec."""
        entries = self.asset_entries()
        self._ensure_generated_directory()
        expected_paths = {entry.destination for entry in entries}
        expected_paths.add(PurePosixPath(CHECKSUM_MANIFEST))
        self._remove_stale_files(expected_paths)
        self._remove_empty_directories()
        for entry in entries:
            self._copy_if_needed(entry)
        self._write_if_changed(
            self.flutter_assets / CHECKSUM_MANIFEST,
            self.checksum_manifest(entries),
        )
        self._write_if_changed(self.pubspec, self.expected_pubspec(entries))
        self._remove_empty_directories()
        print(f"Synced {len(entries)} Flutter assets with SHA-256 manifest.")

    def check(self) -> bool:
        """Return whether the generated mirror and pubspec match their sources."""
        entries = self.asset_entries()
        problems = self.parity_problems(entries)
        return self._report_check_result(entries, problems)

    def check_staged(self) -> bool:
        """Check the repository snapshot currently stored in the Git index."""
        with TemporaryDirectory(prefix="flutter-asset-staged-") as directory:
            snapshot = Path(directory)
            try:
                subprocess.run(
                    [
                        "git",
                        "checkout-index",
                        "--all",
                        "--force",
                        f"--prefix={snapshot.as_posix()}/",
                    ],
                    cwd=self.repository_root,
                    check=True,
                    capture_output=True,
                    text=True,
                )
            except (OSError, subprocess.CalledProcessError) as error:
                raise AssetPipelineError(
                    "could not materialize the staged repository"
                ) from error
            return FlutterAssetPipeline(snapshot).check()

    @staticmethod
    def _report_check_result(entries: list[AssetEntry], problems: list[str]) -> bool:
        if problems:
            print("Flutter asset parity check failed:")
            for problem in problems:
                print(f"  - {problem}")
            print("Run: python3 tools/flutter_asset_pipeline.py sync")
            return False
        print(f"Flutter assets are in parity ({len(entries)} files; SHA-256 verified).")
        return True

    def asset_entries(self) -> list[AssetEntry]:
        """Return every canonical asset and the repository attribution record."""
        if not self.canonical_assets.is_dir():
            raise AssetPipelineError(f"missing canonical assets directory: {self.canonical_assets}")
        attribution = self.repository_root / ATTRIBUTION_SOURCE
        if not attribution.is_file() or attribution.is_symlink():
            raise AssetPipelineError(f"missing attribution file: {attribution}")

        entries = [
            AssetEntry(
                source=source,
                source_path=source.relative_to(self.repository_root).as_posix(),
                destination=PurePosixPath(source.relative_to(self.canonical_assets).as_posix()),
            )
            for source in self._files_in(self.canonical_assets)
        ]
        entries.append(
            AssetEntry(
                source=attribution,
                source_path=ATTRIBUTION_SOURCE,
                destination=ATTRIBUTION_DESTINATION,
            )
        )
        entries.sort(key=lambda entry: entry.destination)
        generated_destinations = [entry.destination for entry in entries]
        generated_destinations.append(PurePosixPath(CHECKSUM_MANIFEST))
        self._validate_destination_collisions(generated_destinations)
        return entries

    @staticmethod
    def _validate_destination_collisions(destinations: list[PurePosixPath]) -> None:
        """Reject generated paths that cannot coexist in one filesystem tree."""
        ordered_destinations = sorted(destinations)
        for index, destination in enumerate(ordered_destinations):
            for other in ordered_destinations[index + 1 :]:
                if (
                    destination != other
                    and destination not in other.parents
                    and other not in destination.parents
                ):
                    continue
                raise AssetPipelineError(
                    "generated asset paths collide: "
                    f"{destination.as_posix()} and {other.as_posix()}"
                )

    def parity_problems(self, entries: list[AssetEntry] | None = None) -> list[str]:
        """Return a deterministic list of source-to-Flutter mirror differences."""
        entries = entries or self.asset_entries()
        expected_files = {entry.destination: entry for entry in entries}
        actual_files = self._files_in(self.flutter_assets, missing_is_empty=True)
        actual_paths = {
            PurePosixPath(path.relative_to(self.flutter_assets).as_posix()): path
            for path in actual_files
            if PurePosixPath(path.relative_to(self.flutter_assets).as_posix())
            != PurePosixPath(CHECKSUM_MANIFEST)
        }
        problems = [
            f"missing Flutter asset: {path.as_posix()}"
            for path in sorted(set(expected_files) - set(actual_paths))
        ]
        problems.extend(
            f"unexpected Flutter asset: {path.as_posix()}"
            for path in sorted(set(actual_paths) - set(expected_files))
        )
        for path in sorted(set(expected_files) & set(actual_paths)):
            source_hash = self.sha256(expected_files[path].source)
            flutter_hash = self.sha256(actual_paths[path])
            if source_hash != flutter_hash:
                problems.append(f"SHA-256 mismatch: {path.as_posix()}")

        manifest_path = self.flutter_assets / CHECKSUM_MANIFEST
        if not manifest_path.is_file():
            problems.append(f"missing checksum manifest: {CHECKSUM_MANIFEST}")
        elif manifest_path.read_text(encoding="utf-8") != self.checksum_manifest(entries):
            problems.append(f"checksum manifest differs: {CHECKSUM_MANIFEST}")
        if not self.pubspec.is_file():
            problems.append(f"missing Flutter pubspec: {self.pubspec}")
        elif self.pubspec.read_text(encoding="utf-8") != self.expected_pubspec(entries):
            problems.append("generated Flutter asset declarations differ: dart/pubspec.yaml")
        return problems

    def checksum_manifest(self, entries: list[AssetEntry]) -> str:
        """Build a stable source-path and SHA-256 record for every generated file."""
        manifest = {
            "schemaVersion": 1,
            "generatedBy": "tools/flutter_asset_pipeline.py",
            "files": [
                {
                    "path": entry.destination.as_posix(),
                    "source": entry.source_path,
                    "sha256": self.sha256(entry.source),
                }
                for entry in entries
            ],
        }
        return json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"

    def expected_pubspec(self, entries: list[AssetEntry]) -> str:
        """Replace only the generated Flutter asset declaration block in pubspec."""
        if not self.pubspec.is_file():
            raise AssetPipelineError(f"missing Flutter pubspec: {self.pubspec}")
        existing = self.pubspec.read_text(encoding="utf-8")
        start = existing.find(ASSET_BLOCK_START)
        end = existing.find(ASSET_BLOCK_END, start + len(ASSET_BLOCK_START))
        if (
            start < 0
            or end < 0
            or existing.count(ASSET_BLOCK_START) != 1
            or existing.count(ASSET_BLOCK_END) != 1
        ):
            raise AssetPipelineError("dart/pubspec.yaml must contain one generated Flutter asset block")
        end_line = existing.find("\n", end)
        if end_line < 0:
            end_line = len(existing)
        else:
            end_line += 1
        generated_block = "\n".join(
            [
                ASSET_BLOCK_START,
                *[
                    f"    - {self._quoted_asset_path(entry.destination)}"
                    for entry in entries
                ],
                f"    - {self._quoted_asset_path(PurePosixPath(CHECKSUM_MANIFEST))}",
                ASSET_BLOCK_END,
                "",
            ]
        )
        return existing[:start] + generated_block + existing[end_line:]

    @staticmethod
    def sha256(path: Path) -> str:
        """Return the SHA-256 digest without loading a binary asset into memory."""
        digest = hashlib.sha256()
        with path.open("rb") as file:
            for block in iter(lambda: file.read(65_536), b""):
                digest.update(block)
        return digest.hexdigest()

    def _copy_if_needed(self, entry: AssetEntry) -> None:
        destination = self.flutter_assets.joinpath(*entry.destination.parts)
        if destination.is_symlink():
            destination.unlink()
        if destination.is_dir():
            if any(destination.iterdir()):
                raise AssetPipelineError(f"generated asset path is a directory: {destination}")
            destination.rmdir()
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.is_file() or self.sha256(entry.source) != self.sha256(destination):
            shutil.copyfile(entry.source, destination)

    def _ensure_generated_directory(self) -> None:
        if self.flutter_assets.is_symlink():
            raise AssetPipelineError(f"generated asset directory must not be a symlink: {self.flutter_assets}")
        self.flutter_assets.mkdir(parents=True, exist_ok=True)

    def _remove_stale_files(self, expected_paths: set[PurePosixPath]) -> None:
        for file in self._files_in(self.flutter_assets, missing_is_empty=True):
            relative = PurePosixPath(file.relative_to(self.flutter_assets).as_posix())
            if relative not in expected_paths:
                file.unlink()

    def _remove_empty_directories(self) -> None:
        directories = [path for path in self.flutter_assets.rglob("*") if path.is_dir()]
        for directory in sorted(directories, key=lambda path: len(path.parts), reverse=True):
            if not any(directory.iterdir()):
                directory.rmdir()

    @staticmethod
    def _quoted_asset_path(path: PurePosixPath) -> str:
        return json.dumps(f"assets/{path.as_posix()}", ensure_ascii=False)

    @staticmethod
    def _files_in(directory: Path, missing_is_empty: bool = False) -> list[Path]:
        if not directory.exists():
            if missing_is_empty:
                return []
            raise AssetPipelineError(f"missing directory: {directory}")
        if directory.is_symlink():
            raise AssetPipelineError(f"asset directory must not be a symlink: {directory}")
        files = []
        for path in directory.rglob("*"):
            if path.is_symlink():
                raise AssetPipelineError(f"asset pipeline does not support symlinks: {path}")
            if path.is_file():
                files.append(path)
        return sorted(files)

    @staticmethod
    def _write_if_changed(path: Path, content: str) -> None:
        if path.is_file() and path.read_text(encoding="utf-8") == content:
            return
        path.write_text(content, encoding="utf-8")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("sync", "check"))
    parser.add_argument(
        "--staged",
        action="store_true",
        help="check the staged Git index snapshot instead of the working tree",
    )
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    repository_root = Path(__file__).resolve().parents[1]
    pipeline = FlutterAssetPipeline(repository_root)
    try:
        if arguments.command == "sync":
            if arguments.staged:
                raise AssetPipelineError("--staged is only valid with check")
            pipeline.sync()
            return 0
        result = pipeline.check_staged() if arguments.staged else pipeline.check()
        return 0 if result else 1
    except AssetPipelineError as error:
        print(f"Flutter asset pipeline error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
