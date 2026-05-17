import Foundation
import Accelerate

/// FFT processing using Accelerate framework
class FFTProcessor {
    private var fftSetup: vDSP_DFT_Setup?
    private let fftSize: Int = 2048
    
    init() {
        // Create FFT setup (forward, real to complex)
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            .FORWARD
        )
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetupD(setup)
        }
    }
    
    /// Perform FFT on audio samples
    /// - Returns: Frequency magnitudes (2-8kHz range focus)
    func performFFT(on samples: [Float]) -> [Float] {
        // Zero-pad or truncate to fftSize
        var paddedSamples = samples
        if paddedSamples.count < fftSize {
            paddedSamples.append(contentsOf: [Float](repeating: 0, count: fftSize - paddedSamples.count))
        } else if paddedSamples.count > fftSize {
            paddedSamples = Array(paddedSamples.prefix(fftSize))
        }
        
        // Split real input into interleaved complex format
        var real = paddedSamples
        var imaginary = [Float](repeating: 0, count: fftSize)
        
        // Perform FFT
        real.withUnsafeMutableBufferPointer { realPtr in
            imaginary.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(
                    realp: realPtr.baseAddress!,
                    imagp: imagPtr.baseAddress!
                )
                
                // Apply Hann window to reduce spectral leakage
                var window = [Float](repeating: 0, count: fftSize)
                vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_DENORM))
                vDSP_vmul(realPtr.baseAddress!, 1, window, 1, realPtr.baseAddress!, 1, vDSP_Length(fftSize))
                
                // Execute FFT
                if let setup = fftSetup {
                    vDSP_DFT_Execute(setup, realPtr.baseAddress!, imagPtr.baseAddress!,
                                   realPtr.baseAddress!, imagPtr.baseAddress!)
                }
            }
        }
        
        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<(fftSize / 2) {
            let real = real[i]
            let imag = imaginary[i]
            magnitudes[i] = sqrt(real * real + imag * imag)
        }
        
        // Normalize
        var maxMag: Float = 0
        vDSP_maxv(magnitudes, 1, &maxMag, vDSP_Length(magnitudes.count))
        if maxMag > 0 {
            var scalar = 1.0 / maxMag
            vDSP_vsmul(magnitudes, 1, &scalar, &magnitudes, 1, vDSP_Length(magnitudes.count))
        }
        
        return magnitudes
    }
    
    /// Get frequency for a given bin index
    func frequency(for bin: Int, sampleRate: Double = 16000.0) -> Double {
        return Double(bin) * sampleRate / Double(fftSize)
    }
    
    /// Get bin index for a given frequency
    func bin(for frequency: Double, sampleRate: Double = 16000.0) -> Int {
        return Int(frequency * Double(fftSize) / sampleRate)
    }
}
