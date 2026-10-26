import AppKit

// main.swift top-level code is not main-actor isolated, but AppDelegate is.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
    app.run() // blocks until quit, so `delegate` stays alive
}
