//
//  AccessibilityEnhancements.swift
//  Fonic HiFi
//
//  Created by Claude on 8/13/25.
//  iOS 26+ Enhanced Accessibility Features
//

import SwiftUI

// MARK: - iOS 26+ Accessibility Enhancements


extension View {
  /// Enhanced VoiceOver support with contextual descriptions
  func enhancedAccessibility(
    label: String,
    hint: String? = nil,
    value: String? = nil,
    traits: AccessibilityTraits = [],
    customAction: (() -> Void)? = nil
  ) -> some View {
    modifier(EnhancedAccessibilityModifier(
      label: label,
      hint: hint,
      value: value,
      traits: traits,
      customAction: customAction
    ))
  }
  
  /// Audio context for music player accessibility
  func audioContextAccessibility(
    isPlaying: Bool,
    trackTitle: String?,
    artist: String?,
    progress: Double? = nil,
    duration: Double? = nil
  ) -> some View {
    modifier(AudioContextAccessibilityModifier(
      isPlaying: isPlaying,
      trackTitle: trackTitle,
      artist: artist,
      progress: progress,
      duration: duration
    ))
  }
  
  /// Dynamic Type support with enhanced scaling
  func adaptiveDynamicType(
    minScale: CGFloat = 0.8,
    maxScale: CGFloat = 2.0
  ) -> some View {
    modifier(AdaptiveDynamicTypeModifier(minScale: minScale, maxScale: maxScale))
  }
  
  /// Assistive Access mode optimization
  func assistiveAccessOptimized(
    simplifiedLayout: Bool = true,
    highContrast: Bool = true,
    largerTargets: Bool = true
  ) -> some View {
    modifier(AssistiveAccessModifier(
      simplifiedLayout: simplifiedLayout,
      highContrast: highContrast,
      largerTargets: largerTargets
    ))
  }
  
  /// Focus management for keyboard navigation
  func enhancedKeyboardNavigation(
    focusableElement: Bool = true,
    customFocusAction: (() -> Void)? = nil
  ) -> some View {
    modifier(KeyboardNavigationModifier(
      focusableElement: focusableElement,
      customFocusAction: customFocusAction
    ))
  }
}

// MARK: - Accessibility Modifiers


struct EnhancedAccessibilityModifier: ViewModifier {
  let label: String
  let hint: String?
  let value: String?
  let traits: AccessibilityTraits
  let customAction: (() -> Void)?
  
  func body(content: Content) -> some View {
    content
      .accessibilityLabel(label)
      .accessibilityHint(hint ?? "")
      .accessibilityValue(value ?? "")
      .accessibilityAddTraits(traits)
      .if(customAction != nil) { view in
        view.accessibilityAction(.default) {
          customAction?()
        }
      }
      .accessibilityRespondsToUserInteraction()
  }
}


struct AudioContextAccessibilityModifier: ViewModifier {
  let isPlaying: Bool
  let trackTitle: String?
  let artist: String?
  let progress: Double?
  let duration: Double?
  
  private var playbackDescription: String {
    var description = ""
    
    if let title = trackTitle, let artist = artist {
      description += "Now \(isPlaying ? "playing" : "paused"): \(title) by \(artist). "
    } else if let title = trackTitle {
      description += "Now \(isPlaying ? "playing" : "paused"): \(title). "
    } else {
      description += isPlaying ? "Audio playing. " : "Audio paused. "
    }
    
    if let progress = progress, let duration = duration, duration > 0 {
      let currentMinutes = Int(progress * duration) / 60
      let currentSeconds = Int(progress * duration) % 60
      let totalMinutes = Int(duration) / 60
      let totalSeconds = Int(duration) % 60
      let percentage = Int(progress * 100)
      
      description += "Progress: \(currentMinutes):\(String(format: "%02d", currentSeconds)) of \(totalMinutes):\(String(format: "%02d", totalSeconds)). \(percentage) percent complete."
    }
    
    return description
  }
  
  func body(content: Content) -> some View {
    content
      .accessibilityElement(children: .combine)
      .accessibilityLabel(playbackDescription)
      .accessibilityAddTraits(isPlaying ? [.playsSound, .updatesFrequently] : [.playsSound])
      .accessibilityAction(.default) {
        // Custom activation action for audio controls
      }
  }
}


