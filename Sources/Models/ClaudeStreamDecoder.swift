import Contracts
import Foundation

/// Turns the `data:` payloads of Claude's streaming API into `ModelEvent`s.
/// Every payload carries its own "type", so `event:` lines are not needed.
public struct ClaudeStreamDecoder {
    private var toolBlocks = Set<Int>()
    private var usage = TokenUsage()
    private var stopReason: String?

    public init() {}

    public mutating func decode(dataLine: String) throws -> [ModelEvent] {
        guard !dataLine.isEmpty, dataLine != "[DONE]" else { return [] }
        guard let data = dataLine.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String
        else { throw ModelError.malformedStream(dataLine) }

        switch type {
        case "message_start":
            if let u = (json["message"] as? [String: Any])?["usage"] as? [String: Any] {
                usage.inputTokens = u["input_tokens"] as? Int ?? 0
                usage.cacheReadTokens = u["cache_read_input_tokens"] as? Int ?? 0
                usage.cacheWriteTokens = u["cache_creation_input_tokens"] as? Int ?? 0
            }
            return []

        case "content_block_start":
            guard let index = json["index"] as? Int,
                  let block = json["content_block"] as? [String: Any],
                  block["type"] as? String == "tool_use"
            else { return [] }
            toolBlocks.insert(index)
            return [.toolUseStart(id: block["id"] as? String ?? "", name: block["name"] as? String ?? "")]

        case "content_block_delta":
            guard let delta = json["delta"] as? [String: Any],
                  let deltaType = delta["type"] as? String
            else { return [] }
            switch deltaType {
            case "text_delta":
                return [.textDelta(delta["text"] as? String ?? "")]
            case "input_json_delta":
                return [.toolInputDelta(delta["partial_json"] as? String ?? "")]
            default:
                return []
            }

        case "content_block_stop":
            if let index = json["index"] as? Int, toolBlocks.remove(index) != nil {
                return [.toolUseEnd]
            }
            return []

        case "message_delta":
            if let delta = json["delta"] as? [String: Any] {
                stopReason = delta["stop_reason"] as? String ?? stopReason
            }
            if let u = json["usage"] as? [String: Any], let out = u["output_tokens"] as? Int {
                usage.outputTokens = out
            }
            return [.usage(usage)]

        case "message_stop":
            return [.done(stopReason: stopReason)]

        case "error":
            let err = json["error"] as? [String: Any]
            throw ModelError.api(type: err?["type"] as? String ?? "unknown",
                                 message: err?["message"] as? String ?? "")

        default: // ping and anything new
            return []
        }
    }
}
