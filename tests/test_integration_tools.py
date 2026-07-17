#!/usr/bin/env python3
"""Unit tests for the isolated FS25 integration tooling."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile
import xml.etree.ElementTree as ET


REPOSITORY = Path(__file__).resolve().parent.parent


def load_module(name: str, relative: str):
    path = REPOSITORY / relative
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


builder = load_module("ev_integration_builder", "scripts/build_integration.py")
supervisor = load_module("ev_integration_supervisor", "scripts/test_fs25.py")


class IntegrationBuilderTests(unittest.TestCase):
    def test_test_archive_is_isolated_from_release_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "FS25_EnhancedVehicle.zip"
            builder.write_archive(output)
            with zipfile.ZipFile(output) as archive:
                names = archive.namelist()
                self.assertIn("FS25_EV_TestRunner.lua", names)
                self.assertNotIn("tests/integration/FS25_EV_TestRunner.lua", names)
                mod_desc = archive.read("modDesc.xml").decode("utf-8")
                self.assertEqual(mod_desc.count("FS25_EV_TestRunner.lua"), 1)
                self.assertLess(
                    mod_desc.index("FS25_EnhancedVehicle_Loader.lua"),
                    mod_desc.index("FS25_EV_TestRunner.lua"),
                )

    def test_builder_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            first = Path(temporary) / "first.zip"
            second = Path(temporary) / "second.zip"
            builder.write_archive(first)
            builder.write_archive(second)
            self.assertEqual(first.read_bytes(), second.read_bytes())


class SupervisorTests(unittest.TestCase):
    def test_marker_parser_tracks_pass_fail_skip_capture_and_completion(self) -> None:
        log = """
