import XCTest
@testable import TheClapper

final class DTWEngineTests: XCTestCase {
    func testCompare_identicalPatterns_areMatch() {
        let engine = DTWEngine()
        let distance = engine.compare(pattern1: [0.0, 0.2, 0.5, 1.0], pattern2: [0.0, 0.2, 0.5, 1.0])
        XCTAssertLessThan(distance, 0.15)
    }

    func testCompare_differentPatterns_areNoMatch() {
        let engine = DTWEngine()
        let distance = engine.compare(pattern1: [0.0, 0.1, 0.15, 0.2], pattern2: [0.0, 0.65, 0.85, 1.0])
        XCTAssertGreaterThan(distance, 0.4)
    }
}
