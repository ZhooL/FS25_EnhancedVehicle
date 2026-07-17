#!/usr/bin/env python3
"""Run the licensed local FS25 integration suite with transactional cleanup."""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET


REPOSITORY = Path(__file__).resolve().parent.parent
APP_ID = "2300320"
MOD_FILENAME = "FS25_EnhancedVehicle.zip"
GAME_PROCESS_MARKERS = (
    "farmingsimulator2025.exe",
    "farmingsimulator2025game.exe",
    "dedicatedserver.exe",
)
MARKER = re.compile(r"EVTEST (START|PASS|FAIL|SKIP|CAPTURE|COMPLETE)(?:\s+([^\r\n]*))?")
CAPTURE_VALUE = re.compile(
    r"([a-z0-9]+)=([^\s]+)"
)
COMPLETE_COUNTS = re.compile(r"pass=(\d+) fail=(\d+) skip=(\d+)")
MOD_LINE = re.compile(
    r'^\s*<mod\b[^>]*\bmodName="FS25_EnhancedVehicle"[^>]*/>\s*$', re.MULTILINE
)


class IntegrationError(RuntimeError):
    """Raised when safe local integration cannot complete."""


@dataclass
class CaseResult:
    name: str
    status: str
    reason: str = ""


@dataclass
class CaptureRequest:
    name: str
    red: float
    green: float
    blue: float
    x1: float
    y1: float
    x2: float
    y2: float


@dataclass
class ScreenshotMetrics:
    name: str
    path: str
    passed: bool
    reason: str
    pixel_count: int = 0
    largest_component: int = 0
    continuity: float = 0.0
    length_ratio: float = 0.0
    center_distance: float = 0.0


@dataclass
class ScenarioResult:
    mode: str
    completed: bool
    cases: list[CaseResult] = field(default_factory=list)
    captures: list[CaptureRequest] = field(default_factory=list)
    screenshots: list[ScreenshotMetrics] = field(default_factory=list)
    log_issues: list[str] = field(default_factory=list)
    elapsed_seconds: float = 0.0
    log_path: str = ""

    @property
    def passed(self) -> bool:
        return (
            self.completed
            and not self.log_issues
            and all(case.status != "fail" for case in self.cases)
            and all(metric.passed for metric in self.screenshots)
        )


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def hash_tree(root: Path) -> str:
    digest = hashlib.sha256()
    if not root.exists():
        digest.update(b"<missing>")
        return digest.hexdigest()
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix().encode("utf-8")
        digest.update(len(relative).to_bytes(4, "big"))
        digest.update(relative)
        if path.is_symlink():
            digest.update(b"L")
            digest.update(os.readlink(path).encode("utf-8", errors="surrogateescape"))
        elif path.is_dir():
            digest.update(b"D")
        elif path.is_file():
            digest.update(b"F")
            with path.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
        else:
            digest.update(b"O")
    return digest.hexdigest()


def discover_game_dir(explicit: Path | None) -> Path:
    candidates: list[Path] = []
    if explicit is not None:
        candidates.append(explicit)
    if os.environ.get("FS25_GAME_DIR"):
        candidates.append(Path(os.environ["FS25_GAME_DIR"]))
    home = Path.home()
    candidates.extend(
        (
            home / ".local/share/Steam/steamapps/common/Farming Simulator 25",
            home / ".steam/steam/steamapps/common/Farming Simulator 25",
        )
    )
    for candidate in candidates:
        if (candidate / "FarmingSimulator2025.exe").is_file():
            return candidate.resolve()
    raise IntegrationError("Farming Simulator 25 installation was not found; use --game-dir")


def discover_profile(explicit: Path | None) -> Path:
    candidates: list[Path] = []
    if explicit is not None:
        candidates.append(explicit)
    if os.environ.get("FS25_PROFILE"):
        candidates.append(Path(os.environ["FS25_PROFILE"]))
    relative = Path(
        "pfx/drive_c/users/steamuser/Documents/My Games/FarmingSimulator2025"
    )
    home = Path.home()
    candidates.extend(
        (
            home / ".steam/steam/steamapps/compatdata" / APP_ID / relative,
            home / ".local/share/Steam/steamapps/compatdata" / APP_ID / relative,
            home / "Documents/My Games/FarmingSimulator2025",
        )
    )
    for candidate in candidates:
        if (candidate / "gameSettings.xml").is_file():
            return candidate.resolve()
    raise IntegrationError("FS25 user profile was not found; use --profile")


def resolve_mods_dir(profile: Path, explicit: Path | None) -> Path:
    if explicit is not None:
        return explicit.resolve()
    settings = profile / "gameSettings.xml"
    try:
        root = ET.parse(settings).getroot()
    except (OSError, ET.ParseError) as error:
        raise IntegrationError(f"cannot inspect {settings}: {error}") from error
    override = root.find("modsDirectoryOverride")
    if override is not None and override.get("active") == "true":
        raise IntegrationError("an active modsDirectoryOverride requires explicit --mods-dir")
    return profile / "mods"


def fs25_processes() -> dict[int, str]:
    found: dict[int, str] = {}
    proc = Path("/proc")
    if not proc.is_dir():
        return found
    for entry in proc.iterdir():
        if not entry.name.isdigit():
            continue
        try:
            command = (entry / "cmdline").read_bytes().replace(b"\0", b" ").decode(
                "utf-8", errors="replace"
            )
        except (OSError, PermissionError):
            continue
        lowered = command.lower()
        if any(marker in lowered for marker in GAME_PROCESS_MARKERS):
            found[int(entry.name)] = command
    return found


def is_fs25_x11_window(
    title: str,
    wm_class: tuple[str, ...],
    window_pid: int | None,
    process_ids: set[int],
) -> bool:
    """Return whether an X11 window belongs to this supervised FS25 launch."""
    identity = " ".join((title, *wm_class)).lower()
    is_game = (
        "farming simulator 25" in identity
        or "farmingsimulator2025" in identity
        or f"steam_app_{APP_ID}" in identity
    )
    return is_game and window_pid is not None and window_pid in process_ids


