#!/usr/bin/env python3
"""Build a deterministic, runtime-only EnhancedVehicle mod archive."""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path, PurePosixPath
import sys
import tempfile
import zipfile


REPOSITORY = Path(__file__).resolve().parent.parent
MANIFEST = REPOSITORY / "scripts" / "runtime-files.txt"
DEFAULT_OUTPUT = REPOSITORY / "build" / "FS25_EnhancedVehicle.zip"
ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)


class ManifestError(RuntimeError):
    """Raised when the runtime manifest cannot safely be packaged."""


def read_manifest() -> list[PurePosixPath]:
    entries: list[PurePosixPath] = []
    seen: set[PurePosixPath] = set()

    for line_number, raw_line in enumerate(
        MANIFEST.read_text(encoding="utf-8").splitlines(), start=1
    ):
        value = raw_line.strip()
        if not value or value.startswith("#"):
            continue

        optional = value.startswith("?")
        if optional:
            value = value[1:]

        path = PurePosixPath(value)
        if (
            not value
            or path.is_absolute()
            or ".." in path.parts
            or "." in path.parts
            or value.endswith("/")
        ):
            raise ManifestError(
                f"{MANIFEST.relative_to(REPOSITORY)}:{line_number}: "
                f"unsafe path {value!r}"
            )
        if path in seen:
            raise ManifestError(
                f"{MANIFEST.relative_to(REPOSITORY)}:{line_number}: "
                f"duplicate path {value!r}"
            )

        source = REPOSITORY.joinpath(*path.parts)
        if not source.exists():
            if optional:
                continue
            raise ManifestError(f"required runtime file is missing: {path}")
        if not source.is_file():
            raise ManifestError(f"runtime entry is not a regular file: {path}")

        seen.add(path)
        entries.append(path)

    if not entries:
        raise ManifestError("runtime manifest is empty")
    return sorted(entries, key=lambda item: item.as_posix())


def write_archive(output: Path, entries: list[PurePosixPath]) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    file_descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{output.name}.", suffix=".tmp", dir=output.parent
    )
    os.close(file_descriptor)
    temporary_path = Path(temporary_name)

    try:
        with zipfile.ZipFile(
            temporary_path,
            mode="w",
            compression=zipfile.ZIP_DEFLATED,
            compresslevel=9,
        ) as archive:
            for relative_path in entries:
                source = REPOSITORY.joinpath(*relative_path.parts)
                info = zipfile.ZipInfo(relative_path.as_posix(), ZIP_TIMESTAMP)
                info.compress_type = zipfile.ZIP_DEFLATED
                info.create_system = 3
                info.external_attr = 0o100644 << 16
                archive.writestr(info, source.read_bytes(), compresslevel=9)
        temporary_path.replace(output)
    except BaseException:
        temporary_path.unlink(missing_ok=True)
        raise


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"archive path (default: {DEFAULT_OUTPUT.relative_to(REPOSITORY)})",
    )
    arguments = parser.parse_args()
    output = arguments.output
    if not output.is_absolute():
        output = Path.cwd() / output

    try:
        entries = read_manifest()
        write_archive(output, entries)
    except (OSError, ManifestError, zipfile.BadZipFile) as error:
        print(f"package: {error}", file=sys.stderr)
        return 1

    print(f"Created {output} ({len(entries)} runtime files)")
    print(f"SHA-256 {sha256(output)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
