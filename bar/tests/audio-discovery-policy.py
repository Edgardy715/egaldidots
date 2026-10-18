#!/usr/bin/env python3
"""Application discovery and card direction policy regressions."""

import importlib.util
from pathlib import Path
import sys
import unittest


SERVICES = Path(__file__).resolve().parents[1] / "services"


def load(name):
    spec = importlib.util.spec_from_file_location(name, SERVICES / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


discovery = load("audio_discovery")
policy = load("audio_policy")


def card(active="output:analog-stereo+input:mono-fallback"):
    return {"active_profile": active, "profiles": {
        "off": {"sinks": 0, "sources": 0, "priority": 0, "available": True},
        "output:analog-stereo+input:mono-fallback": {
            "sinks": 1, "sources": 1, "priority": 6501, "available": True},
        "output:analog-stereo": {"sinks": 1, "sources": 0, "priority": 6500, "available": True},
        "output:iec958-stereo+input:mono-fallback": {
            "sinks": 1, "sources": 1, "priority": 5501, "available": True},
        "output:iec958-stereo": {"sinks": 1, "sources": 0, "priority": 5500, "available": True},
        "input:mono-fallback": {"sinks": 0, "sources": 1, "priority": 1, "available": True},
        "pro-audio": {"sinks": 1, "sources": 1, "priority": 1, "available": True},
    }}


class DiscoveryPolicyTest(unittest.TestCase):
    def test_client_zero_is_valid(self):
        identity = discovery.stream_identity({"client":0,"properties":{"media.name":"audio-src"}},
                                              [{"index":0,"properties":{"application.name":"spotify"}}])
        self.assertEqual(identity["appName"], "Spotify")

    def test_spotify_native_client_and_discord_engine(self):
        clients = [
            {"index": 116, "properties": {"object.id": "108", "application.name": "spotify",
                                          "application.process.binary": "spotify"}},
            {"index": 88, "properties": {"object.id": "88", "application.name": "WEBRTC VoiceEngine",
                                         "application.process.binary": "Discord"}},
        ]
        spotify = {"index": 117, "client": 116, "properties": {
            "client.id": "108", "media.name": "audio-src", "node.name": "audio-src"}}
        discord = {"index": 2630, "client": 88, "properties": {
            "application.name": "WEBRTC VoiceEngine", "application.process.binary": "Discord",
            "media.name": "playStream"}}
        self.assertEqual(discovery.stream_identity(spotify, clients),
                         {"appName": "Spotify", "mediaName": "", "icon": "spotify"})
        self.assertEqual(discovery.stream_identity(discord, clients),
                         {"appName": "Discord", "mediaName": "", "icon": "discord"})
        enriched = discovery.enrich_streams({"clients": clients, "sink-inputs": [spotify],
                                             "source-outputs": [discord]})
        self.assertEqual(enriched["sink-inputs"][0]["identity"]["appName"], "Spotify")
        self.assertEqual(enriched["source-outputs"][0]["identity"]["appName"], "Discord")

    def test_stream_identity_preserves_specific_name_and_icon(self):
        row = {"index": 3, "properties": {"application.name": "Firefox", "application.icon_name": "firefox",
                                           "application.process.binary": "firefox", "media.name": "Video"}}
        self.assertEqual(discovery.stream_identity(row, []),
                         {"appName": "Firefox", "mediaName": "Video", "icon": "firefox"})

    def test_client_index_wins_over_another_clients_object_id(self):
        clients = [
            {"index": 9, "properties": {"object.id": "116", "application.name": "Other"}},
            {"index": 116, "properties": {"object.id": "108", "application.name": "spotify"}},
        ]
        stream = {"index": 117, "client": 116, "properties": {"media.name": "audio-src"}}
        self.assertEqual(discovery.stream_identity(stream, clients)["appName"], "Spotify")

    def test_duplex_direction_independence_and_restore(self):
        device = card()
        self.assertEqual(policy.card_capabilities(device), {
            "outputEnabled": True, "inputEnabled": True,
            "canToggleOutput": True, "canToggleInput": True})
        self.assertEqual(policy.choose_profile(device, "output", False), "input:mono-fallback")
        self.assertEqual(policy.choose_profile(device, "input", False), "output:analog-stereo")
        self.assertEqual(policy.choose_profile(card("input:mono-fallback"), "output", True),
                         "output:analog-stereo+input:mono-fallback")
        self.assertEqual(policy.choose_profile(card("output:analog-stereo"), "input", True),
                         "output:analog-stereo+input:mono-fallback")
        self.assertEqual(policy.choose_profile(card("off"), "output", True), "output:analog-stereo")
        self.assertEqual(policy.choose_profile(card("off"), "input", True), "input:mono-fallback")
        self.assertEqual(policy.choose_profile(card("input:mono-fallback"), "input", False), "off")
        self.assertEqual(policy.choose_profile(card("output:analog-stereo"), "output", False), "off")

    def test_missing_direction_profile_never_disables_other_side(self):
        output_only = card("output:analog-stereo")
        output_only["profiles"].pop("output:analog-stereo+input:mono-fallback")
        output_only["profiles"].pop("output:iec958-stereo+input:mono-fallback")
        output_only["profiles"].pop("pro-audio")
        self.assertFalse(policy.card_capabilities(output_only)["canToggleInput"])
        with self.assertRaisesRegex(ValueError, "sin cambiar la otra dirección"):
            policy.choose_profile(output_only, "input", True)
        input_only = card("input:mono-fallback")
        input_only["profiles"]["output:analog-stereo+input:mono-fallback"]["available"] = False
        input_only["profiles"]["output:iec958-stereo+input:mono-fallback"]["available"] = False
        input_only["profiles"]["pro-audio"]["available"] = "no"
        self.assertFalse(policy.card_capabilities(input_only)["canToggleOutput"])
        with self.assertRaises(ValueError):
            policy.choose_profile(input_only, "output", True)

    def test_unavailable_active_profile_and_invalid_requests(self):
        with self.assertRaisesRegex(ValueError, "perfil activo"):
            policy.choose_profile(card("missing"), "output", False)
        disconnected = card("output:analog-stereo")
        disconnected["profiles"]["output:analog-stereo"]["available"] = False
        self.assertEqual(policy.choose_profile(disconnected, "output", False), "off")
        with self.assertRaises(ValueError):
            policy.choose_profile(card(), "capture", True)
        with self.assertRaises(ValueError):
            policy.choose_profile(card(), "output", 1)


if __name__ == "__main__":
    unittest.main()
