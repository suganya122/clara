import Foundation

/// Parses a .env file's text. Pure, so it is unit tested.
public enum EnvParser {
    public static let keyName = "ANTHROPIC_API_KEY"

    /// Returns the API key, or nil when the line is missing or empty.
    /// Accepts `NAME=value`, `export NAME=value`, optional quotes, and `#` comments.
    public static func apiKey(from text: String) -> String? {
        for rawLine in text.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("export ") { line = String(line.dropFirst(7)) }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let name = line[..<eq].trimmingCharacters(in: .whitespaces)
            guard name == keyName else { continue }
            var value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if value.count >= 2, let first = value.first, first == value.last, first == "\"" || first == "'" {
                value = String(value.dropFirst().dropLast())
            }
            return value.isEmpty ? nil : value
        }
        return nil
    }

    public static let template = """
    # Paste your Anthropic API key after the = sign, save the file, then press Option+Space.
    # This file is read each time you ask, so no restart is needed. Keep it private.
    \(keyName)=

    """
}
