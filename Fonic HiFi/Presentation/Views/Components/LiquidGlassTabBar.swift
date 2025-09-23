//
//  LiquidGlassTabBar.swift
//  Fonic HiFi
//
//  Custom Liquid Glass Tab Bar matching Apple Music's design
//  iOS 26+ Implementation with enhanced Material system
//

import SwiftUI

/// Custom Liquid Glass Tab Bar for iOS 26+
/// Matches Apple Music's exact visual implementation
@available(iOS 26, *)
@MainActor
struct LiquidGlassTabBar: View {
  @Binding var selection: Int
  let items: [TabItem]
  
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  
  // Constants for Apple Music styling
  private let tabBarHeight: CGFloat = 49
  private let iconSize: CGFloat = 24
  private let selectedIconScale: CGFloat = 1.1
  
  var body: some View {
    HStack(spacing: 0) {
      ForEach(items) { item in
        TabButton(
          item: item,
          isSelected: selection == item.id,
          iconSize: iconSize,
          selectedScale: selectedIconScale
        )
        .onTapGesture {
          selectTab(item.id)
        }
      }
    }
    .frame(height: tabBarHeight)
    .frame(maxWidth: .infinity)
    // Use ultraThinMaterial with 0.8 opacity as per Apple Music
    .background(
      Rectangle()
        .fill(.ultraThinMaterial)
        .opacity(0.8)
        .overlay(alignment: .top) {
          // Subtle top border gradient
          LinearGradient(
            colors: [
              Color.white.opacity(0.1),
              Color.clear
            ],
            startPoint: .leading,
            endPoint: .trailing
          )
          .frame(height: 0.5)
        }
    )
    // iOS 26 optimizations
    .clearGlassFix()
    .preferredFrameRate(120) // ProMotion support
  }
  
  private func selectTab(_ tabId: Int) {
    // Animate selection with spring
    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
      selection = tabId
    }
    
    // Haptic feedback
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.prepare()
    generator.impactOccurred(intensity: 0.7)
  }
}

// MARK: - Tab Button Component

@available(iOS 26, *)
private struct TabButton: View {
  let item: TabItem
  let isSelected: Bool
  let iconSize: CGFloat
  let selectedScale: CGFloat
  
  @Environment(\.colorScheme) private var colorScheme
  
  var body: some View {
    VStack(spacing: 4) {
      Image(systemName: isSelected ? item.selectedIcon : item.icon)
        .font(.system(size: iconSize))
        .symbolRenderingMode(.hierarchical)
        .scaleEffect(isSelected ? selectedScale : 1.0)
        .foregroundStyle(isSelected ? .primary : .secondary)
      
      Text(item.title)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(isSelected ? .primary : .secondary)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 49)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(item.title) tab")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select")
  }
}

// MARK: - Tab Item Model

@available(iOS 26, *)
struct TabItem: Identifiable {
  let id: Int
  let title: String
  let icon: String
  let selectedIcon: String
  
  init(id: Int, title: String, icon: String, selectedIcon: String? = nil) {
    self.id = id
    self.title = title
    self.icon = icon
    self.selectedIcon = selectedIcon ?? icon
  }
}

// MARK: - Standard Tab Items

@available(iOS 26, *)
extension TabItem {
  static let standardItems = [
    TabItem(id: 0, title: "Library", icon: "music.note.list", selectedIcon: "music.note.list"),
    TabItem(id: 1, title: "Home", icon: "house", selectedIcon: "house.fill"),
    TabItem(id: 2, title: "Search", icon: "magnifyingglass", selectedIcon: "magnifyingglass"),
    TabItem(id: 3, title: "Settings", icon: "gearshape", selectedIcon: "gearshape.fill")
  ]
}

// MARK: - Preview

#Preview("Liquid Glass Tab Bar") {
  @Previewable @State var selection = 0
  
  return VStack {
    Spacer()
    
    if #available(iOS 26, *) {
      LiquidGlassTabBar(
        selection: $selection,
        items: TabItem.standardItems
      )
    }
  }
  .background(
    LinearGradient(
      colors: [.black, .blue.opacity(0.3)],
      startPoint: .top,
      endPoint: .bottom
    )
  )
  .preferredColorScheme(.dark)
}

#Preview("Tab Bar with Different Selections") {
  VStack(spacing: 20) {
    ForEach(0..<4) { index in
      if #available(iOS 26, *) {
        LiquidGlassTabBar(
          selection: .constant(index),
          items: TabItem.standardItems
        )
      }
    }
  }
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}