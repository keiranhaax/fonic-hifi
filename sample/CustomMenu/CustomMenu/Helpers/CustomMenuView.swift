//
//  CustomMenuView.swift
//  CustomMenu
//
//  Created by Balaji Venkatesh on 20/09/25.
//

import SwiftUI

struct CustomMenuView<Label: View, Content: View>: View {
    var style: CustomMenuStyle = .glass
    var isHapticsEnabled: Bool = true
    @ViewBuilder var label: Label
    @ViewBuilder var content: Content
    /// View Properties
    /// Optional Haptics Feedback!
    @State private var haptics: Bool = false
    @State private var isExpanded: Bool = false
    /// For Zoom transition
    @Namespace private var namespace
    var body: some View {
        Button {
            if isHapticsEnabled {
                haptics.toggle()
            }
            
            isExpanded.toggle()
        } label: {
            label
                .matchedTransitionSource(id: "MENUCONTENT", in: namespace)
        }
        /// Applying Menu Style!
        .applyStyle(style)
        .popover(isPresented: $isExpanded) {
            PopOverHelper {
                content
            }
            .navigationTransition(.zoom(sourceID: "MENUCONTENT", in: namespace))
        }
        .sensoryFeedback(.selection, trigger: haptics)
    }
}

fileprivate struct PopOverHelper<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var isVisible: Bool = false
    var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .task {
                try? await Task.sleep(for: .seconds(0.1))
                withAnimation(.snappy(duration: 0.3, extraBounce: 0)) {
                    isVisible = true
                }
            }
            .presentationCompactAdaptation(.popover)
    }
}

/// Menu Style
enum CustomMenuStyle: String, CaseIterable {
    case glass = "Glass"
    case glassProminent = "Glass Prominent"
}

fileprivate extension View {
    @ViewBuilder
    func applyStyle(_ style: CustomMenuStyle) -> some View {
        switch style {
        case .glass:
            self
                .buttonStyle(.glass)
        case .glassProminent:
            self
                .buttonStyle(.glassProminent)
        }
    }
}

#Preview {
    ContentView()
}
