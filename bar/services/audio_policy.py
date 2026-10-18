"""Choose ALSA card profiles for independent playback and capture switches."""


def _profiles(card):
    profiles = card.get("profiles") or {}
    if isinstance(profiles, dict):
        profiles = [{"name": name, **value} for name, value in profiles.items()]
    return profiles


def _active(card):
    name = card.get("activeProfile", card.get("active_profile"))
    return next((profile for profile in _profiles(card) if profile.get("name") == name), None)


def _enabled(profile, direction):
    return bool(int(profile.get("sinks" if direction == "output" else "sources") or 0))


def choose_profile(card, direction, enabled):
    """Choose an available profile while keeping the other direction's state."""
    if direction not in ("output", "input") or not isinstance(enabled, bool):
        raise ValueError("Dirección o estado de audio inválido")
    active = _active(card)
    if active is None:
        raise ValueError("El perfil activo de la tarjeta no está disponible")
    other = "input" if direction == "output" else "output"
    if _enabled(active, direction) == enabled:
        return active["name"]
    candidates = [profile for profile in _profiles(card)
                  if profile.get("available") not in (False, "no", "unavailable", "not available") and
                  _enabled(profile, direction) == enabled and
                  _enabled(profile, other) == _enabled(active, other)]
    if not candidates:
        raise ValueError(f"La tarjeta no ofrece un perfil para {'activar' if enabled else 'desactivar'} "
                         f"{'la salida' if direction == 'output' else 'la entrada'} "
                         "sin cambiar la otra dirección")
    conventional = [profile for profile in candidates if profile.get("name") != "pro-audio"]
    if conventional:
        candidates = conventional
    old_parts = set(str(active["name"]).split("+"))
    return max(candidates, key=lambda profile: (
        len(old_parts.intersection(str(profile["name"]).split("+"))),
        int(profile.get("priority") or 0), profile["name"]))["name"]


def card_capabilities(card):
    """Expose current direction states and whether each switch can be flipped."""
    active = _active(card)
    output = _enabled(active, "output") if active else False
    input_ = _enabled(active, "input") if active else False

    def can_flip(direction, current):
        try:
            choose_profile(card, direction, not current)
            return True
        except ValueError:
            return False

    return {"outputEnabled": output, "inputEnabled": input_,
            "canToggleOutput": can_flip("output", output),
            "canToggleInput": can_flip("input", input_)}
