#!/usr/bin/env python3
"""Unit tests for the isolated FS25 integration tooling."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock
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
    def assert_protocol_failure(self, log: str, expected_reason: str) -> None:
        cases, _, completed = supervisor.parse_log("client", log)
        self.assertFalse(completed)
        reasons = [case.reason for case in cases if "_protocol_" in case.name]
        self.assertTrue(
            any(expected_reason in reason for reason in reasons),
            f"{expected_reason!r} was not found in protocol errors: {reasons}",
        )

    def test_valid_client_marker_sequence_with_capture(self) -> None:
        log = """
EVTEST START mission_load
EVTEST PASS mission_load
EVTEST START aa_taa
EVTEST CAPTURE taa r=0.05 g=1 b=0.95 x1=0.2 y1=0.4 x2=0.8 y2=0.4
EVTEST PASS aa_taa
EVTEST START optional
EVTEST SKIP optional unsupported GPU
EVTEST COMPLETE pass=2 fail=0 skip=1
"""
        cases, captures, completed = supervisor.parse_log("client", log)
        self.assertTrue(completed)
        self.assertEqual([item.status for item in cases], ["pass", "pass", "skip"])
        self.assertEqual(captures[0].name, "taa")
        self.assertAlmostEqual(captures[0].x2, 0.8)

    def test_valid_dedicated_marker_sequence(self) -> None:
        log = """
EVTEST START mission_load
EVTEST PASS mission_load
EVTEST START dedicated_client_isolation
EVTEST PASS dedicated_client_isolation
EVTEST START mod_teardown
EVTEST PASS mod_teardown
EVTEST COMPLETE pass=3 fail=0 skip=0
"""
        cases, captures, completed = supervisor.parse_log("dedicated", log)
        self.assertTrue(completed)
        self.assertEqual([item.status for item in cases], ["pass", "pass", "pass"])
        self.assertEqual(captures, [])

    def test_zero_case_completion_fails_closed(self) -> None:
        self.assert_protocol_failure(
            "EVTEST COMPLETE pass=0 fail=0 skip=0\n", "no test cases were executed"
        )

    def test_fail_then_restart_and_pass_cannot_overwrite_failure(self) -> None:
        log = """
