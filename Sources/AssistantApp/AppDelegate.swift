import AppKit
import Core

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let hotkey = HotkeyManager()
    private let model = AskViewModel()
    private var panel: OverlayPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()

        // Pressing the hotkey again while the panel is open acts as stop.
        hotkey.onPress = { [weak self] in
            Task { @MainActor in self?.togglePanel() }
        }
        if !hotkey.register() {
            statusItem?.button?.toolTip = "Option+Space is taken by another app"
        }

        if KeychainStore.readKey() == nil {
            promptForAPIKey()
        }
    }

    // MARK: Menu bar

    private func setupMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: AppConfig.appName)
        statusItem = item

        let menu = NSMenu()
        menu.addItem(withTitle: "Ask \(AppConfig.appName)  (⌥Space)", action: #selector(showPanel), keyEquivalent: "")
        menu.addItem(withTitle: "Set API Key…", action: #selector(setAPIKey), keyEquivalent: "")
        menu.addItem(withTitle: "Remove API Key", action: #selector(removeAPIKey), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Stop Everything", action: #selector(stopEverything), keyEquivalent: "")
        menu.addItem(withTitle: "Quit \(AppConfig.appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for entry in menu.items where entry.action != #selector(NSApplication.terminate(_:)) { entry.target = self }
        item.menu = menu
    }

    @objc private func showPanel() { ensurePanel().present() }

    @objc private func setAPIKey() { promptForAPIKey() }

    @objc private func removeAPIKey() { KeychainStore.deleteKey() }

    /// Visible kill switch. Voice and automations will hook in here too.
    @objc private func stopEverything() { model.cancel() }

    private func togglePanel() {
        let panel = ensurePanel()
        if panel.isVisible {
            model.cancel()
            panel.orderOut(nil)
        } else {
            panel.present()
        }
    }

    private func ensurePanel() -> OverlayPanel {
        if let panel { return panel }
        let created = OverlayPanel(model: model) { [weak self] in
            self?.model.cancel()
            self?.panel?.orderOut(nil)
        }
        panel = created
        return created
    }

    // MARK: API key

    private func promptForAPIKey() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Anthropic API key"
        alert.informativeText = "Stored in your macOS Keychain only. It is never written to disk or logs."
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty { KeychainStore.saveKey(key) }
    }
}
