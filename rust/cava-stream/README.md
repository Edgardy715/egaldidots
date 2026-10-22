# Hybrid CAVA helper

Linux-only Rust backend for `bar/Singletons/Cava.qml`. The QML presentation,
native CAVA analysis and Pulse capture remain in place. `cava-stream.sh` execs
the installed Rust helper, or Python when the binary is unavailable. Evidence:
`docs/rust-cava-2026-10-21/REPORT.md`.

Build/install from the repository root with `sh scripts/build-cava-helper.sh`.
Cargo is a build dependency only; the installer builds this optional backend
when a Rust toolchain is available. Build output lives in the user's cache.
Remove `${XDG_DATA_HOME:-$HOME/.local/share}/isla/bin/isla-cava-stream` to return
to Python on the next capture. Keep `cava_stream.py`: it is both the fallback
and the source of parent-death setup used by the NetworkManager monitor.

```sh
cargo test --locked
cargo clippy --locked --all-targets -- -D warnings
cargo build --release --locked
./target/release/isla-cava-stream --identity Spotify \
  --desktop spotify.desktop --bus org.mpris.MediaPlayer2.spotify
```

The existing three CLI options default to empty strings. Optional `--parent PID`
checks the expected direct parent while arming the helper's parent-death signal;
pass the spawning process PID to close the startup ownership race. Without this
option, the helper takes its direct parent at startup as its owner. A process
already reparented to PID1 exits immediately. `--help` prints usage.

Selection resolves the stream's Pulse client index, then PipeWire object ID;
uses the same generic-name filtering and application/binary/desktop fallbacks;
rejects corked or ambiguous matches; and captures only the selected stream's
actual sink monitor. There is no default-sink or mixed-audio fallback. The same
24-band, 60Hz CAVA config is written into a private temporary directory with a
0600 FIFO. Native `stdbuf`, `cava`, `parec`, and `pactl` remain prerequisites.
Each output line contains 24 decimal bands in 0..65535. Silence emits zeros
at 2Hz when no capture is active.

One `poll` loop multiplexes discovery, CAVA output, and writable stdout; no
worker threads or busy waits. `pactl subscribe` triggers discovery on sink-input,
sink, server, or changes to owning clients. Events coalesce for 50ms; a 30s
reconciliation catches missed metadata. Disconnection/failure retries after 1s.
The three snapshot commands execute sequentially but do not block the loop;
each has a 2s timeout and 8MiB output ceiling. JSON snapshots must be arrays.

All children exec through the same executable's internal `--child-exec` mode,
which safely arms SIGKILL parent-death notification and validates the explicit
parent PID before exec. The helper handles SIGTERM/SIGINT, parent loss, child
failure/EOF, and BrokenPipe. Child handles kill and reap on every normal/error
exit path. No user-written unsafe code or alternate signal/pre-exec threads.

Deliberate bounded behavior: event/frame lines above 4096bytes are discarded
through newline. Under stdout backpressure, at most a partially written frame
and the newest complete frame are retained, so a blocked consumer does not
prevent cancellation. Frames use strict signed decimal parsing; malformed CAVA
output is dropped. Children receive SIGKILL on cleanup rather than Python's
SIGTERM followed by 500ms grace; these read-only capture/discovery processes have
no persistent state to flush. FIFO startup retains the 1s bound and 20ms retry.

Dependencies: `serde_json` for Pulse JSON, `nix` for safe Linux process/poll/FIFO
APIs, `signal-hook` for stop flags, and `tempfile` for secure cleanup and naming.
`Cargo.lock` pins transitive versions. Release uses size optimization, LTO,
one codegen unit, stripped symbols, and abort-on-panic.

Unit tests cover selection/client aliases/generic names/desktop/bus/ambiguity,
owner event filtering, complete CAVA configuration, validated bounded frames,
and nonblocking output frame integrity. Runtime lifecycle, native audio parity,
CPU/PSS, and latency benchmarks belong to the coordinator's separate harness;
a unit-test pass alone does not establish those properties.

Build verified with isolated rustc 1.99.1: `cargo test --locked` 7/7 PASS,
`cargo clippy --locked --all-targets -- -D warnings` PASS, release build PASS.
Initial stripped x86_64 release size: 449,776 bytes; dynamic dependencies are
libc/libgcc_s and the system loader. Benchmark results are recorded separately.

The finite runtime harness `python bar/tests/cava-rust-lifecycle.py` (from the
repository root) also passes all five tests: parent mismatch prevents spawning,
SIGTERM/SIGKILL stop active fake capture/subscription children, SIGTERM cancels
an in-flight blocked snapshot in under one second, a full stdout pipe permits
shutdown and BrokenPipe cleanup, and owner death stops the helper and its
children. It shadows pactl/CAVA/parec with fixtures and accesses no audio server.
Set `ISLA_CAVA_RUST_BINARY` to test another build. Exited zombies are treated as
terminated for SIGKILL/owner-death checks because the host init owns their reap;
normal SIGTERM/BrokenPipe cleanup is handled by the helper itself.
