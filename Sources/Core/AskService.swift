import Contracts
import Foundation

public struct AskOutcome: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case answered, stopped }
    public var kind: Kind
    public var text: String
    public var usage: TokenUsage
    public var stopReason: String?
}

/// Milestone 1 pipeline: stop check, then one streaming model call.
/// Cancel by cancelling the Task that runs `ask`.
public struct AskService: Sendable {
    private let model: ModelProvider
    private let stopPhrase: StopPhrase
    private let systemPrompt: String

    public init(model: ModelProvider,
                stopPhrase: StopPhrase = StopPhrase(),
                systemPrompt: String = Persona.systemPrompt()) {
        self.model = model
        self.stopPhrase = stopPhrase
        self.systemPrompt = systemPrompt
    }

    public func ask(_ text: String,
                    tier: ModelTier = .cheap,
                    onText: @Sendable (String) -> Void = { _ in }) async throws -> AskOutcome {
        if stopPhrase.matches(text) {
            return AskOutcome(kind: .stopped, text: "", usage: TokenUsage(), stopReason: nil)
        }

        var reply = ""
        var usage = TokenUsage()
        var stopReason: String?

        let events = model.stream(system: systemPrompt, messages: [.user(text)], tools: [], tier: tier)
        for try await event in events {
            try Task.checkCancellation()
            switch event {
            case .textDelta(let delta):
                reply += delta
                onText(delta)
            case .usage(let u):
                usage = u
            case .done(let reason):
                stopReason = reason
            case .toolUseStart, .toolInputDelta, .toolUseEnd:
                break // no tools in Milestone 1
            }
        }
        return AskOutcome(kind: .answered, text: reply, usage: usage, stopReason: stopReason)
    }
}
