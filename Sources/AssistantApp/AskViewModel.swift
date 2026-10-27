import Contracts
import Core
import Foundation
import Models

/// Drives the temporary text overlay. Voice replaces the text field in Milestone 7.
@MainActor
final class AskViewModel: ObservableObject {
    enum Status: Equatable {
        case idle, thinking, error(String)
        var label: String {
            switch self {
            case .idle: return "Ready"
            case .thinking: return "Thinking"
            case .error: return "Error"
            }
        }
    }

    @Published var input = ""
    @Published var reply = ""
    @Published var status: Status = .idle
    @Published var tokenSummary = ""

    private var task: Task<Void, Never>?

    private let service = AskService(
        model: ClaudeProvider(apiKey: {
            guard let key = APIKeySource.current() else { throw ModelError.missingAPIKey }
            return key
        })
    )

    func submit() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        cancel()
        reply = ""
        tokenSummary = ""
        status = .thinking

        task = Task { [service] in
            do {
                let outcome = try await service.ask(text) { delta in
                    Task { @MainActor [weak self] in self?.reply += delta }
                }
                switch outcome.kind {
                case .stopped:
                    status = .idle
                    reply = "Stopped."
                case .answered:
                    status = .idle
                    let u = outcome.usage
                    tokenSummary = "\(u.inputTokens) in / \(u.outputTokens) out tokens"
                }
                input = ""
            } catch is CancellationError {
                status = .idle
            } catch ModelError.missingAPIKey {
                status = .error("No API key. Menu bar icon, then Open .env File, paste your key and save.")
            } catch ModelError.http(let code, let body) {
                status = .error("Claude API error \(code): \(body.prefix(200))")
            } catch {
                status = .error(error.localizedDescription)
            }
        }
    }

    /// Hotkey pressed again, or Escape: halt immediately.
    func cancel() {
        task?.cancel()
        task = nil
        if status == .thinking { status = .idle }
    }
}
