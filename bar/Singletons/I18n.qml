pragma Singleton
import QtQuick
import Quickshell
import "../i18n/en.js" as En
import "UpdateText.js" as UpdateText

// Runtime language switch. Source strings are Spanish; English lives in i18n/en.js.
// Pure QML/JS on purpose: no .qm compile step and no C++ plugin, so a language
// change applies live (the `language` read below makes every binding re-evaluate).
Singleton {
    readonly property string setting: (Config.regional?.language ?? "system")
    // "system" follows LANG; anything that is not English falls back to Spanish,
    // the language the shell is written in.
    readonly property string language: setting === "system"
        ? (Qt.locale().name.slice(0, 2) === "en" ? "en" : "es") : setting

    Component.onCompleted: UpdateText.setTranslator(source => tr(source))

    function tr(source) {
        if (language !== "en") return source
        const hit = En.strings[source]
        return hit === undefined ? source : hit
    }
}
