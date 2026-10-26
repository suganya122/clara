import Foundation

// Contracts for parts implemented in later milestones. Defined now so
// nothing else needs to change when the real backends arrive.

// MARK: Speech

public enum TranscriptEvent: Equatable, Sendable {
    case partial(String)
    case final(String)
}

public protocol SpeechToText: Sendable {
    /// Starts listening and streams transcript events until stopped.
    func start(language: String) -> AsyncThrowingStream<TranscriptEvent, Error>
    func stop() async
}

public protocol TextToSpeech: Sendable {
    func speak(_ text: String) async
    /// Must stop playback immediately, not at the end of the word.
    func cancel() async
    var isSpeaking: Bool { get async }
}

// MARK: Hands

public struct WindowInfo: Equatable, Sendable {
    public var id: Int
    public var app: String
    public var title: String
    public init(id: Int, app: String, title: String) {
        self.id = id
        self.app = app
        self.title = title
    }
}

public struct WindowFrame: Equatable, Sendable {
    public var x, y, width, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public protocol Hands: Sendable {
    func listWindows() async throws -> [WindowInfo]
    func focus(window: WindowInfo) async -> ActionResult
    func move(window: WindowInfo, to frame: WindowFrame) async -> ActionResult
    func click(x: Double, y: Double) async -> ActionResult
    func type(_ text: String) async -> ActionResult
    func key(_ combo: String) async -> ActionResult
    func scroll(dx: Double, dy: Double) async -> ActionResult
    func menu(app: String, path: [String]) async -> ActionResult
}

// MARK: Capture

public enum ScreenTarget: Equatable, Sendable {
    case activeWindow
    case displayUnderMouse
    case window(WindowInfo)
}

public protocol Capture: Sendable {
    /// Downscaled PNG data for vision.
    func screenshot(_ target: ScreenTarget) async throws -> Data
    /// Accessibility text of the target. Preferred over screenshots.
    func readText(_ target: ScreenTarget) async throws -> String
}

// MARK: Browser

public protocol Browser: Sendable {
    func navigate(url: URL) async -> ActionResult
    func readPage() async throws -> String
    func fill(selector: String, text: String) async -> ActionResult
    func click(selector: String) async -> ActionResult
}

// MARK: Skills

public struct Skill: Codable, Equatable, Sendable {
    public var name: String
    public var triggerPhrases: [String]
    public var parameterSlots: [String]
    public var steps: [JSONValue]
    public var postconditions: [String]
    public init(name: String, triggerPhrases: [String], parameterSlots: [String], steps: [JSONValue], postconditions: [String]) {
        self.name = name
        self.triggerPhrases = triggerPhrases
        self.parameterSlots = parameterSlots
        self.steps = steps
        self.postconditions = postconditions
    }
}

public enum ContractsVersion {
    public static let current = 1
}
