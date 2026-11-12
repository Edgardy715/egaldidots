import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../Singletons"
import "../components"
import "../Singletons/UpdateText.js" as UpdateText

ColumnLayout {
    id: root
    required property var controller
    property var config: Config
    spacing: 16
    readonly property bool motionAllowed: visible && (!Window.window || Window.window.visible) && !Flags.reduceMotion
    readonly property bool checking: controller.busy && controller.operation === "check"
    readonly property bool installing: controller.busy && controller.operation === "install"
    readonly property real fraction: installing ? UpdateText.fraction(controller.progress) : -1
    readonly property bool incomplete: !!controller.error || ["system", "aur", "flatpak", "shell"].some(key => {
        const status = controller.result[key] || {}
        return status.supported !== false && !!status.error
    })
    readonly property string headline: installing ? UpdateText.phase(controller.progress)
        : checking ? I18n.tr("Consultando actualizaciones…")
        : incomplete ? I18n.tr("La consulta necesita atención")
        : controller.count === 1 ? I18n.tr("1 actualización disponible")
        : controller.count > 0 ? I18n.tr("%1 actualizaciones disponibles").arg(controller.count)
        : controller.result.checkedAt ? I18n.tr("Tu equipo está al día") : I18n.tr("Comprueba si hay novedades")
    readonly property int count: controller.count
    property real nowMs: Date.now()
    Timer { interval: 30000; repeat: true; running: root.visible; onTriggered: root.nowMs = Date.now() }
    function relativeTime(iso) {
        const minutes = Math.max(0, Math.floor((nowMs - new Date(iso).getTime()) / 60000))
        if (minutes < 1) return I18n.tr("ahora mismo")
        if (minutes < 60) return I18n.tr("hace %1 min").arg(minutes)
        const hours = Math.floor(minutes / 60)
        if (hours < 24) return I18n.tr("hace %1 h").arg(hours)
        return I18n.tr("hace %1 d").arg(Math.floor(hours / 24))
    }
    readonly property string searchTerms: I18n.tr("actualizaciones actualizar sistema CachyOS Arch Linux paquetes AUR Flatpak aplicaciones shell Azog software")

    ScrollView {
        id: scroll
        objectName: "updatesScroll"
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ColumnLayout {
            width: scroll.availableWidth
            spacing: 14
            RowLayout {
                Layout.fillWidth: true; Layout.bottomMargin: 6; spacing: 16
                // Same signal as login/password confirmation: arc while checking, drawn result after.
                Item {
                    Layout.preferredWidth: 52; Layout.preferredHeight: 52; Layout.alignment: Qt.AlignTop
                    readonly property bool exposed: root.visible && (!root.Window.window || root.Window.window.visible)
                    readonly property bool resolved: !!root.controller.result.checkedAt && root.count === 0
                    ConfirmationIndicator {
                        id: activityIndicator
                        objectName: "updatesActivity"
                        anchors.fill: parent
                        progress: Math.max(0, root.fraction)
                        status: !parent.exposed ? "" : root.installing ? (root.fraction >= 0 ? "progress" : "busy")
                            : root.checking ? "busy" : root.incomplete ? "error"
                            : parent.resolved && !root.controller.busy ? "success" : ""
                    }
                    // Pending: a quiet ring carrying the count, in the indicator's stroke language.
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.86; height: width; radius: width / 2
                        color: "transparent"
                        border.width: Math.max(1.5, parent.width * 0.045)
                        border.color: root.count > 0 ? Theme.accent : Qt.alpha(Theme.foreground, Theme.alphaHairline)
                        opacity: activityIndicator.status === "" ? 1 : 0
                        scale: opacity > 0.5 ? 1 : 0.92
                        Behavior on opacity { enabled: root.motionAllowed; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                        Behavior on scale { enabled: root.motionAllowed; NumberAnimation { duration: Motion.emphasized; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedDecelCurve } }
                        Text {
                            id: countBadge
                            anchors.centerIn: parent
                            // Keep the last positive count while the badge fades out.
                            property int shownCount: 0
                            readonly property bool present: root.count > 0
                            Binding on shownCount { when: root.count > 0; value: root.count }
                            opacity: present ? 1 : 0
                            visible: opacity > 0.01
                            scale: Flags.reduceMotion ? 1 : (present ? 1 : 0.6)
                            Behavior on opacity { enabled: root.motionAllowed; NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                            Behavior on scale { enabled: root.motionAllowed && !Flags.reduceMotion; NumberAnimation { duration: Motion.standardSmall; easing.type: countBadge.present ? Easing.OutBack : Motion.easeStandard } }
                            text: shownCount > 99 ? "99+" : shownCount
                            color: Theme.accent; font.family: Config.appearance.fontDisplayFamily
                            font.pixelSize: Theme.fontSizeHead; font.weight: Font.DemiBold; font.features: { "tnum": 1 }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    AnimatedLabel {
                        objectName: "updatesHeadline"
                        Layout.fillWidth: true; value: root.headline
                        textFormat: Text.PlainText
                        font.family: Config.appearance.fontDisplayFamily; font.pixelSize: Theme.fontSizeHead + 8 * Flags.fontScale
                        font.weight: Font.DemiBold; color: Theme.foreground; wrapMode: Text.WordWrap
                    }
                    AnimatedLabel {
                        Layout.fillWidth: true; textFormat: Text.PlainText
                        value: root.installing ? (UpdateText.committed(root.controller.progress)
                                ? I18n.tr("Aplicando cambios. No apagues el equipo hasta que termine.")
                                : I18n.tr("Se instala en segundo plano. Puedes seguir usando el equipo."))
                            : root.checking ? I18n.tr("Puedes seguir usando la shell mientras tanto.")
                            : root.controller.result.checkedAt ? I18n.tr("Última consulta %1").arg(root.relativeTime(root.controller.result.checkedAt))
                            : I18n.tr("Consulta primero para conocer las versiones disponibles.")
                        font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBodyLg
                        color: Theme.iconSecondary; wrapMode: Text.WordWrap
                    }
                }
                EdotsButton {
                    objectName: "updatesRefresh"
                    Layout.alignment: Qt.AlignTop
                    text: root.checking ? I18n.tr("Comprobando…") : I18n.tr("Comprobar"); symbol: "refresh"
                    accent: !root.controller.busy && root.count === 0
                    enabled: !root.controller.busy
                    onClicked: root.controller.refresh()
                }
            }
            // Reserved slot: feedback grows in instead of shoving the cards.
            Item {
                id: feedbackSlot
                Layout.fillWidth: true
                readonly property string incoming: root.controller.error || root.controller.feedback
                property string latched: ""
                onIncomingChanged: if (incoming.length > 0) latched = incoming
                Component.onCompleted: latched = incoming
                property real fraction: incoming.length > 0 ? 1 : 0
                Behavior on fraction { enabled: root.motionAllowed; NumberAnimation { duration: Motion.emphasized; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedDecelCurve } }
                implicitHeight: banner.implicitHeight * fraction
                clip: true
                Rectangle {
                    id: banner
                    width: parent.width; implicitHeight: feedbackText.implicitHeight + 24
                    radius: 12; opacity: feedbackSlot.fraction
                    color: Qt.alpha(root.controller.error ? Theme.error : Theme.accent, Theme.alphaChip)
                    Text {
                        id: feedbackText
                        objectName: "updatesFeedback"
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 14 }
                        text: feedbackSlot.latched
                        textFormat: Text.PlainText; color: Theme.foreground; wrapMode: Text.Wrap
                        font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                    }
                }
            }
            Repeater {
                model: [
                    {key: "system", title: I18n.tr("Sistema · CachyOS"), hint: I18n.tr("Sistema operativo y aplicaciones de los repositorios oficiales.")},
                    {key: "aur", title: I18n.tr("Aplicaciones · AUR"), hint: I18n.tr("Paquetes de la comunidad, compilados en tu equipo con paru.")},
                    {key: "flatpak", title: I18n.tr("Aplicaciones · Flatpak"), hint: I18n.tr("Aplicaciones y entornos de ejecución instalados con Flatpak.")},
                    {key: "shell", title: I18n.tr("Azog · Shell"), hint: I18n.tr("Novedades de la rama remota configurada en Git.")}
                ]
                UpdateSourceCard {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    sourceKey: modelData.key; title: modelData.title; hint: modelData.hint; 
                    status: root.controller.result[modelData.key] || ({})
                    checked: !!root.controller.result.checkedAt
                    checking: root.checking
                    busy: root.controller.busy
                    motionAllowed: root.motionAllowed
                    order: index
                    installing: root.installing && root.controller.installSource === modelData.key
                    cancelling: installing && root.controller.cancelling
                    progress: installing ? root.controller.progress : ({})
                    outcome: (root.controller.outcomes || {})[modelData.key] || null
                    installable: root.controller.installable(modelData.key)
                    onInstallRequested: root.controller.install(modelData.key)
                    onCancelRequested: root.controller.cancel()
                }
            }
            Text {
                Layout.fillWidth: true; Layout.topMargin: 10
                text: I18n.tr("Azog te avisa; tú eliges cuándo instalar. La instalación se hace en segundo plano y puedes cancelarla hasta que empiezan a aplicarse los cambios.")
                    + (root.controller.result.snapshots ? " " + I18n.tr("Antes de cada cambio del sistema se guarda un punto de restauración, disponible en el menú de inicio.") : "")
                font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                color: Theme.iconSecondary; wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true; Layout.topMargin: 6
                text: I18n.tr("Comprobación automática")
                color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBodyLg; font.weight: Font.DemiBold
            }
            Repeater {
                model: ["enabled", "notifications"]
                SettingRow {
                    required property string modelData
                    objectName: "updatesSetting-" + modelData
                    Layout.fillWidth: true
                    fieldKey: modelData; field: root.config.schema.sections.updates[modelData]
                    value: root.config.updates[modelData]
                    editorEnabled: root.config.loaded && !root.config.saving
                    reducedMotion: Config.appearance.reduceMotion
                    onChangeRequested: value => root.config.update({updates: {[modelData]: value}})
                }
            }
            Text {
                Layout.fillWidth: true
                text: I18n.tr("Se comprueba al iniciar y cada seis horas. Los avisos respetan No molestar. Las aplicaciones descargadas manualmente y las extensiones con actualizador propio se gestionan desde cada aplicación.")
                color: Theme.iconSecondary; font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.fontSizeBody; wrapMode: Text.WordWrap
            }
        }
    }
}
