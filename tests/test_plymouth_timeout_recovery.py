#!/usr/bin/env python3
"""Exercise the actual Plymouth recovery drop-in using isolated user units.

No system manager or real Plymouth/display-manager unit is changed. Runtime
units have an unpredictable prefix and are removed in a finally block. The
missing-MainPID case documents a deliberate boundary of --kill-whom=main.
"""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import uuid


HERE = Path(__file__).resolve().parent
DEFAULT_PATCH = HERE.parent / "usr/lib/systemd/system/plymouth-quit.service.d/timeout-recovery.conf"


def record(directory, name, **extra):
    with (directory / "events.jsonl").open("a") as stream:
        stream.write(json.dumps({"event": name, "monotonic": time.monotonic(), **extra}) + "\n")


def lock_available(directory):
    with (directory / "display.lock").open("a+") as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return False
        return True


def fixture(mode, directory):
    directory = Path(directory)
    if mode == "daemon":
        # A real forking service with one child, like the installed unit.
        read_fd, write_fd = os.pipe()
        child = os.fork()
        if child:
            os.close(write_fd)
            ready = os.read(read_fd, 1)
            os.close(read_fd)
            return 0 if ready == b"1" else 2
        os.close(read_fd)
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        with (directory / "display.lock").open("a+") as stream:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            (directory / "daemon.pid").write_text(str(os.getpid()))
            record(directory, "daemon_acquired_lock", pid=os.getpid())
            os.write(write_fd, b"1")
            os.close(write_fd)
            while not (directory / "quit.request").exists():
                time.sleep(0.01)
            record(directory, "daemon_clean_exit", pid=os.getpid())
        os._exit(0)
    if mode == "timeout":
        record(directory, "quit_client_started")
        time.sleep(600)
        return 0
    if mode == "success":
        record(directory, "quit_client_requested_exit")
        (directory / "quit.request").touch()
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if lock_available(directory):
                record(directory, "quit_client_success")
                return 0
            time.sleep(0.01)
        return 3
    if mode == "probe":
        available = lock_available(directory)
        record(directory, "login_probe", lock_available=available)
        print("display resource available" if available else "display resource busy", flush=True)
        return 0 if available else 12
    raise ValueError(mode)


def unit_quote(text):
    return '"' + str(text).replace("\\", "\\\\").replace('"', '\\"').replace("%", "%%") + '"'


