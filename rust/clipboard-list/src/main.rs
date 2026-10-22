use nix::fcntl::{Flock, FlockArg};
use serde_json::{json, Value};
use std::collections::HashSet;
use std::env;
use std::fs::{self, DirBuilder, File, OpenOptions, Permissions};
use std::io::{Read, Write};
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt};
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::process::ExitCode;

type Result<T> = std::result::Result<T, &'static str>;

fn location() -> Result<PathBuf> {
    #[allow(deprecated)]
    let home = env::var_os("HOME").or_else(|| env::home_dir().map(PathBuf::into_os_string));
    location_from(
        env::var_os("ISLA_CLIPBOARD_LIBRARY"),
        env::var_os("XDG_DATA_HOME"),
        home,
    )
}

fn location_from(
    override_path: Option<std::ffi::OsString>,
    data_home: Option<std::ffi::OsString>,
    home: Option<std::ffi::OsString>,
) -> Result<PathBuf> {
    let nonempty = |v: &std::ffi::OsString| !v.is_empty();
    let path = if let Some(path) = override_path.filter(nonempty) {
        PathBuf::from(path)
    } else {
        let base = data_home.filter(nonempty).map(PathBuf::from).or_else(|| {
            home.map(|home| {
                let home = if home.is_empty() {
                    PathBuf::from("/")
                } else {
                    PathBuf::from(home)
                };
                home.join(".local/share")
            })
        });
        base.ok_or("Unable to locate library")?
            .join("isla/clipboard")
    };
    if !path.is_absolute() {
        return Err("Library path must be absolute");
    }
    Ok(path)
}

fn private_directory(path: &Path) -> Result<()> {
    if path.is_symlink() {
        return Err("Library path may not be a symlink");
    }
    DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(path)
        .map_err(|_| "Unable to create library directory")?;
    let metadata = fs::symlink_metadata(path).map_err(|_| "Invalid library path")?;
    if !metadata.is_dir() {
        return Err("Invalid library path");
    }
    fs::set_permissions(path, Permissions::from_mode(0o700))
        .map_err(|_| "Unable to secure library directory")
}

fn lock(path: &Path) -> Result<Flock<File>> {
    let file = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .mode(0o600)
        .custom_flags(nix::libc::O_NOFOLLOW | nix::libc::O_NONBLOCK)
        .open(path.join(".lock"))
        .map_err(|_| "Unable to open library lock")?;
    if !file
        .metadata()
        .map_err(|_| "Invalid library lock")?
        .is_file()
    {
        return Err("Invalid library lock");
    }
    file.set_permissions(Permissions::from_mode(0o600))
        .map_err(|_| "Unable to secure library lock")?;
    Flock::lock(file, FlockArg::LockExclusive).map_err(|_| "Unable to lock library")
}

fn valid_id(value: &str, prefix: &str) -> bool {
    value.len() == 34 && value.starts_with(prefix) && hex(&value.as_bytes()[2..], 32)
}

fn hex(value: &[u8], length: usize) -> bool {
    value.len() == length
        && value
            .iter()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(byte))
}

fn python_whitespace(c: char) -> bool {
    c.is_whitespace() || ('\u{1c}'..='\u{1f}').contains(&c)
}

fn validate(data: &Value) -> Result<()> {
    let version = &data["version"];
    let version_one = version == &Value::Bool(true)
        || version.as_number().is_some_and(|number| {
            if number.is_f64() {
                number.as_f64() == Some(1.0)
            } else {
                number.as_u64() == Some(1)
            }
        });
    let (Some(collections), Some(entries)) =
        (data["collections"].as_array(), data["entries"].as_array())
    else {
        return Err("Invalid library metadata");
    };
    if !data.is_object() || !version_one {
        return Err("Invalid library metadata");
    }
    let mut collection_ids = HashSet::new();
    for collection in collections {
        let (Some(id), Some(name)) = (collection["id"].as_str(), collection["name"].as_str())
        else {
            return Err("Invalid collection metadata");
        };
        if !valid_id(id, "c-")
            || name.trim_matches(python_whitespace).is_empty()
            || !collection_ids.insert(id)
        {
            return Err("Invalid collection metadata");
        }
    }
    let mut ids = HashSet::new();
    for entry in entries {
        let Some(id) = entry["id"].as_str() else {
            return Err("Invalid entry metadata");
        };
        let collection = entry.get("collectionId").unwrap_or(&Value::Null);
        let collection_valid = entry.get("collectionId").is_none()
            || collection
                .as_str()
                .is_some_and(|id| id.is_empty() || collection_ids.contains(id));
        let digest_valid = entry.get("digest").is_none()
            || entry["digest"]
                .as_str()
                .is_some_and(|digest| hex(digest.as_bytes(), 64));
        if !valid_id(id, "s-")
            || !ids.insert(id)
            || !entry["text"].is_string()
            || !entry["preview"].is_string()
            || !entry["isImage"].is_boolean()
            || !collection_valid
            || !digest_valid
        {
            return Err("Invalid entry metadata");
        }
    }
    Ok(())
}

