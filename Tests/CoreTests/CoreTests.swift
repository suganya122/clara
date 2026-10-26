import Contracts
import XCTest
@testable import Core

/// Fake model that replays scripted events. Counts calls so tests can prove "no LLM call".
final class FakeModel: ModelProvider, @unchecked Sendable {
    var script: [ModelEvent]
    private(set) var calls = 0

    init(script: [ModelEvent] = []) { self.script = script }

    func stream(system: String, messages: [ChatMessage], tools: [ToolDefinition], tier: ModelTier)
        -> AsyncThrowingStream<ModelEvent, Error> {
        calls += 1
        let events = script
        return AsyncThrowingStream { c in
            for e in events { c.yield(e) }
            c.finish()
        }
    }
}

final class StopPhraseTests: XCTestCase {
    func testMatches() {
        let stop = StopPhrase(wakeWord: "Clara")
        XCTAssertTrue(stop.matches("Clara stop"))
        XCTAssertTrue(stop.matches("  clara,  STOP! "))
        XCTAssertTrue(stop.matches("stop"))
        XCTAssertTrue(stop.matches("stop Clara"))
    }

    func testDoesNotMatchLongerSentences() {
        let stop = StopPhrase(wakeWord: "Clara")
        XCTAssertFalse(stop.matches("don't stop the music"))
        XCTAssertFalse(stop.matches("clara stop playing jazz"))
        XCTAssertFalse(stop.matches(""))
    }
}

final class AskServiceTests: XCTestCase {
    func testStopPhraseSkipsModel() async throws {
        let model = FakeModel(script: [.textDelta("hi")])
        let outcome = try await AskService(model: model).ask("Clara stop")
        XCTAssertEqual(outcome.kind, .stopped)
        XCTAssertEqual(model.calls, 0)
    }

    func testCollectsTextUsageAndStopReason() async throws {
        let usage = TokenUsage(inputTokens: 10, outputTokens: 4)
        let model = FakeModel(script: [
            .textDelta("Done, "), .textDelta("Uber is open."),
            .usage(usage), .done(stopReason: "end_turn"),
        ])
        let outcome = try await AskService(model: model).ask("open uber")
        XCTAssertEqual(outcome.kind, .answered)
        XCTAssertEqual(outcome.text, "Done, Uber is open.")
        XCTAssertEqual(outcome.usage, usage)
        XCTAssertEqual(outcome.stopReason, "end_turn")
        XCTAssertEqual(model.calls, 1)
    }

    func testPropagatesModelErrors() async {
        struct Failing: ModelProvider {
            func stream(system: String, messages: [ChatMessage], tools: [ToolDefinition], tier: ModelTier)
                -> AsyncThrowingStream<ModelEvent, Error> {
                AsyncThrowingStream { $0.finish(throwing: ModelError.missingAPIKey) }
            }
        }
        do {
            _ = try await AskService(model: Failing()).ask("hello")
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? ModelError, .missingAPIKey)
        }
    }
}
