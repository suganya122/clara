import AppKit
import Core
import Foundation

/// Where the API key can come from: the .env file first, then the Keychain.
/// The .env file lives in Application Support (outside any repo), readable only by the user.
enum EnvFile {
    static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("assistant-app", isDirectory: true).appendingPathComponent(".env")
    }

    /// Creates the file with an empty key line if it does not exist yet.
    static func ensureExists() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path) else { return }
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                attributes: [.posixPermissions: 0o700])
        fm.createFile(atPath: url.path, contents: Data(EnvParser.template.utf8),
                      attributes: [.posixPermissions: 0o600])
    }

    static func readKey() -> String? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return EnvParser.apiKey(from: text)
    }

    /// Opens the file in TextEdit (.env files have no default app).
    static func openInEditor() {
        ensureExists()
        let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        NSWorkspace.shared.open([url], withApplicationAt: textEdit, configuration: NSWorkspace.OpenConfiguration())
    }
}

enum APIKeySource {
    static func current() -> String? {
        EnvFile.readKey() ?? KeychainStore.readKey()
    }
}