def dismiss_fs25_load_screen(process_ids: set[int]) -> tuple[bool, str]:
    """Send Return directly to the supervised FS25 XWayland window.

    XSendEvent addresses one verified window and does not depend on the pointer
    position or whichever unrelated desktop window currently has focus.
    """
    if sys.platform != "linux" or not os.environ.get("DISPLAY"):
        return False, "targeted X11 input is unavailable on this platform"
    try:
        from Xlib import X, XK, display, error
        from Xlib.protocol import event
    except ImportError:
        return False, "python-xlib is required to dismiss the FS25 load screen"

    connection = None
    try:
        connection = display.Display()
        root = connection.screen().root
        pid_atom = connection.intern_atom("_NET_WM_PID")
        name_atom = connection.intern_atom("_NET_WM_NAME")
        utf8_atom = connection.intern_atom("UTF8_STRING")
        candidates = []
        pending = list(root.query_tree().children)
        while pending:
            window = pending.pop()
            try:
                pending.extend(window.query_tree().children)
                attributes = window.get_attributes()
                if attributes.map_state != X.IsViewable:
                    continue
                title = window.get_wm_name() or ""
                modern_title = window.get_full_property(name_atom, utf8_atom)
                if modern_title is not None and modern_title.value:
                    raw_title = modern_title.value
                    if isinstance(raw_title, bytes):
                        title = raw_title.decode("utf-8", errors="replace")
                    else:
                        title = str(raw_title)
                wm_class = tuple(window.get_wm_class() or ())
                pid_property = window.get_full_property(pid_atom, X.AnyPropertyType)
                window_pid = (
                    int(pid_property.value[0])
                    if pid_property is not None and len(pid_property.value) > 0
                    else None
                )
                if is_fs25_x11_window(title, wm_class, window_pid, process_ids):
                    candidates.append((window, title, window_pid))
            except (error.XError, UnicodeError, ValueError, TypeError):
                continue

        if len(candidates) != 1:
            return False, f"expected one supervised FS25 window, found {len(candidates)}"
        window, title, window_pid = candidates[0]
        keycode = connection.keysym_to_keycode(XK.string_to_keysym("Return"))
        if keycode == 0:
            return False, "X11 has no Return keycode"
        common = {
            "time": X.CurrentTime,
            "root": root,
            "window": window,
            "same_screen": 1,
            "child": X.NONE,
            "root_x": 0,
            "root_y": 0,
            "event_x": 0,
            "event_y": 0,
            "state": 0,
            "detail": keycode,
        }
        window.send_event(
            event.KeyPress(**common), event_mask=X.KeyPressMask, propagate=False
        )
        window.send_event(
            event.KeyRelease(**common), event_mask=X.KeyReleaseMask, propagate=False
        )
        connection.sync()
        return True, f"sent Return to {title!r} (pid {window_pid}, window {window.id})"
    except (error.DisplayConnectionError, error.XError, OSError, AttributeError) as exc:
        return False, f"targeted X11 input failed: {exc}"
    finally:
        if connection is not None:
            connection.close()


