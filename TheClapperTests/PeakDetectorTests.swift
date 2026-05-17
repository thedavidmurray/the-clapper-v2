import XCTest
@testable import TheClapper

final class PeakDetectorTests: XCTestCase {
    var detector: PeakDetector!
    
    override func setUp() {
        super.setUp()
        detector = PeakDetector()
    }
    
    override func tearDown() {
        detector = nil
        super.tearDown()
    }
    
    // MARK: - Clap Detection
    
    func testDetectPeak_strongClapEnergy_returnsClap() {
        let fft = makeFFT(clapEnergy: 0.9, snapEnergy: 0.1)
        let peak = detector.detectPeak(in: fft, amplitude: 0.5)
        XCTAssertNotNil(peak)
        XCTAssertEqual(peak?.type, .clap)
    }
    
    func testDetectPeak_strongSnapEnergy_returnsSnap() {
        let fft = makeFFT(clapEnergy: 0.1, snapEnergy: 0.9)
        let peak = detector.detectPeak(in: fft, amplitude: 0.5)
        XCTAssertNotNil(peak)
        XCTAssertEqual(peak?.type, .snap)
    }
    
    func testDetectPeak_lowEnergy_returnsNil() {
        let fft = makeFFT(clapEnergy: 0.1, snapEnergy: 0.1)
        let peak = detector.detectPeak(in: fft, amplitude: 0.05)
        XCTAssertNil(peak)
    }
    
    func testDetectPeak_cooldownPreventsDoubleDetection() {
        let fft = makeFFT(clapEnergy: 0.9, snapEnergy: 0.1)
        let peak1 = detector.detectPeak(in: fft, amplitude: 0.5)
        XCTAssertNotNil(peak1)
        
        // Immediate second call should return nil due to cooldown
        let peak2 = detector.detectPeak(in: fft, amplitude: 0.5)
        XCTAssertNil(peak2)
    }
    
    func testDetectPeak_afterCooldown_returnsNewPeak() {
        let fft = makeFFT(clapEnergy: 0.9, snapEnergy: 0.1)
        let peak1 = detector.detectPeak(in: fft, amplitude: 0.5)
        XCTAssertNotNil(peak1)
        
        // Wait for cooldown
        Thread.sleep(forTimeInterval: 0.25)
        
        let peak2 = detector.detectPeak(in: fft, amplitude: 0.5)
        XCTAssertNotNil(peak2)
    }
    
    // MARK: - Ambient Noise Handling
    
    func testDetectPeak_ambientNoiseAdjusted_returnsPeak() {
        // First establish ambient noise floor
        let ambientFFT = makeFFT(clapEnergy: 0.05, snapEnergy: 0.05)
        for _ in 0..<5 {
            _ = detector.detectPeak(in: ambientFFT, amplitude: 0.05)
        }
        
        // Now detect strong clap above ambient
        let strongFFT = makeFFT(clapEnergy: 0.9, snapEnergy: 0.1)
        let peak = detector.detectPeak(in: strongFFT, amplitude: 0.6)
        XCTAssertNotNil(peak)
        XCTAssertEqual(peak?.type, .clap)
    }
    
    // MARK: - Buffer Management
    
    func testRecentPeaks_returnsPeaksInWindow() {
        let fft = makeFFT(clapEnergy: 0.9, snapEnergy: 0.1)
        let peak = detector.detectPeak(in: fft, amplitude: 0.5)
        XCTAssertNotNil(peak)
        
        let recent = detector.recentPeaks(since: 1.0)
        XCTAssertEqual(recent.count, 1)
    }
    
    func testClearBuffer_removesAllPeaks() {
        let fft = makeFFT(clapEnergy: 0.9, snapEnergy: 0.1)
        _ = detector.detectPeak(in: fft, amplitude: 0.5)
        
        detector.clearBuffer()
        let recent = detector.recentPeaks(since: 10.0)
        XCTAssertEqual(recent.count, 0)
    }
    
    // MARK: - Helpers
    
    private func makeFFT(clapEnergy: Float, snapEnergy: Float) -> [Float] {
        var magnitudes = Array(repeating: Float(0.01), count: 1025)
        
        // Clap range: 256...640 (2-5kHz)
        for i in 256...640 {
            magnitudes[i] = clapEnergy
        }
        
        // Snap range: 640...1024 (5-8kHz)
        for i in 640...1024 {
            magnitudes[i] = snapEnergy
        }
        
        return magnitudes
    }
}