struct AdaptiveDynamicTypeModifier: ViewModifier {
  let minScale: CGFloat
  let maxScale: CGFloat
  
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  
  private var scaleFactor: CGFloat {
    let currentSize = dynamicTypeSize
    
    // Calculate scale based on dynamic type size
    switch currentSize {
    case .xSmall, .small:
      return max(minScale, 0.85)
    case .medium:
      return max(minScale, 0.95)
    case .large:
      return 1.0
    case .xLarge:
      return min(maxScale, 1.15)
    case .xxLarge:
      return min(maxScale, 1.3)
    case .xxxLarge:
      return min(maxScale, 1.5)
    case .accessibility1:
      return min(maxScale, 1.7)
    case .accessibility2:
      return min(maxScale, 1.9)
    case .accessibility3, .accessibility4, .accessibility5:
      return maxScale
    @unknown default:
      return 1.0
    }
  }
  
  func body(content: Content) -> some View {
    content
      .scaleEffect(scaleFactor)
      .animation(.easeInOut(duration: 0.3), value: scaleFactor)
  }
}


struct AssistiveAccessModifier: ViewModifier {
  let simplifiedLayout: Bool
  let highContrast: Bool
  let largerTargets: Bool
  
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityDifferentiateWithoutColor) private var accessibilityHighContrast
  
  func body(content: Content) -> some View {
    content
      .if(simplifiedLayout) { view in
        view
          .padding(.horizontal, largerTargets ? 8 : 4)
          .padding(.vertical, largerTargets ? 6 : 3)
      }
      .if(highContrast && accessibilityHighContrast) { view in
        view
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(.primary, lineWidth: 2)
              .opacity(0.8)
          )
      }
      .if(largerTargets) { view in
        view
          .frame(minWidth: 44, minHeight: 44)
      }
      .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: accessibilityHighContrast)
  }
}


struct KeyboardNavigationModifier: ViewModifier {
  let focusableElement: Bool
  let customFocusAction: (() -> Void)?
  
  @FocusState private var isFocused: Bool
  
  func body(content: Content) -> some View {
    content
      .focusable(focusableElement)
      .focused($isFocused)
      .onKeyPress(.space) {
        customFocusAction?()
        return .handled
      }
      .onKeyPress(.return) {
        customFocusAction?()
        return .handled
      }
      .overlay(
        RoundedRectangle(cornerRadius: 4)
          .stroke(.blue, lineWidth: 3)
          .opacity(isFocused ? 1 : 0)
          .animation(.easeInOut(duration: 0.2), value: isFocused)
      )
  }
}

// MARK: - Audio Player Accessibility Helpers


struct PlaybackControlAccessibility: ViewModifier {
  let isPlaying: Bool
  let controlType: PlaybackControlType
  let isEnabled: Bool
  
  enum PlaybackControlType {
    case playPause
    case previous
    case next
    case shuffle
    case `repeat`
    case volume
    
    var label: String {
      switch self {
      case .playPause:
        return "Play pause button"
      case .previous:
        return "Previous track"
      case .next:
        return "Next track"
      case .shuffle:
        return "Shuffle"
      case .repeat:
        return "Repeat"
      case .volume:
        return "Volume"
      }
    }
    
    func hint(isPlaying: Bool, isEnabled: Bool = true) -> String {
      switch self {
      case .playPause:
        return isPlaying ? "Double tap to pause" : "Double tap to play"
      case .previous:
        return isEnabled ? "Double tap to go to previous track" : "No previous track available"
      case .next:
        return isEnabled ? "Double tap to go to next track" : "No next track available"
      case .shuffle:
        return isEnabled ? "Double tap to turn off shuffle" : "Double tap to turn on shuffle"
      case .repeat:
        return "Double tap to change repeat mode"
      case .volume:
        return "Drag to adjust volume"
      }
    }
    
    var traits: AccessibilityTraits {
      switch self {
      case .playPause, .previous, .next:
        return [.isButton, .playsSound]
      case .shuffle, .repeat:
        return [.isButton, .allowsDirectInteraction]
      case .volume:
        return [.allowsDirectInteraction]
      }
    }
  }
  