def terminate_processes(launcher: subprocess.Popen[bytes] | None, before: set[int]) -> None:
    if launcher is not None and launcher.poll() is None:
        try:
            os.killpg(launcher.pid, signal.SIGTERM)
        except (ProcessLookupError, PermissionError):
            launcher.terminate()
        try:
            launcher.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(launcher.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                launcher.kill()
    # Steam may return before Proton creates its child process. Keep a short
    # quarantine window and terminate every FS25 process that appears after the
    # pre-launch snapshot, including late descendants and respawns.
    deadline = time.monotonic() + 15
    kill_after = time.monotonic() + 6
    quiet_since: float | None = None
    while time.monotonic() < deadline:
        targets = set(fs25_processes()) - before
        if not targets:
            quiet_since = quiet_since or time.monotonic()
            if time.monotonic() - quiet_since >= 3:
                break
            time.sleep(0.2)
            continue
        quiet_since = None
        use_kill = time.monotonic() >= kill_after
        for process_id in targets:
            try:
                os.kill(process_id, signal.SIGKILL if use_kill else signal.SIGTERM)
            except (ProcessLookupError, PermissionError):
                pass
        time.sleep(0.2)


def discover_proton(game_dir: Path) -> tuple[Path, Path, Path]:
    """Resolve the Proton runtime and prefix which own this FS25 install."""
    steamapps = game_dir.parent.parent
    compat_data = steamapps / "compatdata" / APP_ID
    steam_root = steamapps.parent
    candidates: list[Path] = []
    override = os.environ.get("FS25_PROTON")
    if override:
        candidates.append(Path(override))
    config_info = compat_data / "config_info"
    if config_info.is_file():
        try:
            for line in config_info.read_text(encoding="utf-8", errors="replace").splitlines():
                marker = f"{os.sep}files{os.sep}"
                if marker in line:
                    candidates.append(Path(line.partition(marker)[0]) / "proton")
        except OSError:
            pass
    candidates.extend(
        (
            steamapps / "common" / "Proton - Experimental" / "proton",
            steamapps / "common" / "Proton Hotfix" / "proton",
        )
    )
    proton = next((path.resolve() for path in candidates if path.is_file()), None)
    if proton is None or not compat_data.is_dir():
        raise IntegrationError(
            "the FS25 Proton runtime/prefix was not found; set FS25_PROTON or use --launch-command"
        )
    return proton, compat_data.resolve(), steam_root.resolve()


def active_case(content: str) -> str | None:
    active: str | None = None
    for match in MARKER.finditer(content):
        kind, payload = match.groups()
        name = (payload or "").partition(" ")[0]
        if kind == "START":
            active = name
        elif kind in ("PASS", "FAIL", "SKIP") and name == active:
            active = None
        elif kind == "COMPLETE":
            active = None
    return active


def client_load_screen_ready(
    log_content: str, marker_content: str, log_stable_seconds: float
) -> bool:
    """Detect the load-complete presentation without image/OCR heuristics."""
    if "EVTEST START mission_load" in marker_content:
        return True
    return (
        "FTG '" in log_content
        and "max needed CPU instances" in log_content
        and log_stable_seconds >= 0.75
    )


def ensure_mod_enabled(career_save: Path) -> None:
    raw = career_save.read_bytes()
    has_bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig")
    replacement = (
        '    <mod modName="FS25_EnhancedVehicle" title="EnhancedVehicle" '
        'version="1.1.8.0" required="false"/>'
    )
    if MOD_LINE.search(text):
        text = MOD_LINE.sub(replacement, text)
    else:
        closing = "</careerSavegame>"
        if text.count(closing) != 1:
            raise IntegrationError("careerSavegame.xml has no unambiguous closing element")
        text = text.replace(closing, replacement + "\n" + closing)
    text = re.sub(
        r"(<autoSaveInterval>)[^<]*(</autoSaveInterval>)",
        r"\g<1>9999.000000\g<2>",
        text,
        count=1,
    )
    career_save.write_bytes((b"\xef\xbb\xbf" if has_bom else b"") + text.encode("utf-8"))
    try:
        ET.parse(career_save)
    except ET.ParseError as error:
        raise IntegrationError(f"temporary careerSavegame.xml is invalid: {error}") from error


class ProtectedSession:
    PROTECTED_FILES = (
        "game.xml",
        "gameSettings.xml",
        "inputBinding.xml",
        "log.txt",
        "EVTEST.status",
        "serverProcessId.dat",
    )
    PROTECTED_TREES = (
        "shader_cache",
        "dedicated_server",
        "modSettings/FS25_EnhancedVehicle",
    )

    def __init__(self, profile: Path, mods_dir: Path, savegame_id: int, test_zip: Path):
        self.profile = profile.resolve()
        self.mods_dir = mods_dir.resolve()
        self.savegame_id = savegame_id
        self.save_dir = self._protected_path(self.profile, f"savegame{savegame_id}")
        self.target_mod = self._protected_path(self.mods_dir, MOD_FILENAME)
        self.test_zip = test_zip.resolve()
        self.temp = Path(tempfile.mkdtemp(prefix="FS25_EV_TestSession."))
        self.backup_save = self.temp / "savegame"
        self.backup_mod = self.temp / MOD_FILENAME
        self.file_backups = self.temp / "profile-files"
        self.tree_backups = self.temp / "profile-trees"
        self.original_files: dict[str, str | None] = {}
        self.original_save_hash = ""
        self.original_mod_hash: str | None = None
        self.screenshots_before: set[str] = set()
        self.engine_logs_before: set[str] = set()
        self.original_trees: dict[str, str | None] = {}
        self._prepared = False

    @staticmethod
    def _protected_path(root: Path, relative_name: str) -> Path:
        relative = PurePosixPath(relative_name)
        if relative.is_absolute() or not relative.parts or ".." in relative.parts:
            raise IntegrationError(f"unsafe protected relative path: {relative_name!r}")
        root = root.resolve()
        target = root.joinpath(*relative.parts)
        try:
            target.resolve(strict=False).relative_to(root)
        except ValueError as error:
            raise IntegrationError(
                f"protected path escapes its root: {relative_name!r}"
            ) from error
        return target

    @staticmethod
    def _replace_path(source: Path, destination: Path) -> None:
        source.replace(destination)

    @staticmethod
    def _remove_path(path: Path) -> None:
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path)
        else:
            path.unlink(missing_ok=True)

    @staticmethod
    def _copy_tree(source: Path, destination: Path) -> None:
        shutil.copytree(source, destination, copy_function=shutil.copy2)

    @staticmethod
    def _copy_file(source: Path, destination: Path) -> None:
        shutil.copy2(source, destination)

    def _staging_root(self, target: Path) -> Path:
        target.parent.mkdir(parents=True, exist_ok=True)
        return Path(
            tempfile.mkdtemp(prefix=f".{target.name}.EVTestRestore.", dir=target.parent)
        ).resolve()

    def _restore_present_target(
        self,
        target: Path,
        backup: Path,
        expected_hash: str,
        *,
        tree: bool,
    ) -> list[str]:
        """Stage, verify, swap, and verify one protected target.

        The previous live target is kept in the staging directory until the
        replacement has passed final verification, allowing a failed swap or
        verification to roll back without leaving the live path missing.
        """
        problems: list[str] = []
        try:
            stage_root = self._staging_root(target)
        except OSError as error:
            return [f"could not create restoration staging path for {target}: {error}"]
        replacement = stage_root / "replacement"
        previous = stage_root / "previous"
        hash_target = hash_tree if tree else sha256
        moved_previous = False
        installed_replacement = False
        retain_stage = False
        try:
            if tree:
                self._copy_tree(backup, replacement)
            else:
                self._copy_file(backup, replacement)
            if hash_target(replacement) != expected_hash:
                raise OSError("staged replacement failed hash verification")

            if target.exists() or target.is_symlink():
                self._replace_path(target, previous)
                moved_previous = True
            try:
                self._replace_path(replacement, target)
                installed_replacement = True
            except OSError:
                if moved_previous and not target.exists():
                    try:
                        self._replace_path(previous, target)
                        moved_previous = False
                    except OSError:
                        # A second atomic rename may be unavailable after an
                        # injected or filesystem failure.  Copy the quarantined
                        # live value back as a last best-effort guard against a
                        # missing path, and retain all recovery material if it
                        # cannot be verified.
                        try:
                            if tree:
                                self._copy_tree(previous, target)
                            else:
                                self._copy_file(previous, target)
                            if hash_target(previous) != hash_target(target):
                                retain_stage = True
                        except OSError:
                            retain_stage = True
                raise

            if hash_target(target) != expected_hash:
                raise OSError("restored target failed final hash verification")

            if moved_previous:
                self._remove_path(previous)
                moved_previous = False
        except OSError as error:
            problems.append(f"could not restore {target}: {error}")
            if installed_replacement and moved_previous:
                failed = stage_root / "failed-replacement"
                try:
                    self._replace_path(target, failed)
                    installed_replacement = False
                    self._replace_path(previous, target)
                    moved_previous = False
                except OSError as rollback_error:
                    problems.append(f"could not roll back {target}: {rollback_error}")
                    retain_stage = True
                    if previous.exists() and not target.exists():
                        try:
                            if tree:
                                self._copy_tree(previous, target)
                            else:
                                self._copy_file(previous, target)
                            if hash_target(previous) != hash_target(target):
                                problems.append(
                                    f"copied rollback for {target} failed verification"
                                )
                        except OSError as copy_error:
                            problems.append(
                                f"could not copy quarantined value back to {target}: {copy_error}"
                            )
            if not target.exists():
                problems.append(f"protected path is missing after cleanup failure: {target}")
                retain_stage = True
        finally:
            if retain_stage:
                problems.append(f"retained swap recovery data at {stage_root}")
            else:
                try:
                    self._remove_path(stage_root)
                except OSError as error:
                    problems.append(f"could not remove restoration staging path {stage_root}: {error}")
        return problems

    def _restore_absent_target(self, target: Path) -> list[str]:
        """Remove only a test-created protected target, with quarantine."""
        if not target.exists() and not target.is_symlink():
            return []
        problems: list[str] = []
        try:
            stage_root = self._staging_root(target)
        except OSError as error:
            return [f"could not create restoration staging path for {target}: {error}"]
        previous = stage_root / "test-created"
        retain_stage = False
        try:
            self._replace_path(target, previous)
            if target.exists() or target.is_symlink():
                raise OSError("target remained present after quarantine")
            self._remove_path(previous)
        except OSError as error:
            problems.append(f"could not remove test-created path {target}: {error}")
            if previous.exists() and not target.exists():
                try:
                    self._replace_path(previous, target)
                except OSError as rollback_error:
                    problems.append(f"could not roll back {target}: {rollback_error}")
                    retain_stage = True
        finally:
            if retain_stage:
                problems.append(f"retained swap recovery data at {stage_root}")
            else:
                try:
                    self._remove_path(stage_root)
                except OSError as error:
                    problems.append(f"could not remove restoration staging path {stage_root}: {error}")
        return problems

    @property
    def screenshots_dir(self) -> Path:
        return self.profile / "screenshots"

    def screenshot_inventory(self) -> set[str]:
        if not self.screenshots_dir.is_dir():
            return set()
        return {
            path.relative_to(self.screenshots_dir).as_posix()
            for path in self.screenshots_dir.rglob("*")
            if path.is_file()
        }

    def engine_log_inventory(self) -> set[str]:
        return {path.name for path in self.profile.glob("log_*.txt") if path.is_file()}

    def new_engine_logs(self) -> list[Path]:
        paths = [
            self.profile / name
            for name in self.engine_log_inventory() - self.engine_logs_before
        ]
        return sorted(paths, key=lambda path: (path.stat().st_mtime_ns, path.name))

    def remove_new_engine_logs(self) -> None:
        for path in self.new_engine_logs():
            path.unlink(missing_ok=True)

    def backup(self) -> None:
        career = self.save_dir / "careerSavegame.xml"
        if not career.is_file():
            raise IntegrationError(f"savegame {self.savegame_id} is not usable: {career} is missing")
        if self.target_mod.with_suffix("").is_dir():
            raise IntegrationError(
                f"unpacked mod conflicts with the test ZIP: {self.target_mod.with_suffix('')}"
            )
        self.original_save_hash = hash_tree(self.save_dir)
        shutil.copytree(self.save_dir, self.backup_save, copy_function=shutil.copy2)
        if hash_tree(self.backup_save) != self.original_save_hash:
            raise IntegrationError("selected savegame backup failed hash verification")
        self.file_backups.mkdir(parents=True)
        self.tree_backups.mkdir(parents=True)
        for name in self.PROTECTED_FILES:
            path = self._protected_path(self.profile, name)
            backup = self._protected_path(self.file_backups, name)
            if path.is_file():
                self.original_files[name] = sha256(path)
                shutil.copy2(path, backup)
                if sha256(backup) != self.original_files[name]:
                    raise IntegrationError(f"profile file backup failed verification: {name}")
            else:
                self.original_files[name] = None
        for name in self.PROTECTED_TREES:
            path = self._protected_path(self.profile, name)
            backup = self._protected_path(self.tree_backups, name)
            if path.is_dir():
                self.original_trees[name] = hash_tree(path)
                backup.parent.mkdir(parents=True, exist_ok=True)
                shutil.copytree(path, backup, copy_function=shutil.copy2)
                if hash_tree(backup) != self.original_trees[name]:
                    raise IntegrationError(f"profile tree backup failed verification: {name}")
            else:
                self.original_trees[name] = None
        if self.target_mod.is_file():
            self.original_mod_hash = sha256(self.target_mod)
            shutil.copy2(self.target_mod, self.backup_mod)
            if sha256(self.backup_mod) != self.original_mod_hash:
                raise IntegrationError("production mod ZIP backup failed hash verification")
        self.screenshots_before = self.screenshot_inventory()
        self.engine_logs_before = self.engine_log_inventory()
        self._prepared = True

    def prepare_run(self, mode: str = "client") -> None:
        if not self._prepared:
            raise IntegrationError("profile backup has not completed")
        if self.save_dir.exists():
            shutil.rmtree(self.save_dir)
        shutil.copytree(self.backup_save, self.save_dir, copy_function=shutil.copy2)
        for name, expected in self.original_files.items():
            path = self.profile / name
            backup = self.file_backups / name
            if expected is None:
                path.unlink(missing_ok=True)
            else:
                shutil.copy2(backup, path)
        for name, expected in self.original_trees.items():
            path = self._protected_path(self.profile, name)
            if path.exists():
                shutil.rmtree(path)
            if expected is not None:
                backup = self._protected_path(self.tree_backups, name)
                path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copytree(backup, path, copy_function=shutil.copy2)
        self.mods_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(self.test_zip, self.target_mod)
        ensure_mod_enabled(self.save_dir / "careerSavegame.xml")
        (self.profile / "log.txt").unlink(missing_ok=True)
        (self.profile / "EVTEST.status").unlink(missing_ok=True)
        self.remove_new_engine_logs()
        self.remove_new_screenshots()
        if mode == "dedicated":
            dedicated = self.profile / "dedicated_server"
            dedicated.mkdir(parents=True, exist_ok=True)
            (dedicated / "dedicatedServerConfig.xml").write_text(
                "<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"no\"?>\n"
                "<gameserver>\n"
                "  <settings>\n"
                "    <game_name>EnhancedVehicle automated test</game_name>\n"
                "    <admin_password>EVTestAdminOnly</admin_password>\n"
                "    <game_password></game_password>\n"
                f"    <savegame_index>{self.savegame_id}</savegame_index>\n"
                "    <max_player>2</max_player>\n"
                "    <port>10823</port>\n"
                "    <language>en</language>\n"
                "    <auto_save_interval>9999</auto_save_interval>\n"
                "    <stats_interval>0</stats_interval>\n"
                "    <crossplay_allowed>false</crossplay_allowed>\n"
                "    <pause_game_if_empty>false</pause_game_if_empty>\n"
                "  </settings>\n"
                "  <mods>\n"
                "    <mod filename=\"FS25_EnhancedVehicle\" isDlc=\"false\" enabled=\"true\"/>\n"
                "  </mods>\n"
                "</gameserver>\n",
                encoding="utf-8",
            )

    def new_screenshots(self) -> list[Path]:
        names = self.screenshot_inventory() - self.screenshots_before
        paths = [self.screenshots_dir / name for name in names]
        return sorted(paths, key=lambda path: (path.stat().st_mtime_ns, path.name))

    def remove_new_screenshots(self) -> None:
        for name in self.screenshot_inventory() - self.screenshots_before:
            (self.screenshots_dir / name).unlink(missing_ok=True)

    def restore(self) -> list[str]:
        problems: list[str] = []
        if not self._prepared:
            shutil.rmtree(self.temp, ignore_errors=True)
            return problems
        problems.extend(
            self._restore_present_target(
                self.save_dir,
                self.backup_save,
                self.original_save_hash,
                tree=True,
            )
        )
        for name, expected in self.original_files.items():
            path = self._protected_path(self.profile, name)
            backup = self._protected_path(self.file_backups, name)
            if expected is None:
                problems.extend(self._restore_absent_target(path))
            else:
                problems.extend(
                    self._restore_present_target(path, backup, expected, tree=False)
                )
        for name, expected in self.original_trees.items():
            path = self._protected_path(self.profile, name)
            backup = self._protected_path(self.tree_backups, name)
            if expected is None:
                problems.extend(self._restore_absent_target(path))
            else:
                problems.extend(
                    self._restore_present_target(path, backup, expected, tree=True)
                )
        if self.original_mod_hash is None:
            problems.extend(self._restore_absent_target(self.target_mod))
        else:
            problems.extend(
                self._restore_present_target(
                    self.target_mod,
                    self.backup_mod,
                    self.original_mod_hash,
                    tree=False,
                )
            )

        try:
            self.remove_new_screenshots()
        except OSError as error:
            problems.append(f"could not remove test screenshots: {error}")
        try:
            self.remove_new_engine_logs()
        except OSError as error:
            problems.append(f"could not remove dedicated-server logs: {error}")

        try:
            if hash_tree(self.save_dir) != self.original_save_hash:
                problems.append("selected savegame was not restored byte-for-byte")
        except OSError as error:
            problems.append(f"could not verify selected savegame {self.save_dir}: {error}")
        for name, expected in self.original_files.items():
            path = self._protected_path(self.profile, name)
            try:
                actual = sha256(path) if path.is_file() else None
            except OSError as error:
                problems.append(f"could not verify profile file {path}: {error}")
                continue
            if actual != expected:
                problems.append(f"profile file was not restored: {path}")
        for name, expected in self.original_trees.items():
            path = self._protected_path(self.profile, name)
            try:
                actual = hash_tree(path) if path.is_dir() else None
            except OSError as error:
                problems.append(f"could not verify profile tree {path}: {error}")
                continue
            if actual != expected:
                problems.append(f"profile tree was not restored: {path}")
        try:
            actual_mod = sha256(self.target_mod) if self.target_mod.is_file() else None
        except OSError as error:
            actual_mod = None
            problems.append(f"could not verify production mod ZIP {self.target_mod}: {error}")
        if actual_mod != self.original_mod_hash:
            problems.append(f"installed production mod ZIP was not restored: {self.target_mod}")
        try:
            if self.screenshot_inventory() != self.screenshots_before:
                problems.append("test screenshots were not fully removed")
        except OSError as error:
            problems.append(f"could not verify screenshot cleanup: {error}")
        try:
            if self.engine_log_inventory() != self.engine_logs_before:
                problems.append("dedicated-server logs were not fully removed")
        except OSError as error:
            problems.append(f"could not verify dedicated-server log cleanup: {error}")

        if problems:
            problems.append(f"recovery backup retained at {self.temp.resolve()}")
        else:
            shutil.rmtree(self.temp, ignore_errors=True)
            self._prepared = False
        return problems


