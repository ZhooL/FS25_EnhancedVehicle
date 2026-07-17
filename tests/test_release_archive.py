#!/usr/bin/env python3
"""Regression tests for byte-for-byte release archive validation."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile


REPOSITORY = Path(__file__).resolve().parent.parent


def load_module(name: str, relative: str):
    path = REPOSITORY / relative
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


packager = load_module("ev_release_packager", "scripts/package.py")
release_check = load_module("ev_release_check", "tests/check_release.py")


class ReleaseArchiveTests(unittest.TestCase):
    @staticmethod
    def write_shaped_archive(path: Path, payloads: dict[str, bytes]) -> None:
        entries = release_check.manifest_entries()
        with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for name in entries:
                info = zipfile.ZipInfo(name, release_check.ZIP_TIMESTAMP)
                info.compress_type = zipfile.ZIP_DEFLATED
                info.create_system = 3
                info.external_attr = 0o100644 << 16
                archive.writestr(info, payloads[name], compresslevel=9)

    def test_empty_payloads_fail_source_comparison(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "empty.zip"
            entries = release_check.manifest_entries()
            self.write_shaped_archive(archive, {name: b"" for name in entries})
            with self.assertRaisesRegex(
                release_check.ValidationError,
                "archive payload does not match runtime source",
            ):
                release_check.validate_archive(archive, entries)

    def test_mutated_payload_with_valid_zip_crc_fails_source_comparison(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "mutated.zip"
            entries = release_check.manifest_entries()
            payloads = {
                name: REPOSITORY.joinpath(*Path(name).parts).read_bytes()
                for name in entries
            }
            changed = entries[0]
            payloads[changed] = payloads[changed] + b"\nmutated"
            self.write_shaped_archive(archive, payloads)
            with self.assertRaisesRegex(release_check.ValidationError, changed):
                release_check.validate_archive(archive, entries)

    def test_generated_archive_payloads_match_sources(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "generated.zip"
            entries = packager.read_manifest()
            packager.write_archive(archive, entries)
            release_check.validate_archive(
                archive, [entry.as_posix() for entry in entries]
            )


if __name__ == "__main__":
    unittest.main()
