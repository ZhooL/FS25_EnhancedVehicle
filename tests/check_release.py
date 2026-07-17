#!/usr/bin/env python3
"""Validate EnhancedVehicle source metadata, translations, and release ZIPs."""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path, PurePosixPath
import sys
import xml.etree.ElementTree as ElementTree
import zipfile


REPOSITORY = Path(__file__).resolve().parent.parent
MANIFEST = REPOSITORY / "scripts" / "runtime-files.txt"
EXPECTED_VERSION = "1.1.8.0"
EXPECTED_DESC_VERSION = "110"
ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)
GUIDANCE_I3D = REPOSITORY / "resources" / "guidanceRibbon.i3d"
TEST_RUNNER_NAME = "FS25_EV_TestRunner.lua"


class ValidationError(RuntimeError):
    """Raised when release validation fails."""


def manifest_entries() -> list[str]:
    entries: list[str] = []
    seen: set[str] = set()
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
            raise ValidationError(f"manifest line {line_number} is unsafe: {value!r}")
        if value in seen:
            raise ValidationError(f"manifest contains duplicate entry: {value}")
        seen.add(value)

        source = REPOSITORY.joinpath(*path.parts)
        if source.is_file():
            entries.append(value)
        elif not optional:
            raise ValidationError(f"required runtime file is missing: {value}")

    if not entries:
        raise ValidationError("runtime manifest is empty")
    return sorted(entries)


def parse_xml(path: Path) -> ElementTree.Element:
    try:
        return ElementTree.parse(path).getroot()
    except (ElementTree.ParseError, OSError) as error:
        raise ValidationError(f"invalid XML in {path.relative_to(REPOSITORY)}: {error}") from error


def validate_xml() -> None:
    paths = sorted(REPOSITORY.glob("*.xml"))
    paths += sorted((REPOSITORY / "ui").glob("*.xml"))
    paths += sorted((REPOSITORY / "translations").glob("*.xml"))
    if GUIDANCE_I3D.is_file():
        paths.append(GUIDANCE_I3D)
    if not paths:
        raise ValidationError("no XML files found")
    for path in paths:
        parse_xml(path)


def validate_guidance_mesh() -> None:
    root = parse_xml(GUIDANCE_I3D)
    shapes = root.find("Shapes")
    if shapes is None:
        raise ValidationError("guidance ribbon I3D is missing its <Shapes> element")
    mesh = shapes.find("IndexedTriangleSet")
    if mesh is None:
        raise ValidationError("guidance ribbon is missing its indexed prism geometry")
    vertices = mesh.find("Vertices")
    triangles = mesh.find("Triangles")
    if vertices is None or vertices.get("count") != "24":
        raise ValidationError("guidance ribbon prism must contain 24 vertices")
    if triangles is None or triangles.get("count") != "12":
        raise ValidationError("guidance ribbon prism must contain 12 triangles")


def validate_metadata() -> None:
    root = parse_xml(REPOSITORY / "modDesc.xml")
    if root.tag != "modDesc":
        raise ValidationError(f"modDesc.xml root must be <modDesc>, found <{root.tag}>")
    if root.get("descVersion") != EXPECTED_DESC_VERSION:
        raise ValidationError(
            f"modDesc descVersion must be {EXPECTED_DESC_VERSION}, "
            f"found {root.get('descVersion')!r}"
        )
    version = (root.findtext("version") or "").strip()
    if version != EXPECTED_VERSION:
        raise ValidationError(
            f"modDesc version must be {EXPECTED_VERSION}, found {version!r}"
        )

    source_files = {
        element.get("filename")
        for element in root.findall("./extraSourceFiles/sourceFile")
    }
    if TEST_RUNNER_NAME in source_files:
        raise ValidationError("production modDesc.xml references the integration test runner")


def validate_release_isolation(entries: list[str]) -> None:
    forbidden = [
        entry
        for entry in entries
        if entry == TEST_RUNNER_NAME
        or entry.startswith("tests/")
        or entry.startswith("scripts/test_fs25")
    ]
    if forbidden:
        raise ValidationError(
            "runtime manifest contains test-only files: " + ", ".join(forbidden)
        )