def parse_log(mode: str, content: str) -> tuple[list[CaseResult], list[CaptureRequest], bool]:
    cases: dict[str, CaseResult] = {}
    order: list[str] = []
    captures: list[CaptureRequest] = []
    protocol_errors: list[str] = []
    active: str | None = None
    complete_count = 0
    started_count = 0
    observed_counts = {"pass": 0, "fail": 0, "skip": 0}

    def protocol_error(message: str) -> None:
        protocol_errors.append(message)

    for match in MARKER.finditer(content):
        kind, raw_payload = match.groups()
        payload = (raw_payload or "").strip()
        if complete_count:
            protocol_error(f"{kind} marker appeared after COMPLETE")
        if kind == "COMPLETE":
            complete_count += 1
            if complete_count > 1:
                protocol_error("COMPLETE appeared more than once")
            count_match = COMPLETE_COUNTS.fullmatch(payload)
            if count_match is None:
                protocol_error(f"COMPLETE has malformed counts: {payload!r}")
            else:
                declared = dict(
                    zip(("pass", "fail", "skip"), map(int, count_match.groups()))
                )
                if declared != observed_counts:
                    protocol_error(
                        "COMPLETE counts do not match observed terminals: "
                        f"declared={declared}, observed={observed_counts}"
                    )
            if active is not None:
                protocol_error(f"COMPLETE appeared while case {active!r} was active")
            continue
        name, _, details = payload.partition(" ")
        if not name:
            protocol_error(f"{kind} marker has no case name")
            continue
        if kind == "START":
            if name in cases:
                protocol_error(f"case {name!r} has more than one START")
                continue
            if active is not None:
                protocol_error(f"case {name!r} started while {active!r} was active")
            order.append(name)
            cases[name] = CaseResult(name, "running")
            active = name
            started_count += 1
        elif kind in ("PASS", "FAIL", "SKIP"):
            if name not in cases:
                order.append(name)
                cases[name] = CaseResult(
                    name, "fail", f"{kind} terminal marker appeared without START"
                )
                protocol_error(f"case {name!r} has a terminal marker without START")
                observed_counts[kind.lower()] += 1
            elif cases[name].status != "running":
                protocol_error(f"case {name!r} has more than one terminal result")
            else:
                cases[name] = CaseResult(name, kind.lower(), details)
                observed_counts[kind.lower()] += 1
            if active != name:
                protocol_error(f"terminal marker for {name!r} was not the active case")
            elif cases[name].status != "running":
                active = None
        elif kind == "CAPTURE":
            required = {"r", "g", "b", "x1", "y1", "x2", "y2"}
            pairs: list[tuple[str, str]] = []
            malformed = False
            for token in details.split():
                value_match = CAPTURE_VALUE.fullmatch(token)
                if value_match is None:
                    malformed = True
                else:
                    pairs.append(value_match.groups())
            keys = [key for key, _ in pairs]
            values: dict[str, float] = {}
            malformed = malformed or set(keys) != required or len(keys) != len(required)
            if not malformed:
                try:
                    values = {key: float(value) for key, value in pairs}
                except ValueError:
                    malformed = True
                else:
                    malformed = not all(math.isfinite(value) for value in values.values())
            # Client graphics cases intentionally use case names such as
            # aa_taa and capture labels such as taa.  Those are the only
            # documented distinct case/capture names emitted by the runner.
            associated = active == name or active == f"aa_{name}"
            if active is None or not associated:
                protocol_error(
                    f"CAPTURE {name!r} is not associated with the active case {active!r}"
                )
            if malformed:
                protocol_error(f"CAPTURE {name!r} has malformed or non-finite fields")
            elif associated:
                captures.append(
                    CaptureRequest(
                        name,
                        values["r"],
                        values["g"],
                        values["b"],
                        values["x1"],
                        values["y1"],
                        values["x2"],
                        values["y2"],
                    )
                )
    for name in order:
        if cases[name].status == "running":
            cases[name] = CaseResult(name, "fail", "test process ended before the case completed")
            protocol_error(f"case {name!r} did not emit a terminal result")
    if started_count == 0:
        protocol_error("no test cases were executed")
    if complete_count != 1:
        protocol_error(
            "EVTEST COMPLETE marker was not observed"
            if complete_count == 0
            else "EVTEST COMPLETE marker count was invalid"
        )
    if protocol_errors:
        for index, reason in enumerate(protocol_errors, start=1):
            name = f"{mode}_protocol_{index}"
            order.append(name)
            cases[name] = CaseResult(name, "fail", reason)
    complete = complete_count == 1 and not protocol_errors
    return [cases[name] for name in order], captures, complete


