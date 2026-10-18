"""Resolve application identity from Pulse streams and their owning clients."""

from pathlib import PurePath


GENERIC_NAMES = {"webrtc voiceengine", "chromium input", "audio-src", "playstream", "recstream"}


def _label(value):
    value = str(value or "").strip()
    return value if value.lower() not in GENERIC_NAMES else ""


def _binary(value):
    return PurePath(str(value or "")).name


def stream_identity(item, clients):
    """Return display identity for a pactl sink-input or source-output."""
    props = item.get("properties") or {}
    client_id = str(item["client"]) if item.get("client") is not None else str(props.get("client.id") or "")
    client = next((entry for entry in clients if str(entry.get("index")) == client_id), None)
    if client is None:
        client = next((entry for entry in clients if
                       str((entry.get("properties") or {}).get("object.id")) == client_id), None)
    owner = (client or {}).get("properties") or {}
    binary = _binary(props.get("application.process.binary") or owner.get("application.process.binary"))
    app = (_label(props.get("application.name")) or _label(owner.get("application.name")) or
           _label(props.get("application.desktop_file")) or
           _label(owner.get("application.desktop_file")) or _label(binary) or
           _label(props.get("node.name")) or _label(props.get("media.name")))
    # A generic engine may report its own name while the process identifies the app.
    if binary and str(props.get("application.name") or "").lower() in GENERIC_NAMES:
        app = binary
    app = app or str(item.get("index") or "Aplicación")
    if app.islower():
        app = app[0].upper() + app[1:]
    icon = (props.get("application.icon_name") or owner.get("application.icon_name") or
            props.get("window.icon_name") or owner.get("window.icon_name") or
            props.get("application.desktop_file") or owner.get("application.desktop_file") or
            binary.lower())
    return {"appName": app, "mediaName": _label(props.get("media.name")),
            "icon": str(icon or "")}


def enrich_streams(raw):
    """Add resolved identity to a pactl snapshot without changing its other fields."""
    clients = raw.get("clients") or []
    result = dict(raw)
    for kind in ("sink-inputs", "source-outputs"):
        result[kind] = [{**item, "identity": stream_identity(item, clients)}
                        for item in raw.get(kind) or []]
    return result
