mod identity;

use nix::{
    fcntl::{fcntl, FcntlArg, OFlag},
    poll::{poll, PollFd, PollFlags},
    sys::{prctl::set_pdeathsig, signal::Signal, stat::Mode},
    unistd::{getppid, mkfifo},
};
use serde_json::{Map, Value};
use std::{
    collections::HashSet,
    fs::{self, OpenOptions},
    io::{self, Read, Write},
    os::{
        fd::AsFd,
        unix::{fs::OpenOptionsExt, process::CommandExt},
    },
    path::Path,
    process::{Child, Command, Stdio},
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    time::{Duration, Instant},
};

const BARS: usize = 24;
const LINE_LIMIT: usize = 4096;
const SNAPSHOT_LIMIT: usize = 8 * 1024 * 1024;
const KINDS: [&str; 3] = ["sink-inputs", "clients", "sinks"];
const ZERO: &str = "0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0\n";
fn config(fifo: &Path) -> String {
    format!("[general]\nbars = 24\nframerate = 60\nautosens = 0\nsensitivity = 100\nlower_cutoff_freq = 60\n\n[input]\nmethod = fifo\nsource = {}\nsample_bits = 16\nsample_rate = 44100\nchannels = 2\n\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 65535\nbar_delimiter = 32\nframe_delimiter = 10\nchannels = mono\n\n[smoothing]\nnoise_reduction = 0\n\n[color]\ngradient = 0\n", fifo.display())
}
fn nonblocking(fd: &impl AsFd) -> io::Result<()> {
    let flags = OFlag::from_bits_truncate(fcntl(fd, FcntlArg::F_GETFL)?);
    fcntl(fd, FcntlArg::F_SETFL(flags | OFlag::O_NONBLOCK))?;
    Ok(())
}
// Exec the real program after arming pdeathsig, without pre_exec or unsafe code.
fn child_command(program: &str, args: &[&str]) -> io::Result<Command> {
    let mut cmd = Command::new(std::env::current_exe()?);
    cmd.arg("--child-exec")
        .arg(std::process::id().to_string())
        .arg(program)
        .args(args);
    cmd.stdin(Stdio::null()).stdout(Stdio::piped());
    Ok(cmd)
}
struct Process(Child);
impl Process {
    fn spawn(mut cmd: Command) -> io::Result<Self> {
        let mut p = Self(cmd.spawn()?);
        if let Some(stdout) = &mut p.0.stdout {
            nonblocking(stdout)?;
        }
        Ok(p)
    }
    fn dead(&mut self) -> io::Result<bool> {
        Ok(self.0.try_wait()?.is_some())
    }
    fn read(&mut self, buf: &mut [u8]) -> io::Result<Option<usize>> {
        match self.0.stdout.as_mut().unwrap().read(buf) {
            Err(e) if e.kind() == io::ErrorKind::WouldBlock => Ok(None),
            Err(e) if e.kind() == io::ErrorKind::Interrupted => Ok(None),
            result => result.map(Some),
        }
    }
}
impl Drop for Process {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}
struct Snapshot {
    child: Process,
    started: Instant,
    data: Vec<u8>,
    state: Map<String, Value>,
    kind: usize,
    eof: bool,
}
impl Snapshot {
    fn query(kind: usize) -> io::Result<Process> {
        let mut cmd = child_command("pactl", &["-f", "json", "list", KINDS[kind]])?;
        cmd.stderr(Stdio::null());
        Process::spawn(cmd)
    }
    fn new() -> io::Result<Self> {
        Ok(Self {
            child: Self::query(0)?,
            started: Instant::now(),
            data: Vec::new(),
            state: Map::new(),
            kind: 0,
            eof: false,
        })
    }
    fn pump(&mut self) -> io::Result<Option<Value>> {
        if self.started.elapsed() >= Duration::from_secs(2) {
            return Err(io::Error::new(
                io::ErrorKind::TimedOut,
                "pactl snapshot timed out",
            ));
        }
        let mut bytes = [0; 65536];
        // Bounded work per turn keeps signals and the other descriptors responsive.
        for _ in 0..4 {
            match self.child.read(&mut bytes)? {
                Some(0) => {
                    self.eof = true;
                    break;
                }
                Some(n) => {
                    if self.data.len() + n > SNAPSHOT_LIMIT {
                        return Err(io::Error::other("pactl snapshot exceeds 8 MiB"));
                    }
                    self.data.extend_from_slice(&bytes[..n]);
                }
                None => break,
            }
        }
        if !self.eof {
            return Ok(None);
        }
        let Some(status) = self.child.0.try_wait()? else {
            return Ok(None);
        };
        if !status.success() {
            return Err(io::Error::other("pactl snapshot failed"));
        }
        let value: Value = serde_json::from_slice(&self.data)?;
        if !value.is_array() {
            return Err(io::Error::other("pactl snapshot is not an array"));
        }
        self.state.insert(KINDS[self.kind].into(), value);
        self.kind += 1;
        if self.kind == KINDS.len() {
            return Ok(Some(Value::Object(std::mem::take(&mut self.state))));
        }
        self.child = Self::query(self.kind)?;
        self.started = Instant::now();
        self.data.clear();
        self.eof = false;
        Ok(None)
    }
}
struct Lines {
    data: Vec<u8>,
    discarding: bool,
}
impl Lines {
    fn new() -> Self {
        Self {
            data: Vec::new(),
            discarding: false,
        }
    }
    fn push(&mut self, bytes: &[u8], mut consume: impl FnMut(&[u8])) {
        for &b in bytes {
            if b == b'\n' {
                if !self.discarding {
                    consume(&self.data);
                }
                self.data.clear();
                self.discarding = false;
            } else if !self.discarding {
                if self.data.len() == LINE_LIMIT {
                    self.data.clear();
                    self.discarding = true;
                } else {
                    self.data.push(b);
                }
            }
        }
    }
}
fn frame(line: &[u8]) -> Option<Vec<u8>> {
    let line = std::str::from_utf8(line).ok()?;
    let bands: Vec<_> = line.split_whitespace().map(str::parse::<i64>).collect();
    if bands.len() != BARS {
        return None;
    }
    let bands: Option<Vec<_>> = bands
        .into_iter()
        .map(|v| v.ok().filter(|v| (0..=65535).contains(v)))
        .collect();
    let mut output = bands?
        .iter()
        .map(ToString::to_string)
        .collect::<Vec<_>>()
        .join(" ")
        .into_bytes();
    output.push(b'\n');
    Some(output)
}
struct Capture {
    cava: Process,
    parec: Option<Process>,
    starting: Instant,
    next_open: Instant,
    target: (u64, String),
    lines: Lines,
}
impl Capture {
    fn new(cfg: &Path, target: (u64, String)) -> io::Result<Self> {
        let cmd = child_command(
            "stdbuf",
            &[
                "-o0",
                "cava",
                "-p",
                cfg.to_str()
                    .ok_or_else(|| io::Error::other("non-UTF8 config path"))?,
            ],
        )?;
        Ok(Self {
            cava: Process::spawn(cmd)?,
            parec: None,
            starting: Instant::now(),
            next_open: Instant::now(),
            target,
            lines: Lines::new(),
        })
    }
    fn pump(&mut self, fifo: &Path, output: &mut Output) -> io::Result<()> {
        if self.cava.dead()?
            || self
                .parec
                .as_mut()
                .map(Process::dead)
                .transpose()?
                .unwrap_or(false)
        {
            return Err(io::Error::other("audio child exited"));
        }
        if self.parec.is_none() {
            if self.starting.elapsed() >= Duration::from_secs(1) {
                return Err(io::Error::other("cava did not open FIFO"));
            }
            if Instant::now() < self.next_open {
                return Ok(());
            }
            self.next_open = Instant::now() + Duration::from_millis(20);
            let writer = match OpenOptions::new()
                .write(true)
                .custom_flags(OFlag::O_NONBLOCK.bits())
                .open(fifo)
            {
                Ok(writer) => writer,
                Err(e) if e.raw_os_error() == Some(nix::libc::ENXIO) => return Ok(()),
                Err(e) => return Err(e),
            };
            let flags = OFlag::from_bits_truncate(fcntl(&writer, FcntlArg::F_GETFL)?);
            fcntl(&writer, FcntlArg::F_SETFL(flags & !OFlag::O_NONBLOCK))?;
            let index = self.target.0.to_string();
            let mut cmd = child_command(
                "parec",
                &[
                    "--monitor-stream",
                    &index,
                    "--device",
                    &self.target.1,
                    "--raw",
                    "--format=s16le",
                    "--rate=44100",
                    "--channels=2",
                    "--latency-msec=20",
                ],
            )?;
            cmd.stdout(Stdio::from(writer));
            self.parec = Some(Process::spawn(cmd)?);
        }
        let mut bytes = [0; 65536];
        match self.cava.read(&mut bytes)? {
            Some(0) => return Err(io::Error::other("cava EOF")),
            Some(n) => self.lines.push(&bytes[..n], |line| {
                if let Some(frame) = frame(line) {
                    output.queue(frame);
                }
            }),
            None => (),
        }
        Ok(())
    }
}
struct Output {
    current: Vec<u8>,
    offset: usize,
    next: Option<Vec<u8>>,
}
impl Output {
    fn new() -> Self {
        Self {
            current: Vec::new(),
            offset: 0,
            next: None,
        }
    }
    fn queue(&mut self, frame: Vec<u8>) {
        if self.current.is_empty() || self.offset == 0 {
            self.current = frame;
            self.offset = 0;
        } else {
            self.next = Some(frame);
        }
    }
    fn flush(&mut self, stdout: &mut impl Write) -> io::Result<()> {
        while !self.current.is_empty() {
            match stdout.write(&self.current[self.offset..]) {
                Ok(0) => return Err(io::Error::new(io::ErrorKind::BrokenPipe, "stdout closed")),
                Ok(n) => self.offset += n,
                Err(e)
                    if matches!(
                        e.kind(),
                        io::ErrorKind::WouldBlock | io::ErrorKind::Interrupted
                    ) =>
                {
                    break
                }
                Err(e) => return Err(e),
            }
            if self.offset == self.current.len() {
                self.current = self.next.take().unwrap_or_default();
                self.offset = 0;
            }
        }
        Ok(())
    }
}
fn run(args: &[String]) -> io::Result<()> {
    let mut identity = String::new();
    let mut desktop = String::new();
    let mut bus = String::new();
    let mut expected_parent = None;
    let mut it = args.iter();
    while let Some(arg) = it.next() {
        if arg == "--help" || arg == "-h" {
            println!("isla-cava-stream [--identity NAME] [--desktop FILE] [--bus MPRIS_BUS] [--parent PID]");
            return Ok(());
        }
        if arg == "--parent" {
            let pid: i32 = it
                .next()
                .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "missing parent PID"))?
                .parse()
                .map_err(io::Error::other)?;
            if pid <= 1 {
                return Err(io::Error::new(
                    io::ErrorKind::InvalidInput,
                    "invalid parent PID",
                ));
            }
            expected_parent = Some(pid);
            continue;
        }
        let target = match arg.as_str() {
            "--identity" => &mut identity,
            "--desktop" => &mut desktop,
            "--bus" => &mut bus,
            _ => {
                return Err(io::Error::new(
                    io::ErrorKind::InvalidInput,
                    "unknown argument",
                ))
            }
        };
        *target = it
            .next()
            .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "missing argument value"))?
            .clone();
    }
    let stopping = Arc::new(AtomicBool::new(false));
    for signal in [signal_hook::consts::SIGTERM, signal_hook::consts::SIGINT] {
        signal_hook::flag::register(signal, stopping.clone())?;
    }
    let parent = getppid();
    set_pdeathsig(Signal::SIGTERM)?;
    if getppid() != parent
        || parent.as_raw() == 1
        || expected_parent.is_some_and(|pid| parent.as_raw() != pid)
    {
        return Ok(());
    }
    let directory = tempfile::Builder::new().prefix("isla-cava-").tempdir()?;
    let fifo = directory.path().join("audio.fifo");
    let cfg = directory.path().join("cava.conf");
    mkfifo(&fifo, Mode::S_IRUSR | Mode::S_IWUSR)?;
    fs::write(&cfg, config(&fifo))?;
    let mut stdout = io::stdout();
    nonblocking(&stdout)?;
    let mut output = Output::new();
    let mut subscription: Option<Process> = None;
    let mut query: Option<Snapshot> = None;
    let mut capture: Option<Capture> = None;
    let mut clients = HashSet::new();
    let mut events = Lines::new();
    let mut retry_at = Instant::now();
    let mut refresh_at = retry_at;
    let mut capture_retry = retry_at;
    let mut selected = None;
    let mut last_zero = Instant::now() - Duration::from_secs(1);
    while !stopping.load(Ordering::Relaxed) && getppid() == parent {
        let now = Instant::now();
        if subscription.is_none() && now >= retry_at {
            let result = child_command("pactl", &["subscribe"]).and_then(|mut cmd| {
                cmd.env("LC_ALL", "C").stderr(Stdio::null());
                Process::spawn(cmd)
            });
            match result {
                Ok(child) => {
                    subscription = Some(child);
                    events = Lines::new();
                    refresh_at = now;
                }
                Err(e) => {
                    eprintln!("cava_stream: subscription: {e}");
                    retry_at = now + Duration::from_secs(1);
                }
            }
        }
        if query.is_none() && now >= refresh_at {
            match Snapshot::new() {
                Ok(job) => {
                    query = Some(job);
                    refresh_at = now + Duration::from_secs(30);
                }
                Err(e) => {
                    eprintln!("cava_stream: discovery: {e}");
                    selected = None;
                    refresh_at = now + Duration::from_secs(1);
                }
            }
        }
        if let Some(job) = &mut query {
            match job.pump() {
                Ok(Some(state)) => {
                    clients = identity::stream_clients(&state);
                    selected = identity::select(&state, &identity, &desktop, &bus);
                    query = None;
                    refresh_at = refresh_at.min(
                        Instant::now()
                            + Duration::from_secs(if subscription.is_some() { 30 } else { 1 }),
                    );
                }
                Ok(None) => (),
                Err(e) => {
                    eprintln!("cava_stream: discovery: {e}");
                    query = None;
                    selected = None;
                    refresh_at = Instant::now() + Duration::from_secs(1);
                }
            }
        }
        if capture
            .as_ref()
            .is_some_and(|c| Some(&c.target) != selected.as_ref())
        {
            capture = None;
            capture_retry = now;
        }
        if capture.is_none() && now >= capture_retry {
            if let Some(target) = &selected {
                match Capture::new(&cfg, target.clone()) {
                    Ok(c) => capture = Some(c),
                    Err(e) => {
                        eprintln!("cava_stream: capture: {e}");
                        capture_retry = now + Duration::from_secs(1);
                    }
                }
            }
        }
        if let Some(c) = &mut capture {
            if let Err(e) = c.pump(&fifo, &mut output) {
                eprintln!("cava_stream: stream: {e}");
                capture = None;
                capture_retry = now + Duration::from_secs(1);
                refresh_at = now;
            }
        }
        let mut disconnected = false;
        if let Some(child) = &mut subscription {
            let mut bytes = [0; 4096];
            match child.read(&mut bytes) {
                Ok(Some(0)) | Err(_) => disconnected = true,
                Ok(Some(n)) => events.push(&bytes[..n], |line| {
                    if identity::discovery_event(line, &clients) {
                        refresh_at = refresh_at.min(Instant::now() + Duration::from_millis(50));
                    }
                }),
                Ok(None) => (),
            }
            if child.dead()? {
                disconnected = true;
            }
        }
        if disconnected {
            subscription = None;
            query = None;
            capture = None;
            selected = None;
            retry_at = Instant::now() + Duration::from_secs(1);
            refresh_at = retry_at;
        }
        if capture.is_none() && last_zero.elapsed() >= Duration::from_millis(500) {
            output.queue(ZERO.as_bytes().to_vec());
            last_zero = Instant::now();
        }
        output.flush(&mut stdout)?;
        let mut fds = Vec::new();
        if let Some(p) = &subscription {
            fds.push(PollFd::new(
                p.0.stdout.as_ref().unwrap().as_fd(),
                PollFlags::POLLIN,
            ));
        }
        if let Some(q) = &query {
            if !q.eof {
                fds.push(PollFd::new(
                    q.child.0.stdout.as_ref().unwrap().as_fd(),
                    PollFlags::POLLIN,
                ));
            }
        }
        if let Some(c) = &capture {
            if c.parec.is_some() {
                fds.push(PollFd::new(
                    c.cava.0.stdout.as_ref().unwrap().as_fd(),
                    PollFlags::POLLIN,
                ));
            }
        }
        if !output.current.is_empty() {
            fds.push(PollFd::new(stdout.as_fd(), PollFlags::POLLOUT));
        }
        let mut deadline = Instant::now() + Duration::from_millis(100);
        if query.is_none() {
            deadline = deadline.min(refresh_at);
        }
        if subscription.is_none() {
            deadline = deadline.min(retry_at);
        }
        if let Some(c) = &capture {
            if c.parec.is_none() {
                deadline = deadline.min(c.next_open);
            }
        }
        let timeout = deadline
            .saturating_duration_since(Instant::now())
            .as_millis()
            .min(100) as u16;
        match poll(&mut fds, timeout) {
            Ok(_) | Err(nix::errno::Errno::EINTR) => (),
            Err(e) => return Err(e.into()),
        }
    }
    drop(capture);
    drop(query);
    drop(subscription);
    Ok(())
}
fn main() {
    let args: Vec<_> = std::env::args().skip(1).collect();
    if args.first().is_some_and(|s| s == "--child-exec") {
        let result = (|| -> io::Result<()> {
            let parent: i32 = args
                .get(1)
                .ok_or_else(|| io::Error::other("missing parent"))?
                .parse()
                .map_err(io::Error::other)?;
            set_pdeathsig(Signal::SIGKILL)?;
            if getppid().as_raw() != parent {
                return Err(io::Error::other("parent exited"));
            }
            let program = args
                .get(2)
                .ok_or_else(|| io::Error::other("missing child program"))?;
            Err(Command::new(program).args(&args[3..]).exec())
        })();
        if let Err(e) = result {
            eprintln!("cava_stream: child: {e}");
        }
        std::process::exit(1);
    }
    if let Err(e) = run(&args) {
        if e.kind() != io::ErrorKind::BrokenPipe {
            eprintln!("cava_stream: {e}");
            std::process::exit(1);
        }
    }
}

#[cfg(test)]
mod tests;
