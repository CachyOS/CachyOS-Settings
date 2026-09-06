# Plymouth timeout recovery

Run from the repository root as a normal logged-in user with a running systemd
user manager (Python 3 and systemd are required):

```sh
python3 tests/test_plymouth_timeout_recovery.py --output /tmp/plymouth-timeout-results.json
```

The test reads the production drop-in and redirects its `systemctl` invocation
to uniquely named services in the user manager. It shortens the test client's
start timeout to 0.4 seconds. It never operates on system Plymouth or display
manager services. Temporary services and their processes are cleaned up; JSON
results and a companion `.log` file remain at the selected output path.

A forking daemon holds an exclusive file lock, simulating display ownership.
The login probe is ordered after the quit service and checks that the resource
is available. The cases cover:

- The unpatched timeout leaves the daemon and resource behind.
- The patched timeout releases the resource before the ordered login probe.
- A successful quit exits cleanly; stopping that successful quit service does
  not kill a subsequently restarted daemon.
- A timeout with no daemon returns without blocking the login probe.
- With `GuessMainPID=no`, recovery deliberately cannot select the daemon. The
  test expects the resource to remain occupied and documents this limitation.

These tests exercise actual systemd service ordering and process cleanup. They
do not reproduce a GPU/DRM driver hang or replace multi-monitor cold-boot
testing. The drop-in recovers from a killable daemon left after a quit timeout;
it does not fix the underlying cause of the Plymouth hang.
