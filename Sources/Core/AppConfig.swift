import Foundation

/// The single place the assistant's name lives. Change it here only.
public enum AppConfig {
    public static let appName = "Clara"
    public static let wakeWord = "Clara"

    /// Neutral identifiers, so renaming the assistant never touches storage.
    public static let keychainService = "app.assistant.anthropic"
    public static let keychainAccount = "api-key"
}
