use serde_json::Value;
use std::collections::HashSet;

fn string(v: &Value) -> String {
    match v {
        Value::Null => "None".into(),
        Value::String(s) => s.clone(),
        _ => v.to_string(),
    }
}
fn text(v: &Value) -> String {
    if v.is_null() || v == false || v == 0 || v == "" {
        String::new()
    } else {
        string(v)
    }
}
fn token(s: &str) -> String {
    s.trim().to_lowercase()
}
fn basename(s: &str) -> &str {
    s.trim_end_matches('/').rsplit('/').next().unwrap_or("")
}
fn desktop(s: &str) -> String {
    token(basename(s).strip_suffix(".desktop").unwrap_or(basename(s)))
}
fn generic(s: &str) -> bool {
    matches!(
        s.to_lowercase().as_str(),
        "webrtc voiceengine" | "chromium input" | "audio-src" | "playstream" | "recstream"
    )
}
fn label(v: &Value) -> String {
    let s = text(v).trim().to_owned();
    if generic(&s) {
        String::new()
    } else {
        s
    }
}
fn items<'a>(s: &'a Value, kind: &str) -> &'a [Value] {
    s[kind].as_array().map(Vec::as_slice).unwrap_or(&[])
}
fn client_id(item: &Value) -> String {
    if !item["client"].is_null() {
        string(&item["client"])
    } else {
        text(&item["properties"]["client.id"])
    }
}
fn owner<'a>(stream: &Value, clients: &'a [Value], empty_props_fallback: bool) -> &'a Value {
    let id = client_id(stream);
    let by_index = clients.iter().find(|c| string(&c["index"]) == id);
    if let Some(c) = by_index {
        if !empty_props_fallback || c["properties"].as_object().is_some_and(|p| !p.is_empty()) {
            return &c["properties"];
        }
    }
    clients
        .iter()
        .find(|c| string(&c["properties"]["object.id"]) == id)
        .map(|c| &c["properties"])
        .unwrap_or(&Value::Null)
}
fn app_name(stream: &Value, clients: &[Value]) -> String {
    let p = &stream["properties"];
    let o = owner(stream, clients, false);
    let binary_prop = text(&p["application.process.binary"]);
    let binary_owner = text(&o["application.process.binary"]);
    let binary = basename(if binary_prop.is_empty() {
        &binary_owner
    } else {
        &binary_prop
    });
    if !binary.is_empty() && generic(&text(&p["application.name"])) {
        return token(binary);
    }
    let candidates = [
        label(&p["application.name"]),
        label(&o["application.name"]),
        label(&p["application.desktop_file"]),
        label(&o["application.desktop_file"]),
        if generic(binary) {
            String::new()
        } else {
            binary.to_owned()
        },
        label(&p["node.name"]),
        label(&p["media.name"]),
    ];
    token(
        &candidates
            .into_iter()
            .find(|s| !s.is_empty())
            .unwrap_or_else(|| {
                let index = text(&stream["index"]);
                if index.is_empty() {
                    "Aplicación".into()
                } else {
                    index
                }
            }),
    )
}

pub fn select(s: &Value, identity: &str, desktop_file: &str, bus: &str) -> Option<(u64, String)> {
    let mut wanted = HashSet::from([token(identity), desktop(desktop_file)]);
    if let Some(suffix) = token(bus).strip_prefix("org.mpris.mediaplayer2.") {
        wanted.insert(suffix.split('.').next().unwrap_or("").into());
    }
    wanted.remove("");
    let clients = items(s, "clients");
    let mut matches = Vec::new();
    for stream in items(s, "sink-inputs") {
        let p = &stream["properties"];
        if stream["corked"] == true || token(&text(&p["pulse.corked"])) == "true" {
            continue;
        }
        let mut labels = HashSet::from([app_name(stream, clients)]);
        for source in [p, owner(stream, clients, true)] {
            labels.insert(token(basename(&text(
                &source["application.process.binary"],
            ))));
            labels.insert(desktop(&text(&source["application.desktop_file"])));
        }
        if wanted.is_disjoint(&labels) {
            continue;
        }
        if let Some(sink) = items(s, "sinks")
            .iter()
            .find(|sink| string(&sink["index"]) == string(&stream["sink"]))
        {
            let monitor = text(&sink["monitor_source"]);
            let index = string(&stream["index"]);
            if !monitor.is_empty() && !index.is_empty() && index.bytes().all(|c| c.is_ascii_digit())
            {
                if let Ok(index) = index.parse() {
                    matches.push((index, monitor));
                }
            }
        }
    }
    if matches.len() == 1 {
        matches.pop()
    } else {
        None
    }
}
pub fn stream_clients(s: &Value) -> HashSet<String> {
    let mut owners: HashSet<String> = items(s, "sink-inputs").iter().map(client_id).collect();
    let aliases: Vec<_> = items(s, "clients")
        .iter()
        .filter(|c| owners.contains(&string(&c["properties"]["object.id"])))
        .map(|c| string(&c["index"]))
        .collect();
    owners.extend(aliases);
    owners
}
pub fn discovery_event(line: &[u8], clients: &HashSet<String>) -> bool {
    let line = String::from_utf8_lossy(line);
    for (pos, _) in line.match_indices(" on ") {
        let tail = &line[pos + 4..];
        if ["sink-input", "sink", "server"].iter().any(|kind| {
            tail.strip_prefix(kind)
                .is_some_and(|rest| rest.is_empty() || rest.starts_with(char::is_whitespace))
        }) {
            return true;
        }
    }
    if let Some((_, tail)) = line.split_once("'change' on client #") {
        let id: String = tail.chars().take_while(char::is_ascii_digit).collect();
        let rest = &tail[id.len()..];
        return !id.is_empty()
            && (rest.is_empty() || rest.starts_with(char::is_whitespace))
            && clients.contains(&id);
    }
    false
}