class Suite:
    def __init__(self, patch, output):
        self.patch_path = patch.resolve()
        self.patch = patch.read_text()
        commands = "\n".join(line for line in self.patch.splitlines() if line.startswith("ExecStopPost="))
        if commands.count("/usr/bin/systemctl") != 1 or commands.count("plymouth-start.service") != 1:
            raise ValueError("Expected exactly one systemctl invocation and one daemon target in the actual drop-in")
        self.output = output
        self.prefix = "cachyos-plymouth-test-" + uuid.uuid4().hex[:12]
        self.runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
        self.unitdir = self.runtime / "systemd/user"
        self.unitdir.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix=self.prefix + "-", dir=self.runtime)
        self.state = Path(self.temporary.name)
        self.files = []
        self.directories = []
        self.units = []
        self.daemons = []
        self.logs = []
        self.results = {
            "started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "patch_path": str(self.patch_path),
            "patch_sha256": hashlib.sha256(self.patch.encode()).hexdigest(),
            "patch_text": self.patch,
            "fixture_prefix": self.prefix,
            "systemd_version": self.run(["systemctl", "--version"]).stdout.splitlines()[0],
            "scope": "ordinary user manager only; real Plymouth/display services untouched",
            "cases": [],
        }

    def run(self, command, timeout=15):
        result = subprocess.run(command, text=True, capture_output=True, timeout=timeout)
        self.logs.append("$ " + " ".join(command) + f"\nexit={result.returncode}\n" + result.stdout + result.stderr)
        return result

    def ctl(self, *arguments, timeout=15):
        return self.run(["systemctl", "--user", *arguments], timeout=timeout)

    def write(self, path, content):
        path.write_text(content)
        self.files.append(path)

    def properties(self, unit):
        result = self.ctl("show", unit, "--property=Id,ActiveState,SubState,MainPID,Result,ExecMainStatus,ExecMainStartTimestampMonotonic,ExecMainExitTimestampMonotonic")
        return dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)

    def case(self, name, patched, daemon_exists=True, client="timeout", guess_main_pid=True, restart_then_stop=False):
        directory = self.state / name
        directory.mkdir()
        stem = self.prefix + "-" + name
        daemon, quit_unit, probe = [stem + "-" + item + ".service" for item in ("daemon", "quit", "login")]
        self.units.extend([daemon, quit_unit, probe])
        self.daemons.append(daemon)
        executable = unit_quote(sys.executable) + " " + unit_quote(Path(__file__).resolve()) + " --fixture "

        def command(mode):
            return executable + mode + " " + unit_quote(directory)

        self.write(self.unitdir / daemon, "\n".join([
            "[Unit]", "Description=Isolated Plymouth lock fixture",
            "[Service]", "Type=forking", "RemainAfterExit=yes", "KillMode=mixed", "SendSIGKILL=no",
            "GuessMainPID=" + ("yes" if guess_main_pid else "no"),
            "ExecStart=" + command("daemon"), "",
        ]))
        self.write(self.unitdir / quit_unit, "\n".join([
            "[Unit]", "Description=Isolated Plymouth quit fixture", "After=" + daemon,
            "[Service]", "Type=oneshot", "RemainAfterExit=yes", "TimeoutSec=20",
            # Only the fixture client's start deadline is accelerated.
            "TimeoutStartSec=0.4s", "ExecStart=-" + command(client), "",
        ]))
        self.write(self.unitdir / probe, "\n".join([
            "[Unit]", "Description=Display-manager ordering and resource probe",
            "Wants=" + quit_unit, "After=" + quit_unit,
            "[Service]", "Type=oneshot", "ExecStart=" + command("probe"), "",
        ]))
        if patched:
            dropin = self.unitdir / (quit_unit + ".d")
            dropin.mkdir()
            self.directories.append(dropin)
            transformed = self.patch.replace("/usr/bin/systemctl", "/usr/bin/systemctl --user").replace("plymouth-start.service", daemon)
            self.write(dropin / "timeout-recovery.conf", transformed)
        self.ctl("daemon-reload")
        checks = []

        def check(label, condition):
            checks.append({"check": label, "passed": bool(condition)})

        initial = self.properties(daemon)
        if daemon_exists:
            started = self.ctl("start", daemon)
            initial = self.properties(daemon)
            check("forking daemon starts and holds the display resource", started.returncode == 0 and not lock_available(directory))
            check("MainPID tracking matches the requested fixture mode", (int(initial.get("MainPID", "0")) > 0) == guess_main_pid)
        begin = time.monotonic()
        display = self.ctl("start", probe)
        elapsed = time.monotonic() - begin
        properties = {"daemon": self.properties(daemon), "quit": self.properties(quit_unit), "login": self.properties(probe)}
        resource_free = lock_available(directory)
        events = [json.loads(line) for line in (directory / "events.jsonl").read_text().splitlines()]
        should_recover = not daemon_exists or client == "success" or (patched and guess_main_pid)
        check("ordered login probe matches expected resource availability", (display.returncode == 0) == should_recover and resource_free == should_recover)
        if client == "timeout":
            check("quit client actually reaches TimeoutStartSec", properties["quit"]["Result"] == "timeout")
            check("login probe runs after the timeout, not before", elapsed >= 0.35 and len([event for event in events if event["event"] == "login_probe"]) == 1)
        else:
            check("successful quit retains Result=success", properties["quit"]["Result"] == "success")
            check("daemon exits cleanly without timeout recovery", any(event["event"] == "daemon_clean_exit" for event in events))
        restart_properties = None
        if restart_then_stop:
            (directory / "quit.request").unlink()
            restarted = self.ctl("restart", daemon)
            before = self.properties(daemon)
            stopped = self.ctl("stop", quit_unit)
            after = self.properties(daemon)
            restart_properties = {"before_quit_stop": before, "after_quit_stop": after}
            check("normal stop does not kill a subsequently restarted daemon", restarted.returncode == 0 and stopped.returncode == 0 and before["MainPID"] == after["MainPID"] and int(after["MainPID"]) > 0 and not lock_available(directory))
        journal = self.run(["journalctl", "--user", "--no-pager", "-o", "short-monotonic", "-u", daemon, "-u", quit_unit, "-u", probe]).stdout
        case = {
            "name": name, "patched": patched, "daemon_exists": daemon_exists,
            "daemon_type": "forking", "remain_after_exit": True, "guess_main_pid": guess_main_pid,
            "client_mode": client, "duration_seconds": elapsed,
            "initial_daemon": initial, "properties_after_probe": properties,
            "display_start_exit_code": display.returncode, "resource_free_after_probe": resource_free,
            "events": events, "restart_properties": restart_properties, "checks": checks,
            "passed": all(item["passed"] for item in checks),
            "observed_recovery": should_recover and resource_free and display.returncode == 0,
        }
        if daemon_exists and not guess_main_pid:
            case["limitation"] = "The drop-in cannot terminate a daemon when its unit has MainPID=0: --kill-whom=main cannot select the remaining child. The ordered login probe remains blocked."
        self.results["cases"].append(case)
        self.logs.append("JOURNAL " + name + "\n" + journal)
        print(json.dumps({"case": name, "passed": case["passed"], "resource_free": resource_free, "duration_seconds": round(elapsed, 3), "checks": checks}), flush=True)

    def cleanup(self):
        errors = []
        # Only exact unique fixture unit names are addressed. Kill their own
        # cgroups first because the daemon deliberately ignores TERM and the
        # production-like daemon service has SendSIGKILL=no.
        for daemon in self.daemons:
            try:
                self.ctl("kill", "--kill-whom=all", "--signal=SIGKILL", daemon, timeout=10)
            except subprocess.TimeoutExpired:
                errors.append("Fixture cgroup kill timed out: " + daemon)
        for unit in reversed(self.units):
            try:
                self.ctl("stop", unit, timeout=10)
            except subprocess.TimeoutExpired:
                errors.append("Fixture stop timed out: " + unit)
        if self.units:
            self.ctl("reset-failed", *self.units)
        for path in reversed(self.files):
            path.unlink(missing_ok=True)
        for path in reversed(self.directories):
            path.rmdir()
        self.ctl("daemon-reload")
        leftover = self.ctl("list-units", "--all", "--no-legend", self.prefix + "*")
        if leftover.stdout.strip():
            errors.append("Fixture units still loaded: " + leftover.stdout)
        self.temporary.cleanup()
        self.results["cleanup_errors"] = errors
        return errors

    def save(self):
        self.results["all_expected_checks_passed"] = bool(self.results["cases"]) and all(case["passed"] for case in self.results["cases"]) and not self.results.get("cleanup_errors") and "exception" not in self.results
        self.results["finished_at"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
        self.output.write_text(json.dumps(self.results, indent=2, ensure_ascii=False) + "\n")
        self.output.with_suffix(".log").write_text("\n\n".join(self.logs))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", choices=["daemon", "timeout", "success", "probe"])
    parser.add_argument("directory", nargs="?")
    parser.add_argument("--drop-in", type=Path, default=DEFAULT_PATCH)
    parser.add_argument("--output", type=Path, default=Path("plymouth-timeout-results.json"))
    args = parser.parse_args()
    if args.fixture:
        return fixture(args.fixture, args.directory)
    if os.getuid() == 0:
        parser.error("Run as the regular desktop user, never as root")
    suite = Suite(args.drop_in, args.output)
    try:
        suite.case("baseline-timeout", patched=False)
        suite.case("patched-timeout", patched=True)
        suite.case("successful-quit", patched=True, client="success", restart_then_stop=True)
        suite.case("absent-daemon", patched=True, daemon_exists=False)
        suite.case("missing-mainpid", patched=True, guess_main_pid=False)
    except Exception as error:
        suite.results["exception"] = repr(error)
        raise
    finally:
        suite.cleanup()
        suite.save()
    print(json.dumps({"all_expected_checks_passed": suite.results["all_expected_checks_passed"], "results": str(suite.output), "cleanup_errors": suite.results["cleanup_errors"]}), flush=True)
    return 0 if suite.results["all_expected_checks_passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
