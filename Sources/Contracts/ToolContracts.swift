import Foundation

public enum RiskLevel: String, Codable, Comparable, Sendable {
    case read, write, destructive, externalSend, purchase

    private var rank: Int {
        switch self {
        case .read: return 0
        case .write: return 1
        case .destructive: return 2
        case .externalSend: return 3
        case .purchase: return 4
        }
    }

    public static func < (a: RiskLevel, b: RiskLevel) -> Bool { a.rank < b.rank }

    /// Destructive, send and purchase always need explicit approval.
    public var alwaysNeedsApproval: Bool { self >= .destructive }
}

/// Every tool must declare how it is undone, or declare itself irreversible.
public enum UndoBehavior: Equatable, Sendable {
    case none          // read-only, nothing to undo
    case inverse       // tool records an inverse action in the journal
    case irreversible  // sent messages, submitted forms, purchases
}

public struct ActionResult: Equatable, Sendable {
    public var ok: Bool
    public var evidence: String
    public var stateAfter: String?

    public init(ok: Bool, evidence: String, stateAfter: String? = nil) {
        self.ok = ok
        self.evidence = evidence
        self.stateAfter = stateAfter
    }
}

public protocol Tool: Sendable {
    var name: String { get }
    var summary: String { get }
    var inputSchema: JSONValue { get }
    var risk: RiskLevel { get }
    var undo: UndoBehavior { get }
    func run(input: JSONValue) async throws -> ActionResult
}
