#!/usr/bin/env python3
"""Private, persistent snapshots for Isla's clipboard library."""
import json
import fcntl
import hashlib
import os
import re
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

ID = re.compile(r"^s-[0-9a-f]{32}$")
COLLECTION = re.compile(r"^c-[0-9a-f]{32}$")
HISTORY = re.compile(r"^[0-9]+$")


def location():
    override = os.environ.get("ISLA_CLIPBOARD_LIBRARY")
    if override:
        path = Path(override)
    else:
        base = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local/share")
        path = Path(base) / "isla/clipboard"
    if not path.is_absolute():
        raise ValueError("Library path must be absolute")
    return path


def private_directory(path):
    if path.is_symlink():
        raise ValueError("Library path may not be a symlink")
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.is_symlink() or not path.is_dir():
        raise ValueError("Invalid library path")
    os.chmod(path, 0o700)


def metadata_path(path):
    return path / "library.json"


def read(path):
    private_directory(path)
    file = metadata_path(path)
    if file.is_symlink():
        raise ValueError("Metadata may not be a symlink")
    if not file.exists():
        return {"version": 1, "collections": [], "entries": []}
    os.chmod(file, 0o600)
    raw = json.loads(file.read_text(encoding="utf-8"))
    if not isinstance(raw, dict) or raw.get("version") != 1 or not isinstance(raw.get("collections"), list) or not isinstance(raw.get("entries"), list):
        raise ValueError("Invalid library metadata")
    collections = set()
    for collection in raw["collections"]:
        if not isinstance(collection, dict) or not isinstance(collection.get("id"), str) or not COLLECTION.fullmatch(collection["id"]) or not isinstance(collection.get("name"), str) or not collection["name"].strip() or collection["id"] in collections:
            raise ValueError("Invalid collection metadata")
        collections.add(collection["id"])
    ids = set()
    for entry in raw["entries"]:
        if not isinstance(entry, dict) or not isinstance(entry.get("id"), str) or not ID.fullmatch(entry["id"]) or entry["id"] in ids or not isinstance(entry.get("text"), str) or not isinstance(entry.get("preview"), str) or not isinstance(entry.get("isImage"), bool) or not isinstance(entry.get("collectionId", ""), str) or entry.get("collectionId", "") not in collections | {""} or ("digest" in entry and (not isinstance(entry["digest"], str) or not re.fullmatch(r"[0-9a-f]{64}", entry["digest"]))):
            raise ValueError("Invalid entry metadata")
        ids.add(entry["id"])
    return raw


def commit(path, data):
    fd, temp = tempfile.mkstemp(prefix=".library-", dir=path)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            os.fchmod(stream.fileno(), 0o600)
            json.dump(data, stream, ensure_ascii=False, separators=(",", ":"))
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, metadata_path(path))
        dirfd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(dirfd)
        finally:
            os.close(dirfd)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def valid_id(value, pattern=ID):
    if not pattern.fullmatch(value):
        raise ValueError("Invalid ID")
    return value


def data_path(path, entry_id):
    return path / (valid_id(entry_id) + ".bin")


def read_snapshot(path, entry_id):
    file = data_path(path, entry_id)
    fd = os.open(file, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, "rb") as stream:
        return stream.read()


def entry(data, entry_id):
    return next((item for item in data["entries"] if item["id"] == valid_id(entry_id)), None)


def name(value):
    value = value.strip()
    if not value or len(value) > 100 or any(ord(c) < 32 for c in value):
        raise ValueError("Invalid collection name")
    return value