EVTEST START mission_load
EVTEST PASS mission_load
EVTEST START optional
EVTEST SKIP optional unsupported GPU
EVTEST START broken
EVTEST FAIL broken bad state
EVTEST CAPTURE taa r=0.05 g=1 b=0.95 x1=0.2 y1=0.4 x2=0.8 y2=0.4
EVTEST COMPLETE pass=1 fail=1 skip=1
"""
        cases, captures, completed = supervisor.parse_log("client", log)
        self.assertTrue(completed)
        self.assertEqual([item.status for item in cases], ["pass", "skip", "fail"])
        self.assertEqual(captures[0].name, "taa")
        self.assertAlmostEqual(captures[0].x2, 0.8)

    def test_incomplete_case_becomes_failure(self) -> None:
        cases, _, completed = supervisor.parse_log("client", "EVTEST START waiting\n")
        self.assertFalse(completed)
        self.assertEqual(cases[0].status, "fail")
        self.assertEqual(cases[-1].name, "client_completion")

    def test_active_case_tracks_only_an_unfinished_marker(self) -> None:
        self.assertEqual(
            supervisor.active_case("EVTEST START first\nEVTEST PASS first\nEVTEST START second\n"),
            "second",
        )
        self.assertIsNone(
            supervisor.active_case("EVTEST START first\nEVTEST FAIL first reason\n")
        )

    def test_client_load_screen_waits_for_stable_end_of_map_load(self) -> None:
        loading_log = "FTG 'savegame6/densityMap_weed.gdm' max needed CPU instances = 1"
        self.assertFalse(supervisor.client_load_screen_ready(loading_log, "", 0.5))
        self.assertTrue(supervisor.client_load_screen_ready(loading_log, "", 0.75))
        self.assertTrue(
            supervisor.client_load_screen_ready("", "EVTEST START mission_load\n", 0)
        )

    def test_default_launch_uses_direct_proton_ownership(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            steam = Path(temporary) / "Steam"
            game = steam / "steamapps/common/Farming Simulator 25"
            proton = steam / "steamapps/common/Proton - Experimental/proton"
            compat = steam / "steamapps/compatdata" / supervisor.APP_ID
            game.mkdir(parents=True)
            (game / "x64").mkdir()
            proton.parent.mkdir(parents=True)
            compat.mkdir(parents=True)
            (game / "FarmingSimulator2025.exe").write_bytes(b"exe")
            (game / "x64/FarmingSimulator2025Game.exe").write_bytes(b"game")
            proton.write_bytes(b"runtime")
            command = supervisor.build_launch_command("dedicated", 6, game, None)
            self.assertIn(str(proton.resolve()), command)
            self.assertIn(f"STEAM_COMPAT_DATA_PATH={compat.resolve()}", command)
            self.assertIn("-server", command)
            self.assertNotIn("-autoStartSavegameId", command)

    def test_x11_window_match_requires_game_identity_and_supervised_pid(self) -> None:
        self.assertTrue(
            supervisor.is_fs25_x11_window(
                "Farming Simulator 25", ("steam_app_2300320",), 123, {123, 456}
            )
        )
        self.assertFalse(
            supervisor.is_fs25_x11_window(
                "Farming Simulator 25", ("steam_app_2300320",), 999, {123, 456}
            )
        )
        self.assertFalse(
            supervisor.is_fs25_x11_window("Terminal", ("kitty",), 123, {123})
        )

    def test_temporary_save_edit_is_valid_and_disables_autosave(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            career = Path(temporary) / "careerSavegame.xml"
            career.write_text(
                "<?xml version='1.0'?><careerSavegame><settings>"
                "<autoSaveInterval>15</autoSaveInterval></settings></careerSavegame>",
                encoding="utf-8",
            )
            supervisor.ensure_mod_enabled(career)
            content = career.read_text(encoding="utf-8")
            self.assertIn('modName="FS25_EnhancedVehicle"', content)
            self.assertIn("<autoSaveInterval>9999.000000</autoSaveInterval>", content)

    def test_dedicated_config_enables_archive_by_mod_basename(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            profile = root / "profile"
            mods = profile / "mods"
            save = profile / "savegame6"
            mods.mkdir(parents=True)
            save.mkdir()
            (save / "careerSavegame.xml").write_text(
                "<careerSavegame><settings><autoSaveInterval>15</autoSaveInterval>"
                "</settings></careerSavegame>",
                encoding="utf-8",
            )
            test_zip = root / "test.zip"
            test_zip.write_bytes(b"test")
            session = supervisor.ProtectedSession(profile, mods, 6, test_zip)
            session.backup()
            try:
                session.prepare_run("dedicated")
                config = profile / "dedicated_server/dedicatedServerConfig.xml"
                document = ET.parse(config).getroot()
                mod = document.find("./mods/mod")
                self.assertIsNotNone(mod)
                self.assertEqual(mod.get("filename"), "FS25_EnhancedVehicle")
                self.assertEqual(mod.get("isDlc"), "false")
                self.assertEqual(mod.get("enabled"), "true")
            finally:
                self.assertEqual(session.restore(), [])

    def test_dedicated_runner_uses_unpaused_mission_finished_hook(self) -> None:
        source = (REPOSITORY / "tests/integration/FS25_EV_TestRunner.lua").read_text(
            encoding="utf-8"
        )
        self.assertIn("Mission00.loadMission00Finished", source)
        self.assertIn("FS25_EnhancedVehicle.loadMap = Utils.appendedFunction", source)
        self.assertIn('runDedicatedCase("dedicated_client_isolation"', source)
        self.assertIn('runDedicatedCase("mod_teardown"', source)

    def test_profile_session_restores_every_protected_path(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            profile = root / "profile"
            mods = profile / "mods"
            save = profile / "savegame3"
            screenshots = profile / "screenshots"
            mods.mkdir(parents=True)
            save.mkdir()
            screenshots.mkdir()
            career = save / "careerSavegame.xml"
            career.write_text(
                "<careerSavegame><settings><autoSaveInterval>15</autoSaveInterval>"
                "</settings></careerSavegame>",
                encoding="utf-8",
            )
            (save / "state.dat").write_bytes(b"original-save")
            for name in supervisor.ProtectedSession.PROTECTED_FILES:
                (profile / name).write_bytes(("original-" + name).encode())
            production_mod = mods / supervisor.MOD_FILENAME
            production_mod.write_bytes(b"production")
            (screenshots / "existing.png").write_bytes(b"existing")
            test_zip = root / "test.zip"
            test_zip.write_bytes(b"test")

            original_save_hash = supervisor.hash_tree(save)
            session = supervisor.ProtectedSession(profile, mods, 3, test_zip)
            session.backup()
            (save / "state.dat").write_bytes(b"changed")
            (profile / "game.xml").write_bytes(b"changed")
            production_mod.write_bytes(b"changed")
            (screenshots / "new.png").write_bytes(b"new")
            problems = session.restore()

            self.assertEqual(problems, [])
            self.assertEqual(supervisor.hash_tree(save), original_save_hash)
            self.assertEqual(production_mod.read_bytes(), b"production")
            self.assertEqual((profile / "game.xml").read_bytes(), b"original-game.xml")
            self.assertFalse((screenshots / "new.png").exists())
            self.assertTrue((screenshots / "existing.png").exists())

    @unittest.skipUnless(importlib.util.find_spec("PIL") is not None, "Pillow is optional in CI")
    def test_semantic_screenshot_metrics_accept_a_connected_projected_line(self) -> None:
        from PIL import Image, ImageDraw

        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "capture.png"
            image = Image.new("RGB", (800, 600), (20, 20, 20))
            draw = ImageDraw.Draw(image)
            draw.line((160, 300, 640, 300), fill=(13, 255, 242), width=8)
            image.save(path)
            request = supervisor.CaptureRequest("taa", 0.05, 1, 0.95, 0.2, 0.5, 0.8, 0.5)
            metrics = supervisor.analyze_screenshot(path, request)
            self.assertTrue(metrics.passed, metrics.reason)
            self.assertGreater(metrics.largest_component, 100)


if __name__ == "__main__":
    unittest.main()
