import Contracts
import XCTest
@testable import Models

final class ClaudeStreamDecoderTests: XCTestCase {
    private func run(_ lines: [String]) throws -> [ModelEvent] {
        var decoder = ClaudeStreamDecoder()
        return try lines.flatMap { try decoder.decode(dataLine: $0) }
    }

    func testTextStream() throws {
        let events = try run([
            #"{"type":"message_start","message":{"usage":{"input_tokens":25,"cache_read_input_tokens":5,"cache_creation_input_tokens":2,"output_tokens":1}}}"#,
            #"{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#,
            #"{"type":"ping"}"#,
            #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}"#,
            #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" there"}}"#,
            #"{"type":"content_block_stop","index":0}"#,
            #"{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":7}}"#,
            #"{"type":"message_stop"}"#,
        ])
        XCTAssertEqual(events, [
            .textDelta("Hello"), .textDelta(" there"),
            .usage(TokenUsage(inputTokens: 25, outputTokens: 7, cacheReadTokens: 5, cacheWriteTokens: 2)),
            .done(stopReason: "end_turn"),
        ])
    }

    func testToolUseStream() throws {
        let events = try run([
            #"{"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"t1","name":"open_app","input":{}}}"#,
            #"{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"app\":"}}"#,
            #"{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"\"Uber\"}"}}"#,
            #"{"type":"content_block_stop","index":1}"#,
        ])
        XCTAssertEqual(events, [
            .toolUseStart(id: "t1", name: "open_app"),
            .toolInputDelta("{\"app\":"), .toolInputDelta("\"Uber\"}"),
            .toolUseEnd,
        ])
    }

    func testErrorEventThrows() {
        XCTAssertThrowsError(try run([#"{"type":"error","error":{"type":"overloaded_error","message":"busy"}}"#])) {
            XCTAssertEqual($0 as? ModelError, .api(type: "overloaded_error", message: "busy"))
        }
    }

    func testMalformedLineThrows() {
        XCTAssertThrowsError(try run(["not json"]))
    }
}

final class ClaudeRequestTests: XCTestCase {
    private func body(_ request: URLRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
    }

    func testRequestShape() throws {
        let provider = ClaudeProvider(apiKey: { "sk-test" })
        let request = try provider.makeRequest(system: "be brief", messages: [.user("hi")], tools: [], tier: .cheap)

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")

        let json = try body(request)
        XCTAssertEqual(json["model"] as? String, ClaudeConfig.defaultTierModels[.cheap])
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertNil(json["tools"])

        let system = try XCTUnwrap(json["system"] as? [[String: Any]])
        XCTAssertEqual(system.first?["text"] as? String, "be brief")
        XCTAssertNotNil(system.first?["cache_control"], "system prompt must be cached")
    }

    func testToolsGetCacheBreakpointOnLastOnly() throws {
        let provider = ClaudeProvider(apiKey: { "sk-test" })
        let schema: JSONValue = .object(["type": .string("object")])
        let tools = [ToolDefinition(name: "a", description: "A", inputSchema: schema),
                     ToolDefinition(name: "b", description: "B", inputSchema: schema)]
        let request = try provider.makeRequest(system: "s", messages: [.user("hi")], tools: tools, tier: .balanced)
        let encoded = try XCTUnwrap(try body(request)["tools"] as? [[String: Any]])
        XCTAssertNil(encoded[0]["cache_control"])
        XCTAssertNotNil(encoded[1]["cache_control"])
    }

    func testMissingKeyThrows() {
        let provider = ClaudeProvider(apiKey: { "" })
        XCTAssertThrowsError(try provider.makeRequest(system: "s", messages: [], tools: [], tier: .cheap)) {
            XCTAssertEqual($0 as? ModelError, .missingAPIKey)
        }
    }

    func testNoVersionStringsInTierDefaults() {
        for name in ClaudeConfig.defaultTierModels.values {
            XCTAssertNil(name.range(of: #"\d{8}"#, options: .regularExpression), "\(name) looks pinned to a date")
        }
    }
}
