//
//  BottomSearchBar.swift
//  Fonic HiFi
//
//  Created by Claude on 8/14/25.
//  iOS 26+ Bottom Floating Search Bar with Liquid Glass Design
//

import SwiftUI

/// Bottom floating search bar component matching Apple Music iOS 26 design
/// Features Liquid Glass styling with ultraThinMaterial and smooth animations
@MainActor
struct BottomSearchBar: View {
    @Binding var searchText: String
    @FocusState private var isFocused: Bool
    @State private var isInteracting = false
    @State private var glassIntensity: Double = 0.3
    
    // Animation state
    @State private var searchIconRotation: Double = 0
    @State private var searchFieldScale: CGFloat = 1.0
    
    var body: some View {
        if #available(iOS 26, *) {
            enhancedSearchBar
        } else {
            classicSearchBar
        }
    }
    
    // MARK: - iOS 26+ Enhanced Search Bar
    
    
    private var enhancedSearchBar: some View {
        VStack(spacing: 0) {
            // Floating search container
            LiquidGlassCard(style: .ultraThin) {
                HStack(spacing: 12) {
                    // Search icon with animation
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(searchIconRotation))
                        .scaleEffect(isInteracting ? 1.1 : 1.0)
                        .animation(.liquidBouncy, value: isInteracting)
                    
                    // Search text field
                    TextField("Search Tracks", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($isFocused)
                        .submitLabel(.search)
                        .scaleEffect(searchFieldScale)
                        .animation(.liquidSmooth, value: searchFieldScale)
                        .onSubmit {
                            performSearch()
                        }
                    
                    // Clear button when text exists
                    if !searchText.isEmpty {
                        Button(action: clearSearch) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondary.opacity(0.5))
                                .transition(.scale.combined(with: .opacity))
                        }
                        .buttonStyle(.plain)
                        .animation(.liquidSmooth, value: !searchText.isEmpty)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: -2)
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .animation(.liquidMorph, value: isFocused)
        }
        .onChange(of: isFocused) { _, newValue in
            handleFocusChange(newValue)
        }
        .onChange(of: searchText) { _, _ in
            animateSearchIcon()
        }
    }
    
    // MARK: - Classic Search Bar (iOS 25 and below)
    
    private var classicSearchBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                
                TextField("Search Tracks", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
        }
    }
    
    // MARK: - Actions
    
    private func performSearch() {
        // Haptic feedback
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator.impactOccurred()
        
        // Dismiss keyboard
        isFocused = false
        
        // Animation feedback
        if #available(iOS 26, *) {
            withAnimation(.liquidBouncy) {
                searchIconRotation += 360
            }
        }
    }
    
    private func clearSearch() {
        // Haptic feedback
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator.impactOccurred(intensity: 0.7)
        
        // Clear and animation
        withAnimation(.liquidSmooth) {
            searchText = ""
            searchFieldScale = 0.95
        }
        
        // Reset scale
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.liquidSmooth) {
                searchFieldScale = 1.0
            }
        }
    }
    
    
    private func handleFocusChange(_ focused: Bool) {
        isInteracting = focused
        
        // Enhanced haptic feedback
        if focused {
            let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
            impactGenerator.impactOccurred(intensity: 0.8)
        }
        
        // Animate glass intensity
        withAnimation(.liquidMorph) {
            glassIntensity = focused ? 0.5 : 0.3
        }
    }
    
    
    private func animateSearchIcon() {
        // Subtle rotation on text change
        withAnimation(.liquidSmooth) {
            searchIconRotation += 15
        }
        
        // Reset rotation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.liquidSmooth) {
                searchIconRotation = 0
            }
        }
    }
}

// MARK: - Bottom Search Bar Container

/// Container view that properly positions the search bar with safe area handling
@MainActor
struct BottomSearchContainer<Content: View>: View {
    @Binding var searchText: String
    let content: () -> Content
    
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Main content with padding for search bar
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, searchBarHeight + geometry.safeAreaInsets.bottom)
                
                // Floating search bar
                BottomSearchBar(searchText: $searchText)
                    .offset(y: -keyboardHeight)
                    .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: keyboardHeight)
            }
            .ignoresSafeArea(.keyboard)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }
    
    private var searchBarHeight: CGFloat {
        60 // Height of search bar including padding
    }
}

#Preview {
    @Previewable @State var searchText = ""
    
    return ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            BottomSearchBar(searchText: $searchText)
        }
    }
}