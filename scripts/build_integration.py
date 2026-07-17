#!/usr/bin/env python3
"""Build a deterministic test-only EnhancedVehicle archive."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
from pathlib import Path, PurePosixPath
import sys
import tempfile
import os
import zipfile


REPOSITORY = Path(__file__).resolve().parent.parent
PACKAGE_SCRIPT = REPOSITORY / "scripts" / "package.py"
RUNNER_SOURCE = REPOSITORY / "tests" / "integration" / "FS25_EV_TestRunner.lua"
RUNNER_ARCHIVE_NAME = PurePosixPath("FS25_EV_TestRunner.lua")
ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)


class IntegrationBuildError(RuntimeError):
    """Raised when an isolated test archive cannot be constructed."""


def load_release_packager():
    spec = importlib.util.spec_from_file_location("ev_release_package", PACKAGE_SCRIPT)
    if spec is None or spec.loader is None:
        raise IntegrationBuildError(f"cannot import {PACKAGE_SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def inject_runner(mod_desc: bytes) -> bytes:
    text = mod_desc.decode("utf-8-sig")
    if RUNNER_ARCHIVE_NAME.as_posix() in text:
        raise IntegrationBuildError("production modDesc.xml already references the test runner")
    closing = "  </extraSourceFiles>"
    if text.count(closing) != 1:
        raise IntegrationBuildError("modDesc.xml has no unambiguous <extraSourceFiles> section")
    injected = text.replace(
        closing,
        f'    <sourceFile filename="{RUNNER_ARCHIVE_NAME.as_posix()}" />\n{closing}',
    )
    return injected.encode("utf-8")


def archive_bytes() -> dict[PurePosixPath, bytes]:
    packager = load_release_packager()
    entries = packager.read_manifest()
    files = {
        entry: REPOSITORY.joinpath(*entry.parts).read_bytes()
        for entry in entries
    }
    mod_desc = PurePosixPath("modDesc.xml")
    files[mod_desc] = inject_runner(files[mod_desc])
    files[RUNNER_ARCHIVE_NAME] = RUNNER_SOURCE.read_bytes()
    return files


def write_archive(output: Path) -> None:
    files = archive_bytes()
    output.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{output.name}.", suffix=".tmp", dir=output.parent
    )
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        with zipfile.ZipFile(
            temporary,
            "w",
            compression=zipfile.ZIP_DEFLATED,
            compresslevel=9,
        ) as archive:
            for relative, content in sorted(files.items(), key=lambda item: item[0].as_posix()):
                info = zipfile.ZipInfo(relative.as_posix(), ZIP_TIMESTAMP)
                info.compress_type = zipfile.ZIP_DEFLATED
                info.create_system = 3
                info.external_attr = 0o100644 << 16
                archive.writestr(info, content, compresslevel=9)
        temporary.replace(output)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="destination for the test-only ZIP")
    args = parser.parse_args()
    output = args.output if args.output.is_absolute() else Path.cwd() / args.output
    try:
        write_archive(output)
    except (OSError, UnicodeError, IntegrationBuildError, zipfile.BadZipFile) as error:
        print(f"integration package: {error}", file=sys.stderr)
        return 1
    print(f"Created isolated test archive {output}")
    print(f"SHA-256 {sha256(output)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
