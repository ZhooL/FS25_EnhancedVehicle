#!/usr/bin/env python3
"""Optionally validate EnhancedVehicle's APIs against an installed FS25 SDK."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys
import zipfile


VEHICLE_LOADING = "dataS/scripts/vehicles/VehicleLoadingData.lua"
REVERSE_DRIVING = "dataS/scripts/vehicles/specializations/ReverseDriving.lua"
SETTINGS_MODEL = "dataS/scripts/gui/base/SettingsModel.lua"

REQUIRED_ZIP_TOKENS = {
    VEHICLE_LOADING: (
        "function VehicleLoadingData:setStoreItem(",
        "function VehicleLoadingData:setConfigurations(",
        "function VehicleLoadingData:setIsRegistered(",
        "function VehicleLoadingData:setIsSaved(",
        "function VehicleLoadingData:setPosition(",
        "function VehicleLoadingData:load(",
    ),
    REVERSE_DRIVING: (
        "function ReverseDriving:setIsReverseDriving(",
        "function ReverseDriving:reverseDirectionChanged(",
        "function ReverseDriving:getAIDirectionNode(",
    ),
    SETTINGS_MODEL: (
        "setPostProcessAntiAliasing",
        "getSupportsPostProcessAntiAliasing",
        "setMSAA",
        "setDLSSQuality",
    ),
}


def candidates(explicit: Path | None) -> list[Path]:
    values: list[Path] = []
    if explicit is not None:
        values.append(explicit)
    game_dir = os.environ.get("FS25_GAME_DIR")
    if game_dir:
        values.append(Path(game_dir) / "sdk" / "debugger" / "gameSource.zip")
    home = Path.home()
    values.extend(
        (
            home
            / ".local/share/Steam/steamapps/common/Farming Simulator 25/sdk/debugger/gameSource.zip",
            home
            / ".steam/steam/steamapps/common/Farming Simulator 25/sdk/debugger/gameSource.zip",
        )
    )
    return values


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-source", type=Path)
    parser.add_argument(
        "--required",
        action="store_true",
        help="fail instead of skipping when the SDK archive is unavailable",
    )
    args = parser.parse_args()

    source = next((path for path in candidates(args.game_source) if path.is_file()), None)
    if source is None:
        message = "FS25 SDK source contract skipped (gameSource.zip not installed)"
        if args.required:
            print(message, file=sys.stderr)
            return 1
        print(message)
        return 0

    try:
        with zipfile.ZipFile(source) as archive:
            for member, tokens in REQUIRED_ZIP_TOKENS.items():
                try:
                    content = archive.read(member).decode("utf-8", errors="replace")
                except KeyError as error:
                    raise RuntimeError(f"SDK archive is missing {member}") from error
                for token in tokens:
                    if token not in content:
                        raise RuntimeError(f"FS25 engine contract is missing {token!r} in {member}")
    except (OSError, RuntimeError, zipfile.BadZipFile) as error:
        print(f"engine contract: {error}", file=sys.stderr)
        return 1

    binding_changes = source.parents[1] / "scriptBindingChanges.txt"
    if binding_changes.is_file() and "saveScreenshot" not in binding_changes.read_text(
        encoding="utf-8", errors="replace"
    ):
        print("engine contract: saveScreenshot binding is unavailable", file=sys.stderr)
        return 1

    script_binding = source.parents[1] / "debugger" / "scriptBinding.xml"
    if not script_binding.is_file():
        print("engine contract: scriptBinding.xml is unavailable", file=sys.stderr)
        return 1
    binding_text = script_binding.read_text(encoding="utf-8", errors="replace")
    for function_name in (
        "createPlaneShapeFrom2DContour",
        "createTransformGroup",
        "getMaterial",
        "setMaterial",
    ):
        if f'<function name="{function_name}"' not in binding_text:
            print(f"engine contract: {function_name} binding is unavailable", file=sys.stderr)
            return 1

    print(f"Validated installed FS25 engine contracts in {source}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
