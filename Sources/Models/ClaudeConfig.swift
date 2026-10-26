import Contracts
import Foundation

public struct ClaudeConfig: Sendable {
    public var endpoint: URL
    public var apiVersion: String
    public var maxTokens: Int
    /// Aliases only. No version strings.
    public var tierModels: [ModelTier: String]

    public init(endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!,
                apiVersion: String = "2023-06-01",
                maxTokens: Int = 1024,
                tierModels: [ModelTier: String] = ClaudeConfig.defaultTierModels) {
        self.endpoint = endpoint
        self.apiVersion = apiVersion
        self.maxTokens = maxTokens
        self.tierModels = tierModels
    }

    public static let defaultTierModels: [ModelTier: String] = [
        .cheap: "claude-haiku-5-5",
        .balanced: "claude-sonnet-5-5",
        .max: "claude-opus-5-5",
    ]
}