// serde_json's arbitrary_precision reserves a map key; escaped keys use Python too.
fn incompatible_keys(bytes: &[u8]) -> bool {
    let mut index = 0;
    while index < bytes.len() {
        if bytes[index] != b'"' {
            index += 1;
            continue;
        }
        let start = index;
        let mut escaped = false;
        index += 1;
        while index < bytes.len() && bytes[index] != b'"' {
            if bytes[index] == b'\\' {
                escaped = true;
                index += 1;
            }
            index += 1;
        }
        let end = index.min(bytes.len());
        index = index.saturating_add(1);
        let mut next = index;
        while next < bytes.len() && bytes[next].is_ascii_whitespace() {
            next += 1;
        }
        if bytes.get(next) == Some(&b':')
            && (escaped || &bytes[start + 1..end] == b"$serde_json::private::Number")
        {
            return true;
        }
    }
    false
}

fn list(path: &Path) -> Result<Value> {
    private_directory(path)?;
    let _lock = lock(path)?;
    let metadata_path = path.join("library.json");
    match fs::symlink_metadata(&metadata_path) {
        Ok(metadata) if metadata.is_file() => {}
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            return Ok(json!({"version": 1, "collections": [], "entries": []}));
        }
        _ => return Err("Invalid library metadata"),
    }
    // Python repairs permissions before reading, including existing mode-000 metadata.
    fs::set_permissions(&metadata_path, Permissions::from_mode(0o600))
        .map_err(|_| "Unable to secure library metadata")?;
    let mut file = match OpenOptions::new()
        .read(true)
        .custom_flags(nix::libc::O_NOFOLLOW | nix::libc::O_NONBLOCK)
        .open(&metadata_path)
    {
        Ok(file) => file,
        Err(_) => return Err("Unable to open library metadata"),
    };
    if !file
        .metadata()
        .map_err(|_| "Invalid library metadata")?
        .is_file()
    {
        return Err("Invalid library metadata");
    }
    file.set_permissions(Permissions::from_mode(0o600))
        .map_err(|_| "Unable to secure library metadata")?;
    let mut bytes = Vec::new();
    file.read_to_end(&mut bytes)
        .map_err(|_| "Unable to read library metadata")?;
    if incompatible_keys(&bytes) {
        return Err("Invalid library JSON");
    }
    let data: Value = serde_json::from_slice(&bytes).map_err(|_| "Invalid library JSON")?;
    validate(&data)?;
    for entry in data["entries"].as_array().unwrap() {
        let id = entry["id"].as_str().unwrap();
        if !fs::symlink_metadata(path.join(format!("{id}.bin")))
            .is_ok_and(|metadata| metadata.is_file())
        {
            return Err("Missing or invalid library snapshot");
        }
    }
    Ok(data)
}

