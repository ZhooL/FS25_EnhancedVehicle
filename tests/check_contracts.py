#!/usr/bin/env python3
"""Validate stable EnhancedVehicle input, save, and public-code contracts."""

from __future__ import annotations

from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET


REPOSITORY = Path(__file__).resolve().parent.parent

EXPECTED_ACTIONS = {
    "FS25_EnhancedVehicle_AJ_FRONT_FOLD",
    "FS25_EnhancedVehicle_AJ_FRONT_ONOFF",
    "FS25_EnhancedVehicle_AJ_FRONT_UPDOWN",
    "FS25_EnhancedVehicle_AJ_REAR_FOLD",
    "FS25_EnhancedVehicle_AJ_REAR_ONOFF",
    "FS25_EnhancedVehicle_AJ_REAR_UPDOWN",
    "FS25_EnhancedVehicle_BD",
    "FS25_EnhancedVehicle_DM",
    "FS25_EnhancedVehicle_FD",
    "FS25_EnhancedVehicle_MENU",
    "FS25_EnhancedVehicle_ODO_MODE",
    "FS25_EnhancedVehicle_PARK",
    "FS25_EnhancedVehicle_RD",
    "FS25_EnhancedVehicle_SNAP_ANGLE1",
    "FS25_EnhancedVehicle_SNAP_ANGLE2",
    "FS25_EnhancedVehicle_SNAP_ANGLE3",
    "FS25_EnhancedVehicle_SNAP_CALC_WW",
    "FS25_EnhancedVehicle_SNAP_GRID_RESET",
    "FS25_EnhancedVehicle_SNAP_HL_DIST",
    "FS25_EnhancedVehicle_SNAP_HL_MODE",
    "FS25_EnhancedVehicle_SNAP_LINES_MODE",
    "FS25_EnhancedVehicle_SNAP_REVERSE",
    "FS25_EnhancedVehicle_SNAP_ONOFF",
    "FS25_EnhancedVehicle_SNAP_OPMODE",
    "FS25_EnhancedVehicle_SNAP_TRACK",
    "FS25_EnhancedVehicle_SNAP_TRACKJ",
    "FS25_EnhancedVehicle_SNAP_TRACKO",
    "FS25_EnhancedVehicle_SNAP_TRACKP",
    "FS25_EnhancedVehicle_SNAP_TRACKW",
}

EXPECTED_SAVE_KEYS = {
    "frontDiffIsOn",
    "backDiffIsOn",
    "driveMode",
    "parkingBrakeIsOn",
    "odoMeter",
    "tripMeter",
    "odoMode",
}

PUBLIC_FUNCTIONS = {
    "FS25_EnhancedVehicle.buildNetworkSnapshot",
    "FS25_EnhancedVehicle.sanitizeNetworkSnapshot",
    "FS25_EnhancedVehicle.applyNetworkSnapshot",
    "FS25_EnhancedVehicle.getGuidanceDirectionNode",
    "FS25_EnhancedVehicle.getGuidanceDirectionSign",
    "FS25_EnhancedVehicle.guidanceGeometryNeedsRefresh",
    "FS25_EnhancedVehicle.setHydraulicGroupTurnedOn",
}


def fail(message: str) -> None:
    raise RuntimeError(message)


def main() -> int:
    try:
        root = ET.parse(REPOSITORY / "modDesc.xml").getroot()
        actions = {
            item.get("name")
            for item in root.findall("./actions/action")
            if item.get("name")
        }
        bindings = {
            item.get("action")
            for item in root.findall("./inputBinding/actionBinding")
            if item.get("action")
        }
        if actions != EXPECTED_ACTIONS:
            fail(
                "input action contract changed; missing="
                f"{sorted(EXPECTED_ACTIONS - actions)}, extra={sorted(actions - EXPECTED_ACTIONS)}"
            )
        if bindings != actions:
            fail(
                "every input action must have a binding; missing="
                f"{sorted(actions - bindings)}, extra={sorted(bindings - actions)}"
            )

        source = (REPOSITORY / "FS25_EnhancedVehicle.lua").read_text(encoding="utf-8")
        save_keys = set(
            re.findall(
                r"\{\s*\d+\s*,\s*'([^']+)'\s*\}",
                source[source.index("-- load vehicle status from savegame") : source.index("-- update vehicle parameters")],
            )
        )
        if save_keys != EXPECTED_SAVE_KEYS:
            fail(
                "save-key contract changed; missing="
                f"{sorted(EXPECTED_SAVE_KEYS - save_keys)}, extra={sorted(save_keys - EXPECTED_SAVE_KEYS)}"
            )

        for function_name in sorted(PUBLIC_FUNCTIONS):
            if f"function {function_name}(" not in source:
                fail(f"public helper is missing: {function_name}")

        loader = (REPOSITORY / "FS25_EnhancedVehicle_Loader.lua").read_text(
            encoding="utf-8"
        )
        for callback in ("EV_load", "EV_loadedMission", "EV_unload", "EV_validateTypes"):
            if f"function {callback}(" not in loader:
                fail(f"loader callback is missing: {callback}")
        if "FS25_EV_TestRunner.lua" in loader:
            fail("production loader references the test runner")
    except (OSError, ET.ParseError, RuntimeError, ValueError) as error:
        print(f"contract validation: {error}", file=sys.stderr)
        return 1

    print("Validated input actions, save keys, public helpers, and loader contracts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
