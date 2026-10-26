import Contracts
import Foundation

public struct ClaudeProvider: ModelProvider {
    private let config: ClaudeConfig
    private let apiKey: @Sendable () throws -> String
    private let session: URLSession

    public init(config: ClaudeConfig = ClaudeConfig(),
                session: URLSession = .shared,
                apiKey: @escaping @Sendable () throws -> String) {
        self.config = config
        self.session = session
        self.apiKey = apiKey
    }

    /// Public so tests can check the exact request without a network call.
    public func makeRequest(system: String, messages: [ChatMessage], tools: [ToolDefinition], tier: ModelTier) throws -> URLRequest {
        let key = try apiKey()
        guard !key.isEmpty else { throw ModelError.missingAPIKey }
        guard let model = config.tierModels[tier] else { throw ModelError.malformedStream("no model for tier \(tier)") }

        let cache: JSONValue = .object(["type": .string("ephemeral")])

        var body: [String: JSONValue] = [
            "model": .string(model),
            "max_tokens": .number(Double(config.maxTokens)),
            "stream": .bool(true),
            // Stable system prompt is cached.
            "system": .array([.object(["type": .string("text"), "text": .string(system), "cache_control": cache])]),
            "messages": .array(messages.map(Self.encode)),
        ]

        if !tools.isEmpty {
            var encoded = tools.map { tool -> JSONValue in
                .object(["name": .string(tool.name),
                         "description": .string(tool.description),
                         "input_schema": tool.inputSchema])
            }
            // Cache breakpoint on the last tool covers the whole tool list.
            if case .object(var last) = encoded[encoded.count - 1] {
                last["cache_control"] = cache
                encoded[encoded.count - 1] = .object(last)
            }
            body["tools"] = .array(encoded)
        }

        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(config.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(JSONValue.object(body))
        return request
    }

    public func stream(system: String, messages: [ChatMessage], tools: [ToolDefinition], tier: ModelTier)
        -> AsyncThrowingStream<ModelEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest(system: system, messages: messages, tools: tools, tier: tier)
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else { throw ModelError.badResponse }

                    if http.statusCode != 200 {
                        var text = ""
                        for try await line in bytes.lines { text += line }
                        // The key is never echoed: the body is the server's error text only.
                        throw ModelError.http(status: http.statusCode, body: text)
                    }

                    var decoder = ClaudeStreamDecoder()
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        for event in try decoder.decode(dataLine: payload) {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func encode(_ message: ChatMessage) -> JSONValue {
        let blocks: [JSONValue] = message.content.map { block in
            switch block {
            case .text(let t):
                return .object(["type": .string("text"), "text": .string(t)])
            case .toolUse(let id, let name, let input):
                return .object(["type": .string("tool_use"), "id": .string(id), "name": .string(name), "input": input])
            case .toolResult(let id, let content, let isError):
                return .object(["type": .string("tool_result"), "tool_use_id": .string(id),
                                "content": .string(content), "is_error": .bool(isError)])
            }
        }
        return .object(["role": .string(message.role.rawValue), "content": .array(blocks)])
    }
}
