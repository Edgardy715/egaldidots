use super::*;
use serde_json::json;

fn fixture() -> Value {
    json!({"clients":[
        {"index":116,"properties":{"object.id":"108","application.name":"spotify","application.process.binary":"spotify"}},
        {"index":88,"properties":{"application.name":"Discord","application.process.binary":"Discord"}}],
        "sinks":[{"index":58,"monitor_source":"actual.monitor"},{"index":57,"monitor_source":"default.monitor"}],
        "sink-inputs":[
        {"index":117,"client":"116","sink":58,"corked":false,"properties":{"client.id":"108","media.name":"audio-src"}},
        {"index":118,"client":"88","sink":58,"corked":false,"properties":{"application.name":"WEBRTC VoiceEngine","media.name":"playStream"}}]})
}
#[test]
fn exact_identity_and_monitor() {
    let s = fixture();
    assert_eq!(
        identity::select(
            &s,
            "Spotify",
            "spotify.desktop",
            "org.mpris.MediaPlayer2.spotify"
        ),
        Some((117, "actual.monitor".into()))
    );
    assert_eq!(
        identity::select(&s, "Discord", "", ""),
        Some((118, "actual.monitor".into()))
    );
    assert_eq!(
        identity::select(&s, "", "/usr/share/applications/spotify.desktop", ""),
        Some((117, "actual.monitor".into()))
    );
    assert_eq!(
        identity::select(&s, "", "", "org.mpris.MediaPlayer2.spotify.instance123"),
        Some((117, "actual.monitor".into()))
    );
    let mut s = s;
    s["sink-inputs"][0]["client"] = Value::Null;
    assert_eq!(
        identity::select(&s, "Spotify", "", ""),
        Some((117, "actual.monitor".into()))
    );
    assert!(identity::stream_clients(&s).contains("116"));
}
#[test]
fn unsafe_selections_are_silent() {
    assert_eq!(identity::select(&fixture(), "", "", ""), None);
    assert_eq!(identity::select(&fixture(), "Tidal", "", ""), None);
    for field in ["corked", "pulse.corked", "sink", "index", "ambiguous"] {
        let mut s = fixture();
        match field {
            "corked" => s["sink-inputs"][0]["corked"] = json!(true),
            "pulse.corked" => s["sink-inputs"][0]["properties"]["pulse.corked"] = json!(" TRUE "),
            "sink" => s["sink-inputs"][0]["sink"] = json!(999),
            "index" => s["sink-inputs"][0]["index"] = json!("bad"),
            _ => {
                let duplicate = s["sink-inputs"][0].clone();
                s["sink-inputs"].as_array_mut().unwrap().push(duplicate);
            }
        }
        assert_eq!(identity::select(&s, "Spotify", "", ""), None, "{field}");
    }
}
#[test]
fn identity_fallbacks() {
    let mut s = fixture();
    s["clients"][0]["properties"] = json!({"application.desktop_file":"/apps/player.desktop"});
    assert_eq!(
        identity::select(&s, "", "player.desktop", ""),
        Some((117, "actual.monitor".into()))
    );
    s["clients"][0]["properties"] = json!({});
    s["sink-inputs"][0]["properties"]["node.name"] = json!("player");
    assert_eq!(
        identity::select(&s, "player", "", ""),
        Some((117, "actual.monitor".into()))
    );
    s["sink-inputs"][0]["properties"]["node.name"] = Value::Null;
    s["sink-inputs"][0]["properties"]["media.name"] = json!("player");
    assert_eq!(
        identity::select(&s, "player", "", ""),
        Some((117, "actual.monitor".into()))
    );
}
#[test]
fn events_only_reconcile_relevant_owners() {
    let owners = identity::stream_clients(&fixture());
    for line in [
        "Event 'new' on sink-input #4",
        "Event 'remove' on sink #1",
        "Event 'change' on server #0",
        "Event 'change' on client #116",
    ] {
        assert!(
            identity::discovery_event(line.as_bytes(), &owners),
            "{line}"
        );
    }
    for line in [
        "Event 'new' on client #116",
        "Event 'remove' on client #116",
        "Event 'change' on client #9",
        "Event 'change' on source #1",
        "Event 'change' on sink-input-extra #1",
        "Event 'change' on client #116bad",
    ] {
        assert!(
            !identity::discovery_event(line.as_bytes(), &owners),
            "{line}"
        );
    }
}
#[test]
fn frames_are_bounded_validated_and_normalized() {
    let valid = ["65535"; 24].join(" ");
    assert_eq!(
        frame(valid.as_bytes()),
        Some(format!("{valid}\n").into_bytes())
    );
    assert_eq!(frame(["65536"; 24].join(" ").as_bytes()), None);
    assert_eq!(frame(["-1"; 24].join(" ").as_bytes()), None);
    assert_eq!(frame(["nan"; 24].join(" ").as_bytes()), None);
    assert_eq!(frame(b"1 2 3"), None);
    assert_eq!(
        frame(["+0001"; 24].join("\t").as_bytes()),
        Some(format!("{}\n", ["1"; 24].join(" ")).into_bytes())
    );
    let mut lines = Lines::new();
    let mut output = Vec::new();
    lines.push(&vec![b'x'; LINE_LIMIT + 100], |l| output.push(l.to_vec()));
    lines.push(b"\npartial", |l| output.push(l.to_vec()));
    assert!(output.is_empty());
    lines.push(b" line\n", |l| output.push(l.to_vec()));
    assert_eq!(output, vec![b"partial line".to_vec()]);
}
#[test]
fn complete_cava_config() {
    let cfg = config(Path::new("/tmp/audio.fifo"));
    for entry in [
        "bars = 24",
        "framerate = 60",
        "autosens = 0",
        "sensitivity = 100",
        "lower_cutoff_freq = 60",
        "method = fifo",
        "source = /tmp/audio.fifo",
        "sample_bits = 16",
        "sample_rate = 44100",
        "channels = 2",
        "method = raw",
        "raw_target = /dev/stdout",
        "data_format = ascii",
        "ascii_max_range = 65535",
        "bar_delimiter = 32",
        "frame_delimiter = 10",
        "channels = mono",
        "noise_reduction = 0",
        "gradient = 0",
    ] {
        assert!(cfg.lines().any(|l| l == entry), "{entry}");
    }
}
#[test]
fn output_keeps_complete_frames_after_partial_write() {
    struct Writer(Vec<u8>, bool);
    impl Write for Writer {
        fn write(&mut self, data: &[u8]) -> io::Result<usize> {
            if self.1 {
                return Err(io::ErrorKind::WouldBlock.into());
            }
            self.1 = true;
            let n = data.len().min(2);
            self.0.extend_from_slice(&data[..n]);
            Ok(n)
        }
        fn flush(&mut self) -> io::Result<()> {
            Ok(())
        }
    }
    let mut out = Output::new();
    let mut writer = Writer(Vec::new(), false);
    out.queue(b"123\n".to_vec());
    out.flush(&mut writer).unwrap();
    out.queue(b"456\n".to_vec());
    out.queue(b"789\n".to_vec());
    for _ in 0..5 {
        writer.1 = false;
        out.flush(&mut writer).unwrap();
    }
    assert_eq!(writer.0, b"123\n789\n");
}
