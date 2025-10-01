//
//  ContentView.swift
//  CustomGlassTabBar
//
//  Created by Balaji Venkatesh on 28/09/25.
//

import SwiftUI

/// Tab Items!
enum CustomTab: String, CaseIterable {
    case home = "Home"
    case notifications = "Notifications"
    case settings = "Settings"
    
    var symbol: String {
        switch self {
        case .home: return "house"
        case .notifications: return "bell"
        case .settings: return "gearshape"
        }
    }
    
    var actionSymbol: String {
        switch self {
        case .home: return "plus"
        case .notifications: return "tray.full.fill"
        case .settings: return "cloud.moon.fill"
        }
    }
    
    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

struct ContentView: View {
    @State private var activeTab: CustomTab = .home
    var body: some View {
        TabView(selection: $activeTab) {
            Tab.init(value: .home) {
//                ScrollView(.vertical) {
//                    VStack(spacing: 10) {
//                        ForEach(1...20, id: \.self) { _ in
//                            RoundedRectangle(cornerRadius: 15)
//                                .fill(.red.gradient)
//                                .frame(height: 50)
//                        }
//                    }
//                    .padding(15)
//                }
//                /// Add these code to every tab view!
//                .safeAreaBar(edge: .bottom, spacing: 0, content: {
//                    Text(".")
//                        .blendMode(.destinationOut)
//                        /// Tab Bar Height
//                        .frame(height: 55)
//                })
//                .toolbarVisibility(.hidden, for: .tabBar)
                
                Text("Home")
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
            
            Tab.init(value: .notifications) {
                Text("Notification")
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
            
            Tab.init(value: .settings) {
                Text("Settings")
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBarView()
                .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    func CustomTabBarView() -> some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                GeometryReader {
                    /// Type 1
                    CustomTabBar(size: $0.size, barTint: .gray.opacity(0.3), activeTab: $activeTab) { tab in
                        VStack(spacing: 3) {
                            Image(systemName: tab.symbol)
                                .font(.title3)
                            
                            Text(tab.rawValue)
                                .font(.system(size: 10))
                                .fontWeight(.medium)
                        }
                        .symbolVariant(.fill)
                        .frame(maxWidth: .infinity)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                    
                    /// Type 2
//                        CustomTabBar2(size: $0.size, activeTab: $activeTab)
//                            .overlay {
//                                HStack(spacing: 0) {
//                                    ForEach(CustomTab.allCases, id: \.rawValue) { tab in
//                                        VStack(spacing: 3) {
//                                            Image(systemName: tab.symbol)
//                                                .font(.title3)
//
//                                            Text(tab.rawValue)
//                                                .font(.system(size: 10))
//                                                .fontWeight(.medium)
//                                        }
//                                        .symbolVariant(.fill)
//                                        .foregroundStyle(activeTab == tab ? Color.primary : Color.primary.opacity(0.5))
//                                        .frame(maxWidth: .infinity)
//                                    }
//                                }
//                                .animation(.easeInOut(duration: 0.25), value: activeTab)
//                            }
//                            .glassEffect(.regular.interactive(), in: .capsule)
                }
                
                ZStack {
                    ForEach(CustomTab.allCases, id: \.rawValue) { tab in
                        Image(systemName: tab.actionSymbol)
                            .font(.system(size: 22, weight: .medium))
                            .blurFade(activeTab == tab)
                    }
                }
                .frame(width: 55, height: 55)
                .glassEffect(.regular.interactive(), in: .capsule)
                .animation(.smooth(duration: 0.55, extraBounce: 0), value: activeTab)
            }
        }
        .frame(height: 55)
    }
}

/// Blur Fade In/Out
extension View {
    @ViewBuilder
    func blurFade(_ status: Bool) -> some View {
        self
            .compositingGroup()
            .blur(radius: status ? 0 : 10)
            .opacity(status ? 1 : 0)
    }
}

#Preview {
    ContentView()
}