def _dispatch(args, path):
    if args[0] == "wipe":
        subprocess.run(["cliphist", "wipe"], check=True)
        return {}
    data = read(path)
    action = args[0]
    if action == "list":
        for item in data["entries"]:
            # Missing snapshots are errors; never silently drop user data.
            if data_path(path, item["id"]).is_symlink() or not data_path(path, item["id"]).is_file():
                raise FileNotFoundError(item["id"])
        return data
    if action == "save":
        if len(args) not in (5, 6):
            raise ValueError("Invalid save arguments")
        history_id, image_flag, text, preview = args[1:5]
        if not HISTORY.fullmatch(history_id):
            raise ValueError("Invalid history ID")
        if image_flag not in ("0", "1"):
            raise ValueError("Invalid image flag")
        collection_id = valid_id(args[5], COLLECTION) if len(args) > 5 and args[5] else ""
        if len(args) > 5 and args[5] and not any(item["id"] == collection_id for item in data["collections"]):
            raise ValueError("Unknown collection")
        payload = subprocess.run(["cliphist", "decode", history_id], check=True, stdout=subprocess.PIPE).stdout
        digest = hashlib.sha256(payload).hexdigest()
        for saved in data["entries"]:
            if saved["isImage"] == (image_flag == "1") and (saved.get("digest") or hashlib.sha256(read_snapshot(path, saved["id"])).hexdigest()) == digest:
                if len(args) > 5 and saved["collectionId"] != collection_id:
                    saved["collectionId"] = collection_id
                    commit(path, data)
                return {"id": saved["id"]}
        full_text = "" if image_flag == "1" else payload.decode("utf-8", errors="replace")
        item_id = "s-" + uuid.uuid4().hex
        file = data_path(path, item_id)
        fd = os.open(file, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        commit_started = False
        try:
            with os.fdopen(fd, "wb") as stream:
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
            item = {"id": item_id, "digest": digest, "text": full_text, "preview": preview if image_flag == "1" else full_text[:100], "isImage": image_flag == "1", "collectionId": collection_id}
            data["entries"].insert(0, item)
            commit_started = True
            commit(path, data)
        except Exception:
            # Once commit starts, replace may have succeeded even if fsync fails.
            # Keep the payload so metadata can never reference a missing snapshot.
            if not commit_started:
                file.unlink(missing_ok=True)
            raise
        return {"id": item_id}
    if action == "remove":
        item = entry(data, args[1])
        if item is None:
            raise ValueError("Unknown entry")
        data["entries"].remove(item)
        commit(path, data)
        data_path(path, item["id"]).unlink(missing_ok=True)
        return {}
    if action == "create":
        collection_name = name(args[1])
        if any(c["name"].casefold() == collection_name.casefold() for c in data["collections"]):
            raise ValueError("collection_exists")
        collection = {"id": "c-" + uuid.uuid4().hex, "name": collection_name}
        data["collections"].append(collection)
        commit(path, data)
        return collection
    if action == "rename":
        collection_id = valid_id(args[1], COLLECTION)
        collection = next((item for item in data["collections"] if item["id"] == collection_id), None)
        if collection is None:
            raise ValueError("Unknown collection")
        collection_name = name(args[2])
        if any(c["id"] != collection_id and c["name"].casefold() == collection_name.casefold() for c in data["collections"]):
            raise ValueError("collection_exists")
        collection["name"] = collection_name
        commit(path, data)
        return collection
    if action == "delete":
        collection_id = valid_id(args[1], COLLECTION)
        original = len(data["collections"])
        data["collections"] = [item for item in data["collections"] if item["id"] != collection_id]
        if len(data["collections"]) == original:
            raise ValueError("Unknown collection")
        for item in data["entries"]:
            if item["collectionId"] == collection_id:
                item["collectionId"] = ""
        commit(path, data)
        return {}
    if action == "move":
        item = entry(data, args[1])
        collection_id = args[2]
        if item is None or (collection_id and not any(c["id"] == valid_id(collection_id, COLLECTION) for c in data["collections"])):
            raise ValueError("Unknown entry or collection")
        item["collectionId"] = collection_id
        commit(path, data)
        return {}
    if action == "copy":
        item = entry(data, args[1])
        if item is None:
            raise ValueError("Unknown entry")
        subprocess.run(["wl-copy"], input=read_snapshot(path, item["id"]), check=True)
        return {}
    if action == "preview":
        item = entry(data, args[1])
        if item is None or not item["isImage"]:
            raise ValueError("Unknown image")
        target = Path(args[2])
        if not target.is_absolute() or target.is_symlink() or target.parent.is_symlink():
            raise ValueError("Invalid preview path")
        size = "768x320" if args[3] == "full" else "144x144" if args[3] == "thumb" else None
        if size is None:
            raise ValueError("Invalid preview size")
        subprocess.run(["magick", "-", "-auto-orient", "-thumbnail", size, "-strip", str(target)], input=read_snapshot(path, item["id"]), check=True)
        return {}
    raise ValueError("Unknown action")


def dispatch(args):
    path = location()
    private_directory(path)
    lock = path / ".lock"
    fd = os.open(lock, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        os.fchmod(fd, 0o600)
        fcntl.flock(fd, fcntl.LOCK_EX)
        return _dispatch(args, path)
    finally:
        os.close(fd)


if __name__ == "__main__":
    try:
        result = dispatch(sys.argv[1:])
        print(json.dumps({"ok": True, "data": result}, ensure_ascii=False))
    except (OSError, ValueError, KeyError, IndexError, json.JSONDecodeError, subprocess.CalledProcessError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        sys.exit(1)
