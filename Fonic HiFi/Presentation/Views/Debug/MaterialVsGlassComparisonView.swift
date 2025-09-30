//
//  MaterialVsGlassComparisonView.swift
//  Fonic HiFi
//
//  Phase 0: Visual Fidelity Gate for Liquid Glass Migration
//  iOS 26+ Material vs Glass Comparison Harness
//

import SwiftUI

struct MaterialVsGlassComparisonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Test 1: ultraThin → clear
                ComparisonRow(
                    title: "ultraThin → clear",
                    material: { Text("Material").background(.thinMaterial) },
                    glass: { Text("Glass").glassEffect(.clear) }
                )

                // Test 2: standard → regular
                ComparisonRow(
                    title: "standard → regular",
                    material: { Text("Material").background(.regularMaterial) },
                    glass: { Text("Glass").glassEffect(.regular) }
                )

                // Test 3: thick → regular
                ComparisonRow(
                    title: "thick → regular",
                    material: { Text("Material").background(.thickMaterial) },
                    glass: { Text("Glass").glassEffect(.regular) }
                )

                // Test 4: intensity mappings (0.6, 0.7, 0.8, 0.9)
                VStack {
                    ForEach([0.6, 0.7, 0.8, 0.9], id: \.self) { intensity in
                        ComparisonRow(
                            title: "intensity: \(intensity)",
                            material: { Text("Material \(intensity)").background(.regularMaterial.opacity(intensity)) },
                            glass: { Text("Glass \(intensity)").glassEffect(.regular.tint(.white.opacity(intensity))) }
                        )
                    }
                }
            }
        }
        .background(.purple.gradient) // Test on colored backgrounds
    }
}

struct ComparisonRow<MaterialContent: View, GlassContent: View>: View {
    let title: String
    @ViewBuilder let material: () -> MaterialContent
    @ViewBuilder let glass: () -> GlassContent

    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            HStack(spacing: 20) {
                VStack {
                    material()
                    Text("CURRENT (Material)").font(.caption)
                }
                VStack {
                    glass()
                    Text("PROPOSED (Glass)").font(.caption)
                }
            }
        }
        .padding()
    }
}

#Preview {
    MaterialVsGlassComparisonView()
}