fn main() -> ExitCode {
    let args: Vec<_> = env::args_os().skip(1).collect();
    let valid_args =
        (args.len() == 1 || (args.len() == 3 && args[1] == "--fallback")) && args[0] == "list";
    let mut result = if valid_args {
        location().and_then(|path| list(&path))
    } else {
        Err("Expected list with optional --fallback script")
    };
    // The list call has returned, releasing its lock before Python acquires it.
    if result == Err("Invalid library JSON") && args.len() == 3 {
        let _error = Command::new("python3").arg(&args[2]).arg("list").exec();
        result = Err("Unable to execute library fallback");
    }
    let (output, code) = match result {
        Ok(data) => (json!({"ok": true, "data": data}), ExitCode::SUCCESS),
        Err(error) => (json!({"ok": false, "error": error}), ExitCode::FAILURE),
    };
    let mut stdout = std::io::stdout().lock();
    if serde_json::to_writer(&mut stdout, &output).is_err() || stdout.write_all(b"\n").is_err() {
        return ExitCode::FAILURE;
    }
    code
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::symlink;
    use std::sync::atomic::{AtomicUsize, Ordering};

    struct Temp(PathBuf);
    impl Temp {
        fn new() -> Self {
            static NEXT: AtomicUsize = AtomicUsize::new(0);
            let path = env::temp_dir().join(format!(
                "isla-clipboard-list-{}-{}",
                std::process::id(),
                NEXT.fetch_add(1, Ordering::Relaxed)
            ));
            fs::create_dir(&path).unwrap();
            Self(path)
        }
    }
    impl Drop for Temp {
        fn drop(&mut self) {
            fs::remove_dir_all(&self.0).unwrap();
        }
    }

    fn fixture() -> Value {
        json!({"version":1,"collections":[{"id":format!("c-{}", "a".repeat(32)), "name":"Work"}],
            "entries":[{"id":format!("s-{}", "b".repeat(32)), "text":"secret\n🦀", "preview":"text", "isImage":false,
            "collectionId":format!("c-{}", "a".repeat(32)), "digest":"c".repeat(64)}],
            "unknown":{"number":123456789012345678901234567890_u128}})
    }

    #[test]
    fn reserved_or_escaped_keys_use_compatibility_path() {
        assert!(incompatible_keys(
            br#"{"$serde_json::private::Number":"123"}"#
        ));
        assert!(incompatible_keys(
            br#"{"\u0024serde_json::private::Number":"123"}"#
        ));
        assert!(!incompatible_keys(
            br#"{"text":"escaped\nvalue\u00e9\\and\"quotes","unknown":123}"#
        ));
        assert!(!incompatible_keys(
            br#"{"text":"$serde_json::private::Number"}"#
        ));
    }

    #[test]
    fn preserves_unknown_fields_and_python_versions() {
        let mut data = fixture();
        for version in [json!(1), json!(true), json!(1.0), json!(1e0)] {
            data["version"] = version;
            assert!(validate(&data).is_ok());
        }
        let encoded = serde_json::to_vec(&data).unwrap();
        assert_eq!(serde_json::from_slice::<Value>(&encoded).unwrap(), data);
        for version in [json!(false), json!(0), json!("1"), json!(null), json!(2)] {
            data["version"] = version;
            assert_eq!(validate(&data), Err("Invalid library metadata"));
        }
    }

    #[test]
    fn validates_all_entry_fields_and_references() {
        let invalid = [
            ("id", json!("s-invalid")),
            ("text", json!(null)),
            ("preview", json!(0)),
            ("isImage", json!(1)),
            ("collectionId", json!(null)),
            ("collectionId", json!(format!("c-{}", "e".repeat(32)))),
            ("digest", json!("A".repeat(64))),
            ("digest", json!(false)),
        ];
        for (field, value) in invalid {
            let mut data = fixture();
            data["entries"][0][field] = value;
            assert_eq!(validate(&data), Err("Invalid entry metadata"), "{field}");
        }
        let mut data = fixture();
        data["entries"][0]
            .as_object_mut()
            .unwrap()
            .remove("collectionId");
        data["entries"][0].as_object_mut().unwrap().remove("digest");
        assert!(validate(&data).is_ok());
        let duplicate = data["entries"][0].clone();
        data["entries"].as_array_mut().unwrap().push(duplicate);
        assert_eq!(validate(&data), Err("Invalid entry metadata"));
    }

    #[test]
    fn validates_collections_and_python_strip() {
        for name in ["", " \t\n", "\u{1c}\u{1d}\u{1e}\u{1f}\u{85}\u{a0}"] {
            let mut data = fixture();
            data["collections"][0]["name"] = json!(name);
            assert_eq!(validate(&data), Err("Invalid collection metadata"));
        }
        let mut data = fixture();
        data["collections"][0]["name"] = json!("\u{1c}x\u{1f}");
        assert!(validate(&data).is_ok());
        let duplicate = data["collections"][0].clone();
        data["collections"].as_array_mut().unwrap().push(duplicate);
        assert_eq!(validate(&data), Err("Invalid collection metadata"));
        for raw in [
            json!([]),
            json!(null),
            json!({"version":1,"collections":{},"entries":[]}),
        ] {
            assert_eq!(validate(&raw), Err("Invalid library metadata"));
        }
    }

    #[test]
    fn locations_obey_override_and_absolute_requirement() {
        let os = |s: &str| Some(std::ffi::OsString::from(s));
        assert_eq!(
            location_from(os("/override"), os("/xdg"), os("/home")).unwrap(),
            Path::new("/override")
        );
        assert_eq!(
            location_from(os(""), os("/xdg"), os("/home")).unwrap(),
            Path::new("/xdg/isla/clipboard")
        );
        assert_eq!(
            location_from(None, os(""), os("/home")).unwrap(),
            Path::new("/home/.local/share/isla/clipboard")
        );
        assert_eq!(
            location_from(None, None, os("")).unwrap(),
            Path::new("/.local/share/isla/clipboard")
        );
        assert!(location_from(os("relative"), None, None).is_err());
        assert!(location_from(None, None, None).is_err());
    }

    #[test]
    fn list_secures_files_and_rejects_missing_or_symlink_snapshots() {
        let temp = Temp::new();
        assert_eq!(
            list(&temp.0).unwrap(),
            json!({"version":1,"collections":[],"entries":[]})
        );
        assert!(!temp.0.join("library.json").exists());
        let bytes = serde_json::to_vec(&fixture()).unwrap();
        fs::write(temp.0.join("library.json"), &bytes).unwrap();
        assert!(list(&temp.0).is_err());
        let snapshot = temp.0.join(format!("s-{}.bin", "b".repeat(32)));
        symlink("library.json", &snapshot).unwrap();
        assert!(list(&temp.0).is_err());
        fs::remove_file(&snapshot).unwrap();
        fs::create_dir(&snapshot).unwrap();
        assert!(list(&temp.0).is_err());
        fs::remove_dir(&snapshot).unwrap();
        fs::write(&snapshot, b"unread payload").unwrap();
        fs::set_permissions(&snapshot, Permissions::from_mode(0o0)).unwrap();
        fs::set_permissions(temp.0.join("library.json"), Permissions::from_mode(0o0)).unwrap();
        assert_eq!(list(&temp.0).unwrap(), fixture());
        assert_eq!(fs::read(temp.0.join("library.json")).unwrap(), bytes);
        assert_eq!(
            fs::metadata(&temp.0).unwrap().permissions().mode() & 0o777,
            0o700
        );
        for name in [".lock", "library.json"] {
            assert_eq!(
                fs::metadata(temp.0.join(name))
                    .unwrap()
                    .permissions()
                    .mode()
                    & 0o777,
                0o600
            );
        }
    }

    #[test]
    fn symlink_roots_locks_and_metadata_are_rejected() {
        let temp = Temp::new();
        let root = temp.0.join("root");
        symlink(&temp.0, &root).unwrap();
        assert!(list(&root).is_err());
        symlink("target", temp.0.join(".lock")).unwrap();
        assert!(list(&temp.0).is_err());
        fs::remove_file(temp.0.join(".lock")).unwrap();
        symlink("missing", temp.0.join("library.json")).unwrap();
        assert!(list(&temp.0).is_err());
    }

    #[test]
    fn locks_are_exclusive_and_released() {
        let temp = Temp::new();
        let held = lock(&temp.0).unwrap();
        let contender = || {
            OpenOptions::new()
                .read(true)
                .write(true)
                .open(temp.0.join(".lock"))
                .unwrap()
        };
        assert!(Flock::lock(contender(), FlockArg::LockExclusiveNonblock).is_err());
        drop(held);
        assert!(Flock::lock(contender(), FlockArg::LockExclusiveNonblock).is_ok());
        fs::write(temp.0.join("library.json"), b"NaN").unwrap();
        assert_eq!(list(&temp.0), Err("Invalid library JSON"));
        assert!(Flock::lock(contender(), FlockArg::LockExclusiveNonblock).is_ok());
    }
}