EVTEST START repeated
EVTEST FAIL repeated first failure
EVTEST START repeated
EVTEST PASS repeated
EVTEST COMPLETE pass=1 fail=0 skip=0
"""
        cases, _, completed = supervisor.parse_log("client", log)
        self.assertFalse(completed)
        self.assertEqual(cases[0].status, "fail")
        self.assertEqual(cases[0].reason, "first failure")
        self.assert_protocol_failure(log, "more than one START")

    def test_duplicate_start_fails_protocol(self) -> None:
        self.assert_protocol_failure(
            "EVTEST START case\nEVTEST START case\nEVTEST PASS case\n"
            "EVTEST COMPLETE pass=1 fail=0 skip=0\n",
            "more than one START",
        )

    def test_duplicate_terminal_fails_protocol(self) -> None:
        self.assert_protocol_failure(
            "EVTEST START case\nEVTEST PASS case\nEVTEST FAIL case later\n"
            "EVTEST COMPLETE pass=1 fail=0 skip=0\n",
            "more than one terminal result",
        )

    def test_terminal_without_start_fails_protocol(self) -> None:
        self.assert_protocol_failure(
            "EVTEST FAIL orphan reason\nEVTEST COMPLETE pass=0 fail=1 skip=0\n",
            "without START",
        )

    def test_missing_or_malformed_completion_counts_fail_protocol(self) -> None:
        prefix = "EVTEST START case\nEVTEST PASS case\n"
        self.assert_protocol_failure(prefix + "EVTEST COMPLETE\n", "malformed counts")
        self.assert_protocol_failure(
            prefix + "EVTEST COMPLETE pass=one fail=0 skip=0\n", "malformed counts"
        )

    def test_mismatched_completion_counts_fail_protocol(self) -> None:
        self.assert_protocol_failure(
            "EVTEST START case\nEVTEST PASS case\n"
            "EVTEST COMPLETE pass=0 fail=0 skip=0\n",
            "do not match",
        )

    def test_duplicate_complete_and_markers_after_complete_fail_protocol(self) -> None:
        prefix = (
            "EVTEST START case\nEVTEST PASS case\n"
            "EVTEST COMPLETE pass=1 fail=0 skip=0\n"
        )
        self.assert_protocol_failure(
            prefix + "EVTEST COMPLETE pass=1 fail=0 skip=0\n", "more than once"
        )
        self.assert_protocol_failure(prefix + "EVTEST START later\n", "after COMPLETE")

    def test_malformed_or_non_finite_capture_fails_protocol(self) -> None:
        prefix = "EVTEST START aa_taa\n"
        suffix = "EVTEST PASS aa_taa\nEVTEST COMPLETE pass=1 fail=0 skip=0\n"
        self.assert_protocol_failure(
            prefix + "EVTEST CAPTURE taa r=1 g=1 b=1 x1=0 y1=0 x2=1\n" + suffix,
            "malformed or non-finite",
        )
        self.assert_protocol_failure(
            prefix
            + "EVTEST CAPTURE taa r=nan g=1 b=1 x1=0 y1=0 x2=1 y2=1\n"
            + suffix,
            "malformed or non-finite",
        )

    def test_incomplete_case_becomes_failure(self) -> None:
        cases, _, completed = supervisor.parse_log("client", "EVTEST START waiting\n")
        self.assertFalse(completed)
        self.assertEqual(cases[0].status, "fail")
        self.assertTrue(any("_protocol_" in case.name for case in cases))

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

    def test_profile_session_restores_existing_mod_settings_subtree_only(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            profile = root / "profile"
            mods = profile / "mods"
            save = profile / "savegame3"
            settings = profile / "modSettings/FS25_EnhancedVehicle"
            sibling = profile / "modSettings/OtherMod"
            mods.mkdir(parents=True)
            save.mkdir()
            settings.mkdir(parents=True)
            sibling.mkdir(parents=True)
            (save / "careerSavegame.xml").write_text("<careerSavegame/>")
            (settings / "nested.xml").write_bytes(b"original-settings")
            (sibling / "keep.xml").write_bytes(b"keep")
            test_zip = root / "test.zip"
            test_zip.write_bytes(b"test")
            original_hash = supervisor.hash_tree(settings)

            session = supervisor.ProtectedSession(profile, mods, 3, test_zip)
            session.backup()
            (settings / "nested.xml").write_bytes(b"changed")
            (settings / "created.xml").write_bytes(b"created")
            self.assertEqual(session.restore(), [])

            self.assertEqual(supervisor.hash_tree(settings), original_hash)
            self.assertEqual((settings / "nested.xml").read_bytes(), b"original-settings")
            self.assertEqual((sibling / "keep.xml").read_bytes(), b"keep")

    def test_profile_session_removes_only_test_created_mod_settings_subtree(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            profile = root / "profile"
            mods = profile / "mods"
            save = profile / "savegame3"
            sibling = profile / "modSettings/OtherMod"
            mods.mkdir(parents=True)
            save.mkdir()
            sibling.mkdir(parents=True)
            (save / "careerSavegame.xml").write_text("<careerSavegame/>")
            (sibling / "keep.xml").write_bytes(b"keep")
            test_zip = root / "test.zip"
            test_zip.write_bytes(b"test")

            session = supervisor.ProtectedSession(profile, mods, 3, test_zip)
            session.backup()
            created = profile / "modSettings/FS25_EnhancedVehicle/nested"
            created.mkdir(parents=True)
            (created / "settings.xml").write_bytes(b"created")
            self.assertEqual(session.restore(), [])

            self.assertFalse((profile / "modSettings/FS25_EnhancedVehicle").exists())
            self.assertEqual((sibling / "keep.xml").read_bytes(), b"keep")

    def _fault_session(self, root: Path) -> tuple[object, Path, Path]:
        profile = root / "profile"
        mods = profile / "mods"
        save = profile / "savegame6"
        mods.mkdir(parents=True)
        save.mkdir()
        (save / "careerSavegame.xml").write_text("<careerSavegame/>")
        (save / "state.dat").write_bytes(b"original-save")
        production_mod = mods / supervisor.MOD_FILENAME
        production_mod.write_bytes(b"production-mod")
        test_zip = root / "test.zip"
        test_zip.write_bytes(b"test-mod")
        session = supervisor.ProtectedSession(profile, mods, 6, test_zip)
        session.backup()
        (save / "state.dat").write_bytes(b"test-save")
        production_mod.write_bytes(b"test-mod")
        return session, save, production_mod

    def _assert_retained_backup(self, session: object, problems: list[str]) -> None:
        self.assertTrue(session.temp.is_dir())
        self.assertTrue(session.backup_save.is_dir())
        recovery = str(session.temp.resolve())
        self.assertTrue(any(recovery in problem for problem in problems), problems)

    def test_staging_copy_failure_keeps_live_save_and_recovery_backup(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            session, save, production_mod = self._fault_session(Path(temporary))
            original_copy_tree = session._copy_tree

            def fail_save_stage(source: Path, destination: Path) -> None:
                if source == session.backup_save:
                    raise OSError("injected staged copy failure")
                original_copy_tree(source, destination)

            with mock.patch.object(session, "_copy_tree", side_effect=fail_save_stage):
                problems = session.restore()
            self.assertTrue(save.is_dir())
            self.assertEqual((save / "state.dat").read_bytes(), b"test-save")
            self.assertEqual(production_mod.read_bytes(), b"production-mod")
            self._assert_retained_backup(session, problems)

            self.assertEqual(session.restore(), [])
            self.assertEqual((save / "state.dat").read_bytes(), b"original-save")
            self.assertEqual(production_mod.read_bytes(), b"production-mod")

    def test_swap_failure_rolls_back_live_save_and_allows_retry(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            session, save, _ = self._fault_session(Path(temporary))
            original_replace = session._replace_path
            failed = False

            def fail_replacement(source: Path, destination: Path) -> None:
                nonlocal failed
                if not failed and source.name == "replacement" and destination == save:
                    failed = True
                    raise OSError("injected swap failure")
                original_replace(source, destination)

            with mock.patch.object(session, "_replace_path", side_effect=fail_replacement):
                problems = session.restore()
            self.assertTrue(save.is_dir())
            self.assertEqual((save / "state.dat").read_bytes(), b"test-save")
            self._assert_retained_backup(session, problems)

            self.assertEqual(session.restore(), [])
            self.assertEqual((save / "state.dat").read_bytes(), b"original-save")

    def test_pre_swap_quarantine_failure_keeps_live_save_and_allows_retry(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            session, save, _ = self._fault_session(Path(temporary))
            original_replace = session._replace_path
            failed = False

            def fail_quarantine(source: Path, destination: Path) -> None:
                nonlocal failed
                if not failed and source == save and destination.name == "previous":
                    failed = True
                    raise OSError("injected pre-swap quarantine failure")
                original_replace(source, destination)

            with mock.patch.object(session, "_replace_path", side_effect=fail_quarantine):
                problems = session.restore()
            self.assertTrue(save.is_dir())
            self.assertEqual((save / "state.dat").read_bytes(), b"test-save")
            self._assert_retained_backup(session, problems)

            self.assertEqual(session.restore(), [])
            self.assertEqual((save / "state.dat").read_bytes(), b"original-save")

    def test_production_zip_restore_failure_is_not_silently_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            session, save, production_mod = self._fault_session(Path(temporary))
            original_copy_file = session._copy_file

            def fail_mod_stage(source: Path, destination: Path) -> None:
                if source == session.backup_mod:
                    raise OSError("injected mod restore failure")
                original_copy_file(source, destination)

            with mock.patch.object(session, "_copy_file", side_effect=fail_mod_stage):
                problems = session.restore()
            self.assertEqual((save / "state.dat").read_bytes(), b"original-save")
            self.assertEqual(production_mod.read_bytes(), b"test-mod")
            self.assertTrue(any(str(production_mod) in problem for problem in problems))
            self._assert_retained_backup(session, problems)

            self.assertEqual(session.restore(), [])
            self.assertEqual(production_mod.read_bytes(), b"production-mod")

    def test_final_save_verification_failure_rolls_back_and_allows_retry(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            session, save, _ = self._fault_session(Path(temporary))
            original_hash_tree = supervisor.hash_tree

            def fail_live_verification(path: Path) -> str:
                if path == save:
                    return "injected-wrong-hash"
                return original_hash_tree(path)

            with mock.patch.object(
                supervisor, "hash_tree", side_effect=fail_live_verification
            ):
                problems = session.restore()
            self.assertTrue(save.is_dir())
            self.assertEqual((save / "state.dat").read_bytes(), b"test-save")
            self._assert_retained_backup(session, problems)

            self.assertEqual(session.restore(), [])
            self.assertEqual((save / "state.dat").read_bytes(), b"original-save")

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