  func body(content: Content) -> some View {
    content
      .accessibilityLabel(controlType.label)
      .accessibilityHint(controlType.hint(isPlaying: isPlaying, isEnabled: isEnabled))
      .accessibilityAddTraits(controlType.traits)
      .if(!isEnabled) { view in
        view.accessibilityAddTraits(.isStaticText)
      }
      .if(controlType == .playPause) { view in
        view.accessibilityValue(isPlaying ? "Playing" : "Paused")
      }
  }
}

// MARK: - Progress Control Accessibility


struct ProgressControlAccessibility: ViewModifier {
  let progress: Double
  let duration: Double
  let isUserInteracting: Bool
  
  private var progressDescription: String {
    let currentTime = progress * duration
    let currentMinutes = Int(currentTime) / 60
    let currentSeconds = Int(currentTime) % 60
    let totalMinutes = Int(duration) / 60
    let totalSeconds = Int(duration) % 60
    let percentage = Int(progress * 100)
    
    return "\(percentage)% complete. \(currentMinutes):\(String(format: "%02d", currentSeconds)) of \(totalMinutes):\(String(format: "%02d", totalSeconds))"
  }
  
  func body(content: Content) -> some View {
    content
      .accessibilityLabel("Playback progress")
      .accessibilityValue(progressDescription)
      .accessibilityHint("Drag to seek to a different position in the track")
      .accessibilityAddTraits([.allowsDirectInteraction, .updatesFrequently])
      .accessibilityAdjustableAction { direction in
        // Handle increment/decrement for accessibility
        switch direction {
        case .increment:
          // Seek forward 10 seconds
          break
        case .decrement:
          // Seek backward 10 seconds
          break
        @unknown default:
          break
        }
      }
  }
}

// MARK: - Search Accessibility


struct SearchAccessibility: ViewModifier {
  let searchText: String
  let resultCount: Int
  let category: String
  
  private var searchResultsDescription: String {
    if searchText.isEmpty {
      return "Showing all \(category.lowercased())"
    } else {
      return "Search results for '\(searchText)': \(resultCount) \(category.lowercased()) found"
    }
  }
  
  func body(content: Content) -> some View {
    content
      .accessibilityLabel("Search field")
      .accessibilityHint("Type to search your \(category.lowercased())")
      .accessibilityValue(searchText.isEmpty ? "Empty" : searchText)
      .onChange(of: searchText) { _, newValue in
        // Announce search results
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          AccessibilityNotification.Announcement(searchResultsDescription)
            .post()
        }
      }
  }
}

// MARK: - Utility Extensions

extension View {
  @ViewBuilder
  func `if`<Content: View>(
    _ condition: Bool,
    transform: (Self) -> Content
  ) -> some View {
    if condition {
      transform(self)
    } else {
      self
    }
  }
}

// MARK: - Preview Helpers


struct AccessibilityEnhancements_Previews: PreviewProvider {
  static var previews: some View {
    VStack(spacing: 20) {
      // Enhanced button example
      Button("Play") {
        print("Play tapped")
      }
      .enhancedAccessibility(
        label: "Play button",
        hint: "Double tap to start playback",
        traits: [.isButton, .playsSound]
      )
      .assistiveAccessOptimized()
      
      // Audio context example
      VStack {
        Text("Now Playing")
        Text("Moonlight Sonata - Ludwig van Beethoven")
      }
      .audioContextAccessibility(
        isPlaying: true,
        trackTitle: "Moonlight Sonata",
        artist: "Ludwig van Beethoven",
        progress: 0.3,
        duration: 335
      )
      
      // Progress slider example
      Slider(value: .constant(0.3), in: 0...1)
        .modifier(ProgressControlAccessibility(
          progress: 0.3,
          duration: 180,
          isUserInteracting: false
        ))
      
      // Search field example
      TextField("Search", text: .constant("test"))
        .modifier(SearchAccessibility(
          searchText: "test",
          resultCount: 5,
          category: "Tracks"
        ))
    }
    .padding()
    .adaptiveDynamicType()
  }
}