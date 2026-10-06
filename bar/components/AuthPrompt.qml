import QtQuick
import "../components"

// Composition accepts the real authorization service or a mock backend.
AuthPromptView {
    id: root
    required property var backend
    authState: ({
        flow: backend.flow,
        active: backend.active,
        sudoActive: backend.sudoActive,
        sudoCanRespond: backend.sudoCanRespond,
        sudoSubmitting: backend.sudoSubmitting,
        sudoSuccess: backend.sudoSuccess,
        sudoError: backend.sudoError,
        sudoPrompt: backend.sudoPrompt,
        polkitSubmitting: backend.polkitSubmitting,
        polkitSuccess: backend.polkitSuccess,
        polkitError: backend.polkitError,
        polkitMessage: backend.polkitMessage
    })
    onResponseRequested: (secret, sudo, reply) => reply(sudo ? backend.submitSudo(secret) : backend.submit(secret))
    onCancelRequested: sudo => { if (sudo) backend.cancelSudo(); else backend.cancel() }
    onRetryRequested: backend.beginSudoRetry()
    onIdentityRequested: index => {
        if (root.flow && index >= 0 && index < root.identities.length)
            root.flow.selectedIdentity = root.identities[index]
    }
    Connections {
        target: root.backend
        function onAuthenticationRequestStarted() { root.resetInput(); Qt.callLater(root.focusInput) }
        function onSudoRequestStarted() { root.resetInput(); if (root.hasError) root.reject(); else Qt.callLater(root.focusInput) }
    }
    Connections {
        target: root.flow
        function onAuthenticationFailed() { root.editing = false; if (!root.hasError) root.reject() }
        function onSelectedIdentityChanged() { root.resetInput(); Qt.callLater(root.focusInput) }
        function onIsResponseRequiredChanged() { root.responseRequirementChanged() }
    }
}
