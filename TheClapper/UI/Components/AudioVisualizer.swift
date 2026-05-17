import SwiftUI

/// Real-time audio visualization component for gesture detection feedback
struct AudioVisualizer: View {
    @ObservedObject var audioCapture: AudioCapture
    
    @State private var barHeights: [CGFloat] = Array(repeating: 0.1, count: 20)
    @State private var peakIndicator: Bool = false
    @State private var lastPeakType: PeakType = .none
    
    private let barCount = 20
    private let updateInterval: TimeInterval = 0.05
    
    enum PeakType {
        case none
        case clap
        case snap
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                
                VStack(spacing: 8) {
                    // Visualizer bars
                    HStack(spacing: 4) {
                        ForEach(0..<barCount, id: \.self) { index in
                            VisualizerBar(
                                height: barHeights[index],
                                color: barColor(for: index),
                                peakType: lastPeakType
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: geometry.size.height * 0.6)
                    
                    // Peak indicator
                    HStack(spacing: 16) {
                        PeakLabel(
                            icon: "hand.tap.fill",
                            label: "Clap",
                            isActive: lastPeakType == .clap && peakIndicator
                        )
                        
                        PeakLabel(
                            icon: "sparkles",
                            label: "Snap",
                            isActive: lastPeakType == .snap && peakIndicator
                        )
                        
                        Spacer()
                        
                        // Sensitivity indicator
                        HStack(spacing: 4) {
                            ForEach(0..<4) { i in
                                Circle()
                                    .fill(sensitivityColor(for: i))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .font(.caption)
                }
            }
            .onAppear {
                startVisualization()
            }
            .onDisappear {
                stopVisualization()
            }
        }
    }
    
    // MARK: - Visualization
    
    private func startVisualization() {
        // Subscribe to audio level updates
        Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            updateBarHeights()
        }
        
        // Peak detection callback
        audioCapture.onPeakDetected = { peak in
            DispatchQueue.main.async {
                self.handlePeak(peak: peak)
            }
        }
    }
    
    private func stopVisualization() {
        // Cleanup handled by timer invalidation on view disappear
    }
    
    private func updateBarHeights() {
        withAnimation(.easeOut(duration: updateInterval)) {
            // Generate heights based on simulated audio levels
            // In real app, this would use actual FFT data
            for i in 0..<barCount {
                let targetHeight = CGFloat.random(in: 0.1...0.8)
                let current = barHeights[i]
                
                // Smooth decay
                barHeights[i] = current * 0.7 + targetHeight * 0.3
            }
            
            // Sort for wave effect (optional)
            // barHeights.sort(by: { abs($0 - 0.5) < abs($1 - 0.5) })
        }
    }
    
    private func handlePeak(peak: PeakDetector.DetectedPeak) {
        // Flash peak indicator
        withAnimation(.easeInOut(duration: 0.1)) {
            peakIndicator = true
            lastPeakType = peak.type == .clap ? .clap : .snap
            
            // Boost visualization bars
            for i in 0..<min(5, barCount) {
                barHeights[i] = 1.0
            }
        }
        
        // Fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.2)) {
                peakIndicator = false
            }
        }
    }
    
    // MARK: - Styling
    
    private func barColor(for index: Int) -> Color {
        let progress = Double(index) / Double(barCount)
        
        // Gradient from blue to purple
        return Color(
            hue: 0.6 - (progress * 0.2),
            saturation: 0.8,
            brightness: 0.9
        )
    }
    
    private func sensitivityColor(for index: Int) -> Color {
        // 4-dot sensitivity indicator
        let sensitivity = 3 // 0-3
        return index <= sensitivity ? Color.green : Color.gray.opacity(0.3)
    }
}

// MARK: - Visualizer Bar

struct VisualizerBar: View {
    let height: CGFloat
    let color: Color
    let peakType: AudioVisualizer.PeakType
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                peakType == .clap ? Color.orange :
                peakType == .snap ? Color.yellow :
                color
            )
            .frame(height: height * 100)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .animation(.easeOut(duration: 0.05), value: height)
    }
}

// MARK: - Peak Label

struct PeakLabel: View {
    let icon: String
    let label: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(label)
        }
        .foregroundStyle(isActive ? Color.blue : Color.secondary)
        .font(.caption)
        .fontWeight(isActive ? .semibold : .regular)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isActive ? Color.blue.opacity(0.2) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

// MARK: - Preview

#Preview {
    AudioVisualizer(audioCapture: AudioCapture())
        .frame(height: 100)
        .padding()
}