def log_issues(content: str) -> list[str]:
    issues: list[str] = []
    for line in content.splitlines():
        lowered = line.lower()
        known_inline_mesh_warning = (
            "i3d contains non-binary indexed triangle sets" in lowered
            and "guidanceribbon.i3d" in lowered
        )
        is_error = "error:" in lowered or "lua call stack" in lowered
        ev_warning = "warning" in lowered and (
            "enhancedvehicle" in lowered or "evtest" in lowered
        )
        if (is_error or ev_warning) and not known_inline_mesh_warning:
            issues.append(line[-500:])
    return issues


def connected_components(points: set[tuple[int, int]]) -> int:
    largest = 0
    while points:
        seed = points.pop()
        stack = [seed]
        size = 0
        while stack:
            x, y = stack.pop()
            size += 1
            for nx in (x - 1, x, x + 1):
                for ny in (y - 1, y, y + 1):
                    neighbor = (nx, ny)
                    if neighbor in points:
                        points.remove(neighbor)
                        stack.append(neighbor)
        largest = max(largest, size)
    return largest


def analyze_screenshot(path: Path, request: CaptureRequest) -> ScreenshotMetrics:
    try:
        from PIL import Image
    except ImportError as error:
        raise IntegrationError(
            "Pillow is required for screenshot metrics; install it with python3 -m pip install Pillow"
        ) from error

    with Image.open(path) as source:
        image = source.convert("RGB")
        width, height = image.size
        expected_length = max(
            1.0,
            ((request.x2 - request.x1) ** 2 * width**2 + (request.y2 - request.y1) ** 2 * height**2)
            ** 0.5,
        )

        def inspect(invert_y: bool) -> tuple[int, int, float, float, float]:
            ys = [request.y1, request.y2]
            if invert_y:
                ys = [1 - value for value in ys]
            xs = [request.x1, request.x2]
            padding_x = max(24, int(width * 0.08))
            padding_y = max(24, int(height * 0.12))
            left = max(0, int(min(xs) * width) - padding_x)
            right = min(width, int(max(xs) * width) + padding_x)
            top = max(0, int(min(ys) * height) - padding_y)
            bottom = min(height, int(max(ys) * height) + padding_y)
            pixels = image.load()
            points: set[tuple[int, int]] = set()
            target = (request.red * 255, request.green * 255, request.blue * 255)
            for y in range(top, bottom):
                for x in range(left, right):
                    red, green, blue = pixels[x, y]
                    distance = abs(red - target[0]) + abs(green - target[1]) + abs(blue - target[2])
                    cyan_shape = green > 85 and blue > 75 and green > red * 1.25 and blue > red * 1.2
                    if distance < 245 and cyan_shape:
                        points.add((x, y))
            if not points:
                return 0, 0, 0.0, 0.0, 99.0
            saved = set(points)
            largest = connected_components(points)
            min_x = min(point[0] for point in saved)
            max_x = max(point[0] for point in saved)
            min_y = min(point[1] for point in saved)
            max_y = max(point[1] for point in saved)
            observed_length = max(max_x - min_x, max_y - min_y)
            expected_center_x = (request.x1 + request.x2) * 0.5
            expected_center_y = (ys[0] + ys[1]) * 0.5
            center_x = (min_x + max_x) * 0.5 / width
            center_y = (min_y + max_y) * 0.5 / height
            center_distance = ((center_x - expected_center_x) ** 2 + (center_y - expected_center_y) ** 2) ** 0.5
            return (
                len(saved),
                largest,
                largest / len(saved),
                observed_length / expected_length,
                center_distance,
            )

        candidates = (inspect(False), inspect(True))
        count, largest, continuity, length_ratio, center_distance = max(
            candidates, key=lambda item: (item[1], item[0])
        )
        minimum_pixels = max(20, int(expected_length * 0.12))
        passed = (
            count >= minimum_pixels
            and largest >= 10
            and continuity >= 0.04
            and 0.12 <= length_ratio <= 2.5
            and center_distance <= 0.25
        )
        reasons: list[str] = []
        if count < minimum_pixels:
            reasons.append(f"only {count} target-color pixels (minimum {minimum_pixels})")
        if largest < 10:
            reasons.append("no continuous target-color component")
        if continuity < 0.04:
            reasons.append(f"continuity {continuity:.3f} is too low")
        if not 0.12 <= length_ratio <= 2.5:
            reasons.append(f"projected length ratio {length_ratio:.3f} is outside broad bounds")
        if center_distance > 0.25:
            reasons.append(f"projected center error {center_distance:.3f} is too large")
        return ScreenshotMetrics(
            request.name,
            str(path),
            passed,
            "; ".join(reasons),
            count,
            largest,
            continuity,
            length_ratio,
            center_distance,
        )


