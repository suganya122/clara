import Foundation

/// Detects the stop phrase. Runs before any model call.
public struct StopPhrase: Sendable {
    public let wakeWord: String

    public init(wakeWord: String = AppConfig.wakeWord) {
        self.wakeWord = wakeWord
    }

    public func matches(_ transcript: String) -> Bool {
        let words = normalize(transcript)
        let wake = normalize(wakeWord)
        return words == ["stop"] || words == wake + ["stop"] || words == ["stop"] + wake
    }

    private func normalize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}
