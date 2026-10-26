import XCTest
@testable import Contracts

final class ContractsTests: XCTestCase {
    func testJSONValueRoundTrip() throws {
        let value: JSONValue = .object([
            "a": .number(1.5),
            "b": .array([.bool(true), .null, .string("x")]),
            "c": .object(["d": .string("e")]),
        ])
        let data = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: data), value)
    }

    func testRiskOrderingAndApproval() {
        XCTAssertTrue(RiskLevel.read < .write)
        XCTAssertTrue(RiskLevel.purchase > .externalSend)
        XCTAssertFalse(RiskLevel.read.alwaysNeedsApproval)
        XCTAssertFalse(RiskLevel.write.alwaysNeedsApproval)
        XCTAssertTrue(RiskLevel.destructive.alwaysNeedsApproval)
        XCTAssertTrue(RiskLevel.externalSend.alwaysNeedsApproval)
        XCTAssertTrue(RiskLevel.purchase.alwaysNeedsApproval)
    }
}
