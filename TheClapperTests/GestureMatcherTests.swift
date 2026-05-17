import XCTest
@testable import TheClapper

@MainActor
final class GestureMatcherTests: XCTestCase {
    var matcher: GestureMatcher!
    
    override func setUp() {
        super.setUp()
        matcher = GestureMatcher()
        // Clear any custom gestures from previous test runs
        matcher.knownGestures.removeAll { $0.isCustom }
    }
    
    override func tearDown() {
        matcher = nil
        super.tearDown()
    }
    
    // MARK: - Built-in Gesture Matching
    
    func testMatch_singleClap_returnsSingleClap() {
        let peak = makePeak(type: .clap)
        let result = matcher.matchGesture(peak)
        XCTAssertEqual(result, .singleClap)
    }
    
    func testMatch_singleSnap_returnsSingleSnap() {
        let peak = makePeak(type: .snap)
        let result = matcher.matchGesture(peak)
        XCTAssertEqual(result, .singleSnap)
    }
    
    func testMatch_doubleClap_returnsDoubleClap() {
        let peak1 = makePeak(type: .clap, offset: 0)
        let peak2 = makePeak(type: .clap, offset: 0.25)
        
        _ = matcher.matchGesture(peak1)
        let result = matcher.matchGesture(peak2)
        XCTAssertEqual(result, .doubleClap)
    }
    
    func testMatch_tripleClap_returnsTripleClap() {
        let peak1 = makePeak(type: .clap, offset: 0)
        let peak2 = makePeak(type: .clap, offset: 0.25)
        let peak3 = makePeak(type: .clap, offset: 0.5)
        
        _ = matcher.matchGesture(peak1)
        _ = matcher.matchGesture(peak2)
        let result = matcher.matchGesture(peak3)
        XCTAssertEqual(result, .tripleClap)
    }
    
    func testMatch_mixedPeaks_returnsNil() {
        let peak1 = makePeak(type: .clap, offset: 0)
        let peak2 = makePeak(type: .snap, offset: 0.25)
        
        _ = matcher.matchGesture(peak1)
        let result = matcher.matchGesture(peak2)
        XCTAssertNil(result)
    }
    
    func testMatch_noPeaks_returnsNil() {
        // Without feeding any peaks, matcher should not match any gesture
        XCTAssertNil(matcher.lastMatchedGesture)
    }
    
    // MARK: - Custom Gesture Training
    
    func testTrainCustomGesture_validSamples_returnsGesture() {
        let samples = [
            [makePeak(type: .clap, offset: 0), makePeak(type: .clap, offset: 0.3)],
            [makePeak(type: .clap, offset: 0), makePeak(type: .clap, offset: 0.35)],
            [makePeak(type: .clap, offset: 0), makePeak(type: .clap, offset: 0.28)]
        ]
        
        let gesture = matcher.trainCustomGesture(name: "My Clap", samples: samples)
        XCTAssertNotNil(gesture)
        XCTAssertEqual(gesture?.name, "My Clap")
        XCTAssertTrue(gesture?.isCustom ?? false)
    }
    
    func testTrainCustomGesture_differentPeakCounts_returnsNil() {
        let samples = [
            [makePeak(type: .clap)],
            [makePeak(type: .clap), makePeak(type: .clap)],
            [makePeak(type: .clap)]
        ]
        
        let gesture = matcher.trainCustomGesture(name: "Bad", samples: samples)
        XCTAssertNil(gesture)
    }
    
    func testTrainCustomGesture_emptySamples_returnsNil() {
        let samples = [[PeakDetector.DetectedPeak](), [PeakDetector.DetectedPeak](), [PeakDetector.DetectedPeak]()]
        let gesture = matcher.trainCustomGesture(name: "Empty", samples: samples)
        XCTAssertNil(gesture)
    }
    
    // MARK: - Helpers
    
    private func makePeak(type: PeakDetector.PeakType, offset: TimeInterval = 0) -> PeakDetector.DetectedPeak {
        PeakDetector.DetectedPeak(
            timestamp: Date().addingTimeInterval(offset),
            amplitude: 0.8,
            frequency: type == .clap ? 3500 : 7000,
            type: type,
            confidence: 0.9,
            frequencyProfile: Array(repeating: 0.5, count: 384)
        )
    }
}