def screenshot_results(
    scenario: str,
    requests: list[CaptureRequest],
    screenshots: list[Path],
    artifacts: Path,
) -> list[ScreenshotMetrics]:
    results: list[ScreenshotMetrics] = []
    for index, request in enumerate(requests):
        if index >= len(screenshots):
            results.append(
                ScreenshotMetrics(request.name, "", False, "screenshot file was not produced")
            )
            continue
        source = screenshots[index]
        destination = artifacts / f"{scenario}-{index + 1:02d}-{request.name}{source.suffix.lower()}"
        shutil.copy2(source, destination)
        results.append(analyze_screenshot(destination, request))
    if len(screenshots) > len(requests):
        for index, source in enumerate(screenshots[len(requests) :], start=len(requests) + 1):
            shutil.copy2(source, artifacts / f"{scenario}-{index:02d}-unexpected{source.suffix.lower()}")
    if len(results) > 1:
        passing_counts = [metric.pixel_count for metric in results if metric.pixel_count > 0]
        if passing_counts and max(passing_counts) / min(passing_counts) > 12:
            results.append(
                ScreenshotMetrics(
                    "aa_consistency",
                    "",
                    False,
                    "target-color visibility varies by more than 12x across AA modes",
                )
            )
        else:
            results.append(ScreenshotMetrics("aa_consistency", "", True, ""))
    return results


