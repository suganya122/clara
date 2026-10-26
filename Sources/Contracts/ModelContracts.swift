import Foundation

/// Cheap / Balanced / Max. Concrete model names come from config, never from code.
public enum ModelTier: String, Codable, CaseIterable, Sendable {
    case cheap, balanced, max
}

public struct TokenUsage: Equatable, Codable, Sendable {
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheReadTokens: Int
    public var cacheWriteTokens: Int

    public init(inputTokens: Int = 0, outputTokens: Int = 0, cacheReadTokens: Int = 0, cacheWriteTokens: Int = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
    }
}

public enum ContentBlock: Equatable, Sendable {
    case text(String)
    case toolUse(id: String, name: String, input: JSONValue)
    case toolResult(toolUseID: String, content: String, isError: Bool)
}

public struct ChatMessage: Equatable, Sendable {
    public enum Role: String, Sendable { case user, assistant }
    public var role: Role
    public var content: [ContentBlock]

    public init(role: Role, content: [ContentBlock]) {
        self.role = role
        self.content = content
    }

    public static func user(_ text: String) -> ChatMessage { .init(role: .user, content: [.text(text)]) }
    public static func assistant(_ text: String) -> ChatMessage { .init(role: .assistant, content: [.text(text)]) }
}

public struct ToolDefinition: Equatable, Sendable {
    public var name: String
    public var description: String
    public var inputSchema: JSONValue

    public init(name: String, description: String, inputSchema: JSONValue) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

public enum ModelEvent: Equatable, Sendable {
    case textDelta(String)
    case toolUseStart(id: String, name: String)
    case toolInputDelta(String)
    case toolUseEnd
    case usage(TokenUsage)
    case done(stopReason: String?)
}

public enum ModelError: Error, Equatable {
    case missingAPIKey
    case badResponse
    case http(status: Int, body: String)
    case api(type: String, message: String)
    case malformedStream(String)
}

/// One interface for any reasoning model. Claude is the default implementation.
public protocol ModelProvider: Sendable {
    func stream(system: String, messages: [ChatMessage], tools: [ToolDefinition], tier: ModelTier)
        -> AsyncThrowingStream<ModelEvent, Error>
}