def translation_keys(path: Path) -> set[str]:
    root = parse_xml(path)
    values = [element.get("name") for element in root.findall("./texts/text")]
    missing_names = sum(value is None or value == "" for value in values)
    if missing_names:
        raise ValidationError(
            f"{path.relative_to(REPOSITORY)} contains {missing_names} text entries without names"
        )
    names = [value for value in values if value]
    duplicates = sorted(name for name, count in Counter(names).items() if count > 1)
    if duplicates:
        raise ValidationError(
            f"{path.relative_to(REPOSITORY)} contains duplicate keys: "
            + ", ".join(duplicates)
        )
    return set(names)


def validate_translations() -> None:
    english = REPOSITORY / "translations" / "translation_en.xml"
    expected = translation_keys(english)
    translation_paths = sorted((REPOSITORY / "translations").glob("translation_*.xml"))
    if len(translation_paths) < 2:
        raise ValidationError("expected English plus at least one translated locale")

    differences: list[str] = []
    for path in translation_paths:
        actual = translation_keys(path)
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        if missing:
            differences.append(
                f"{path.name}: missing English keys: {', '.join(missing)}"
            )
        if extra:
            differences.append(
                f"{path.name}: keys absent from English: {', '.join(extra)}"
            )
    if differences:
        raise ValidationError("translation key mismatch\n  " + "\n  ".join(differences))


def validate_archive(path: Path, expected_entries: list[str]) -> None:
    try:
        with zipfile.ZipFile(path, "r") as archive:
            infos = archive.infolist()
            names = [info.filename for info in infos]
            if TEST_RUNNER_NAME in names or any(name.startswith("tests/") for name in names):
                raise ValidationError(f"release archive contains test harness files: {path}")
            if len(names) != len(set(names)):
                raise ValidationError(f"archive contains duplicate entries: {path}")
            if names != expected_entries:
                missing = sorted(set(expected_entries) - set(names))
                extra = sorted(set(names) - set(expected_entries))
                order_error = not missing and not extra
                details = []
                if missing:
                    details.append("missing: " + ", ".join(missing))
                if extra:
                    details.append("unexpected: " + ", ".join(extra))
                if order_error:
                    details.append("entries are not in deterministic lexical order")
                raise ValidationError("archive layout mismatch; " + "; ".join(details))

            for info in infos:
                entry = PurePosixPath(info.filename)
                if entry.is_absolute() or ".." in entry.parts or info.is_dir():
                    raise ValidationError(f"unsafe archive entry: {info.filename!r}")
                if info.date_time != ZIP_TIMESTAMP:
                    raise ValidationError(
                        f"non-deterministic timestamp on archive entry: {info.filename}"
                    )
                if info.create_system != 3 or (info.external_attr >> 16) != 0o100644:
                    raise ValidationError(
                        f"non-deterministic file mode on archive entry: {info.filename}"
                    )
            corrupt = archive.testzip()
            if corrupt is not None:
                raise ValidationError(f"archive CRC check failed for: {corrupt}")
    except (OSError, zipfile.BadZipFile) as error:
        raise ValidationError(f"invalid ZIP archive {path}: {error}") from error


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, help="also validate a built release ZIP")
    parser.add_argument(
        "--list-lua",
        action="store_true",
        help="print whitelisted runtime Lua paths and skip other checks",
    )
    arguments = parser.parse_args()

    try:
        entries = manifest_entries()
        if arguments.list_lua:
            for entry in entries:
                if entry.endswith(".lua"):
                    print(entry)
            return 0

        validate_xml()
        validate_guidance_mesh()
        validate_metadata()
        validate_release_isolation(entries)
        validate_translations()
        if arguments.archive is not None:
            validate_archive(arguments.archive.resolve(), entries)
    except ValidationError as error:
        print(f"validation: {error}", file=sys.stderr)
        return 1

    checked = "source metadata, XML, and translations"
    if arguments.archive is not None:
        checked += f", plus {arguments.archive}"
    print(f"Validated {checked}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
