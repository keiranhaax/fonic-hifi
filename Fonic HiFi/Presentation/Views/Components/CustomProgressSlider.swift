//
//  CustomProgressSlider.swift
//  Fonic HiFi
//
//  Custom progress slider matching Apple Music's design:
//  - Thin track (4pt height)
//  - Circular thumb, visible at rest (8pt), expands on drag (14pt)
//  - Full 44pt touch target for HIG compliance
//

import SwiftUI

@MainActor
struct CustomProgressSlider: View {
    @Binding var progress: Double
    let onEditingChanged: (Bool) -> Void
    var abLoopState: ABLoopState?
    var duration: TimeInterval?

    @State private var isDragging = false
    @State private var trackWidth: CGFloat = 1 // Avoid division by zero

    private var thumbSize: CGFloat {
        isDragging ? 14 : 8
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Track background
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(height: 4)

            // A-B Loop region highlight
            if let loopState = abLoopState,
               let duration,
               duration > 0,
               let pointA = loopState.pointA {
                let aProgress = pointA / duration
                let bProgress = loopState.pointB.map { $0 / duration } ?? progress

                // Highlighted region
                Capsule()
                    .fill(Color.orange.opacity(0.4))
                    .frame(
                        width: max(0, trackWidth * (bProgress - aProgress)),
                        height: 4
                    )
                    .offset(x: trackWidth * aProgress)
            }

            // Filled track
            Capsule()
                .fill(Color.white)
                .frame(width: max(0, trackWidth * progress), height: 4)

            // Thumb - always visible, expands on drag
            Circle()
                .fill(Color.white)
                .frame(width: thumbSize, height: thumbSize)
                .offset(x: thumbOffset)
                .animation(.easeInOut(duration: 0.15), value: isDragging)

            // A-B Loop markers
            if let loopState = abLoopState,
               let duration,
               duration > 0 {
                // Point A marker
                if let pointA = loopState.pointA {
                    let aProgress = pointA / duration
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 2, height: 10)
                        .offset(x: trackWidth * aProgress - 1)
                }

                // Point B marker
                if let pointB = loopState.pointB {
                    let bProgress = pointB / duration
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 2, height: 10)
                        .offset(x: trackWidth * bProgress - 1)
                }
            }
        }
        .frame(height: 44, alignment: .center) // Full touch target
        .contentShape(Rectangle())
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            trackWidth = width
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        onEditingChanged(true)
                    }
                    let newProgress = max(0, min(1, value.location.x / trackWidth))
                    progress = newProgress
                }
                .onEnded { _ in
                    isDragging = false
                    onEditingChanged(false)
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                progress = min(1, progress + 0.05)
                onEditingChanged(true)
                onEditingChanged(false)
            case .decrement:
                progress = max(0, progress - 0.05)
                onEditingChanged(true)
                onEditingChanged(false)
            @unknown default:
                break
            }
        }
    }

    private var thumbOffset: CGFloat {
        // Calculate offset so thumb center follows progress
        // At progress 0: thumb left edge at 0 (center at thumbSize/2)
        // At progress 1: thumb right edge at trackWidth (center at trackWidth - thumbSize/2)
        let availableTrackLength = trackWidth - thumbSize
        return availableTrackLength * progress
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var progress = 0.5

    VStack(spacing: 40) {
        CustomProgressSlider(progress: $progress) { _ in }
            .padding(.horizontal, 24)

        Text("Progress: \(Int(progress * 100))%")
            .foregroundStyle(.white)
    }
    .padding()
    .background(Color.black)
}