def build_launch_command(
    mode: str,
    savegame_id: int,
    game_dir: Path,
    override: str | None,
) -> list[str]:
    if override:
        values = {
            "mode": mode,
            "savegame_id": str(savegame_id),
            "game_exe": str(game_dir / "FarmingSimulator2025.exe"),
            "game_dir": str(game_dir),
        }
        return [part.format(**values) for part in shlex.split(override)]
    proton, compat_data, steam_root = discover_proton(game_dir)
    environment = shutil.which("env") or "/usr/bin/env"
    game_binary = game_dir / "x64" / "FarmingSimulator2025Game.exe"
    if not game_binary.is_file():
        raise IntegrationError(f"FS25 game binary is missing: {game_binary}")
    command = [
        environment,
        f"STEAM_COMPAT_DATA_PATH={compat_data}",
        f"STEAM_COMPAT_CLIENT_INSTALL_PATH={steam_root}",
        f"STEAM_COMPAT_APP_ID={APP_ID}",
        f"SteamAppId={APP_ID}",
        f"SteamGameId={APP_ID}",
        str(proton),
        "run",
        str(game_binary),
    ]
    if mode == "dedicated":
        command.append("-server")
    else:
        command.extend(("-autoStartSavegameId", str(savegame_id)))
    return command


def run_scenario(
    mode: str,
    command: list[str],
    profile: Path,
    session: ProtectedSession,
    artifacts: Path,
    timeout: float,
    startup_timeout: float,
    case_timeout: float,
    launch_cwd: Path,
) -> ScenarioResult:
    before = set(fs25_processes())
    if before:
        raise IntegrationError("FS25 is already running; close it before integration testing")
    started = time.monotonic()
    launcher: subprocess.Popen[bytes] | None = None
    completed = False
    latest = ""
    latest_markers = ""
    timeout_issue = ""
    observed_case: str | None = None
    observed_case_at = 0.0
    dismissal_started_at: float | None = None
    load_screen_dismissed = mode != "client"
    dismissal_reason = ""
    latest_log_signature = ""
    latest_log_changed_at = started
    try:
        launcher = subprocess.Popen(
            command,
            cwd=launch_cwd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        deadline = started + timeout
        marker_path = profile / "EVTEST.status"
        process_seen = False
        while time.monotonic() < deadline:
            if set(fs25_processes()) - before:
                process_seen = True
            engine_logs = session.new_engine_logs()
            log_path = (
                engine_logs[-1]
                if mode == "dedicated" and engine_logs
                else profile / "log.txt"
            )
            if log_path.is_file():
                try:
                    latest = log_path.read_text(encoding="utf-8", errors="replace")
                except OSError:
                    pass
            signature = f"{len(latest)}:{latest[-256:]}"
            if signature != latest_log_signature:
                latest_log_signature = signature
                latest_log_changed_at = time.monotonic()
            if marker_path.is_file():
                try:
                    latest_markers = marker_path.read_text(
                        encoding="utf-8", errors="replace"
                    )
                except OSError:
                    pass
            marker_content = latest_markers or latest
            log_stable_seconds = time.monotonic() - latest_log_changed_at
            if mode == "client" and client_load_screen_ready(
                latest, marker_content, log_stable_seconds
            ):
                dismissal_started_at = dismissal_started_at or time.monotonic()
                if not load_screen_dismissed:
                    load_screen_dismissed, dismissal_reason = dismiss_fs25_load_screen(
                        set(fs25_processes()) - before
                    )
                    if load_screen_dismissed:
                        print(f"FS25 load screen: {dismissal_reason}")
                    elif time.monotonic() - dismissal_started_at > 15:
                        timeout_issue = dismissal_reason
                        break
            engine_entered_gameplay = (
                mode != "dedicated" or "Info: Entered Gameplay" in latest
            )
            if "EVTEST COMPLETE" in marker_content and engine_entered_gameplay:
                completed = True
                time.sleep(2)
                break
            if marker_content:
                current_case = active_case(marker_content)
                if current_case != observed_case:
                    observed_case = current_case
                    observed_case_at = time.monotonic()
                elif current_case is not None and time.monotonic() - observed_case_at > case_timeout:
                    timeout_issue = (
                        f"supervisor case timeout after {case_timeout:.0f}s: {current_case}"
                    )
                    break
            if process_seen and not (set(fs25_processes()) - before):
                break
            if not process_seen and time.monotonic() - started > startup_timeout:
                break
            time.sleep(0.25)
    finally:
        terminate_processes(launcher, before)

    engine_logs = session.new_engine_logs()
    log_path = engine_logs[-1] if mode == "dedicated" and engine_logs else profile / "log.txt"
    if log_path.is_file():
        latest = log_path.read_text(encoding="utf-8", errors="replace")
    marker_path = profile / "EVTEST.status"
    if marker_path.is_file():
        latest_markers = marker_path.read_text(encoding="utf-8", errors="replace")

    elapsed = time.monotonic() - started
    log_artifact = artifacts / f"{mode}.log"
    log_artifact.write_text(latest, encoding="utf-8")
    cases, captures, marker_complete = parse_log(mode, latest_markers or latest)
    screenshots = screenshot_results(
        mode, captures, session.new_screenshots(), artifacts
    )
    return ScenarioResult(
        mode=mode,
        completed=completed and marker_complete,
        cases=cases,
        captures=captures,
        screenshots=screenshots,
        log_issues=log_issues(latest) + ([timeout_issue] if timeout_issue else []),
        elapsed_seconds=elapsed,
        log_path=str(log_artifact),
    )


def write_junit(path: Path, scenarios: list[ScenarioResult], cleanup: list[str]) -> None:
    suite = ET.Element("testsuite", name="FS25 EnhancedVehicle integration")
    failures = 0
    skipped = 0
    count = 0
    for scenario in scenarios:
        for result in scenario.cases:
            count += 1
            test = ET.SubElement(suite, "testcase", classname=scenario.mode, name=result.name)
            if result.status == "fail":
                failures += 1
                ET.SubElement(test, "failure", message=result.reason).text = result.reason
            elif result.status == "skip":
                skipped += 1
                ET.SubElement(test, "skipped", message=result.reason)
        for metric in scenario.screenshots:
            count += 1
            test = ET.SubElement(suite, "testcase", classname=f"{scenario.mode}.screenshot", name=metric.name)
            if not metric.passed:
                failures += 1
                ET.SubElement(test, "failure", message=metric.reason).text = metric.reason
        for index, issue in enumerate(scenario.log_issues, start=1):
            count += 1
            failures += 1
            test = ET.SubElement(suite, "testcase", classname=f"{scenario.mode}.log", name=f"issue_{index}")
            ET.SubElement(test, "failure", message=issue).text = issue
    for index, issue in enumerate(cleanup, start=1):
        count += 1
        failures += 1
        test = ET.SubElement(suite, "testcase", classname="cleanup", name=f"restore_{index}")
        ET.SubElement(test, "failure", message=issue).text = issue
    suite.set("tests", str(count))
    suite.set("failures", str(failures))
    suite.set("skipped", str(skipped))
    ET.ElementTree(suite).write(path, encoding="utf-8", xml_declaration=True)


def print_results(scenarios: list[ScenarioResult], cleanup: list[str]) -> None:
    for scenario in scenarios:
        print(f"{scenario.mode}: {'PASS' if scenario.passed else 'FAIL'} ({scenario.elapsed_seconds:.1f}s)")
        for case_result in scenario.cases:
            suffix = f" - {case_result.reason}" if case_result.reason else ""
            print(f"  {case_result.status.upper():4} {case_result.name}{suffix}")
        for metric in scenario.screenshots:
            suffix = f" - {metric.reason}" if metric.reason else ""
            print(f"  {'PASS' if metric.passed else 'FAIL':4} screenshot:{metric.name}{suffix}")
        for issue in scenario.log_issues:
            print(f"  FAIL log: {issue}")
    for issue in cleanup:
        print(f"cleanup: FAIL - {issue}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--savegame-id", required=True, type=int)
    parser.add_argument("--mode", choices=("client", "dedicated", "all"), default="all")
    parser.add_argument("--game-dir", type=Path)
    parser.add_argument("--profile", type=Path)
    parser.add_argument("--mods-dir", type=Path)
    parser.add_argument(
        "--launch-command",
        help="override launch command; supports {mode}, {savegame_id}, {game_exe}, {game_dir}",
    )
    parser.add_argument("--timeout", type=float, default=600, help="seconds per scenario")
    parser.add_argument(
        "--startup-timeout",
        type=float,
        default=120,
        help="seconds to allow Steam/Proton to create the game process",
    )
    parser.add_argument(
        "--case-timeout",
        type=float,
        default=120,
        help="supervisor timeout for one EVTEST case",
    )
    parser.add_argument("--skip-validation", action="store_true")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="validate configuration and build the temporary ZIP without touching the game profile",
    )
    parser.add_argument("--artifacts", type=Path)
    args = parser.parse_args()

    if not 1 <= args.savegame_id <= 20:
        parser.error("--savegame-id must be between 1 and 20")
    if args.timeout < 60:
        parser.error("--timeout must be at least 60 seconds")
    if args.startup_timeout < 30 or args.startup_timeout >= args.timeout:
        parser.error("--startup-timeout must be at least 30 seconds and less than --timeout")
    if args.case_timeout < 30 or args.case_timeout >= args.timeout:
        parser.error("--case-timeout must be at least 30 seconds and less than --timeout")

    artifacts = args.artifacts or (
        REPOSITORY
        / "build"
        / "fs25-tests"
        / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    )
    artifacts = artifacts.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    scenarios: list[ScenarioResult] = []
    cleanup_problems: list[str] = []

    try:
        game_dir = discover_game_dir(args.game_dir)
        profile = discover_profile(args.profile)
        mods_dir = resolve_mods_dir(profile, args.mods_dir)
        if fs25_processes():
            raise IntegrationError("FS25 is already running; close it before integration testing")
        if not args.skip_validation:
            subprocess.run([str(REPOSITORY / "scripts" / "validate.sh")], cwd=REPOSITORY, check=True)
        subprocess.run(
            [sys.executable, str(REPOSITORY / "tests" / "check_engine_contract.py"), "--required"],
            cwd=REPOSITORY,
            check=True,
        )
        with tempfile.TemporaryDirectory(prefix="FS25_EV_TestBuild.") as temporary:
            test_zip = Path(temporary) / MOD_FILENAME
            subprocess.run(
                [sys.executable, str(REPOSITORY / "scripts" / "build_integration.py"), str(test_zip)],
                cwd=REPOSITORY,
                check=True,
            )
            modes = [args.mode] if args.mode != "all" else ["client", "dedicated"]
            if "client" in modes and importlib.util.find_spec("PIL") is None:
                raise IntegrationError(
                    "Pillow is required for screenshot metrics; install it with "
                    "python3 -m pip install Pillow"
                )
            commands = {
                mode: build_launch_command(mode, args.savegame_id, game_dir, args.launch_command)
                for mode in modes
            }
            preflight = {
                "game_dir": str(game_dir),
                "profile": str(profile),
                "mods_dir": str(mods_dir),
                "savegame_id": args.savegame_id,
                "modes": modes,
                "commands": commands,
                "test_zip_sha256": sha256(test_zip),
                "dry_run": args.dry_run,
            }
            (artifacts / "preflight.json").write_text(
                json.dumps(preflight, indent=2) + "\n", encoding="utf-8"
            )
            if args.dry_run:
                print(f"FS25 integration dry run passed; artifacts: {artifacts}")
                return 0

            session = ProtectedSession(profile, mods_dir, args.savegame_id, test_zip)
            try:
                session.backup()
                for mode in modes:
                    session.prepare_run(mode)
                    result = run_scenario(
                        mode,
                        commands[mode],
                        profile,
                        session,
                        artifacts,
                        args.timeout,
                        args.startup_timeout,
                        args.case_timeout,
                        game_dir,
                    )
                    scenarios.append(result)
            finally:
                cleanup_problems = session.restore()
    except (IntegrationError, OSError, subprocess.CalledProcessError) as error:
        cleanup_problems.append(str(error))

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "passed": bool(scenarios)
        and all(scenario.passed for scenario in scenarios)
        and not cleanup_problems,
        "scenarios": [asdict(scenario) | {"passed": scenario.passed} for scenario in scenarios],
        "cleanup_problems": cleanup_problems,
    }
    (artifacts / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    write_junit(artifacts / "junit.xml", scenarios, cleanup_problems)
    print_results(scenarios, cleanup_problems)
    print(f"FS25 integration artifacts: {artifacts}")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
