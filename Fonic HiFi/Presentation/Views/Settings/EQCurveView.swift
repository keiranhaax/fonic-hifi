//
//  EQCurveView.swift
//  Fonic HiFi
//
//  Frequency response curve visualization for the 10-band EQ
//

import SwiftUI

struct EQCurveView: View {
    let configuration: EqualizerConfiguration

    private let minFreq: Float = 20
    private let maxFreq: Float = 20000
    private let minDB: Float = -12
    private let maxDB: Float = 12

    var body: some View {
        Canvas { context, size in
            // Draw grid lines
            drawGrid(context: context, size: size)

            // Draw EQ curve
            drawCurve(context: context, size: size)

            // Draw band markers
            drawBandMarkers(context: context, size: size)
        }
        .frame(height: 120)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridColor = Color.gray.opacity(0.3)

        // Horizontal center line (0 dB)
        let centerY = size.height / 2
        var centerPath = Path()
        centerPath.move(to: CGPoint(x: 0, y: centerY))
        centerPath.addLine(to: CGPoint(x: size.width, y: centerY))
        context.stroke(centerPath, with: .color(gridColor), lineWidth: 1)

        // +6 dB and -6 dB lines
        let quarterHeight = size.height / 4
        var topPath = Path()
        topPath.move(to: CGPoint(x: 0, y: quarterHeight))
        topPath.addLine(to: CGPoint(x: size.width, y: quarterHeight))
        context.stroke(topPath, with: .color(gridColor.opacity(0.5)), lineWidth: 0.5)

        var bottomPath = Path()
        bottomPath.move(to: CGPoint(x: 0, y: size.height - quarterHeight))
        bottomPath.addLine(to: CGPoint(x: size.width, y: size.height - quarterHeight))
        context.stroke(bottomPath, with: .color(gridColor.opacity(0.5)), lineWidth: 0.5)
    }

    private func drawCurve(context: GraphicsContext, size: CGSize) {
        var path = Path()
        let points = 200

        for i in 0..<points {
            let x = CGFloat(i) / CGFloat(points - 1) * size.width
            let freq = freqFromX(x: Float(x), width: Float(size.width))
            let gain = interpolatedGain(at: freq)
            let y = yFromDB(db: gain, height: Float(size.height))

            if i == 0 {
                path.move(to: CGPoint(x: x, y: CGFloat(y)))
            } else {
                path.addLine(to: CGPoint(x: x, y: CGFloat(y)))
            }
        }

        // Draw gradient fill under the curve
        var fillPath = path
        fillPath.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        fillPath.addLine(to: CGPoint(x: 0, y: size.height / 2))
        fillPath.closeSubpath()

        context.fill(fillPath, with: .color(Color.orange.opacity(0.2)))
        context.stroke(path, with: .color(.orange), lineWidth: 2)
    }

    private func drawBandMarkers(context: GraphicsContext, size: CGSize) {
        for band in configuration.bands {
            let x = xFromFreq(freq: band.frequency, width: Float(size.width))
            let y = yFromDB(db: band.gain, height: Float(size.height))

            // Draw small circle at each band's current position
            let markerPath = Path(ellipseIn: CGRect(
                x: CGFloat(x) - 3,
                y: CGFloat(y) - 3,
                width: 6,
                height: 6
            ))
            context.fill(markerPath, with: .color(.white))
            context.stroke(markerPath, with: .color(.orange), lineWidth: 1)
        }
    }

    private func freqFromX(x: Float, width: Float) -> Float {
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let logFreq = logMin + (x / width) * (logMax - logMin)
        return pow(10, logFreq)
    }

    private func xFromFreq(freq: Float, width: Float) -> Float {
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let logFreq = log10(freq)
        return ((logFreq - logMin) / (logMax - logMin)) * width
    }

    private func yFromDB(db: Float, height: Float) -> Float {
        let normalized = (db - minDB) / (maxDB - minDB)
        return height * (1 - normalized)
    }

    private func interpolatedGain(at freq: Float) -> Float {
        let bands = configuration.bands

        // Find surrounding bands
        for i in 0..<(bands.count - 1) {
            let band1 = bands[i]
            let band2 = bands[i + 1]

            if freq >= band1.frequency && freq <= band2.frequency {
                // Use logarithmic interpolation for frequency
                let logFreq = log10(freq)
                let logFreq1 = log10(band1.frequency)
                let logFreq2 = log10(band2.frequency)
                let t = (logFreq - logFreq1) / (logFreq2 - logFreq1)

                // Smooth interpolation using cosine for natural curve
                let smoothT = (1 - cos(t * .pi)) / 2
                return band1.gain + Float(smoothT) * (band2.gain - band1.gain)
            }
        }

        // Edge cases - use shelf behavior
        if freq < bands[0].frequency {
            // Low shelf extends flat from first band
            return bands[0].gain
        }
        if freq > bands[bands.count - 1].frequency {
            // High shelf extends flat from last band
            return bands[bands.count - 1].gain
        }

        return 0
    }
}

#Preview {
    VStack {
        EQCurveView(configuration: .default)
            .padding()

        if let bassBoost = EqualizerConfiguration.presets["Bass Boost"] {
            EQCurveView(configuration: bassBoost)
                .padding()
        }

        if let rock = EqualizerConfiguration.presets["Rock"] {
            EQCurveView(configuration: rock)
                .padding()
        }
    }
    .background(Color(.systemBackground))
}
