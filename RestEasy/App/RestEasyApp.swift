import FirebaseCore
import SwiftUI
import UIKit

@main
struct RestEasyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var spotService = SpotDataService()
    @StateObject private var locationManager = LocationManager()

    init() {
        FirebaseApp.configure()
        Self.configureOpaqueCreamTabBar()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(spotService)
                .environmentObject(locationManager)
                .dynamicTypeSize(dynamicTypeSize)
                .preferredColorScheme(appState.isHighContrastEnabled ? .dark : nil)
        }
    }

    private var dynamicTypeSize: DynamicTypeSize {
        if appState.textSizeScale >= 1.3 {
            return .xxxLarge
        } else if appState.textSizeScale >= 1.1 {
            return .xLarge
        } else if appState.textSizeScale <= 0.9 {
            return .small
        }
        return .medium
    }

    /// Makes the bottom tab bar solid cream like the map search field (no translucency).
    private static func configureOpaqueCreamTabBar() {
        let creamColor = UIColor(AppTheme.cream)
        let selectedColor = UIColor(AppTheme.forestGreen)
        let unselectedColor = UIColor.black.withAlphaComponent(0.45)

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = creamColor
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.12)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = unselectedColor
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedColor]
        itemAppearance.selected.iconColor = selectedColor
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.isTranslucent = false
    }
}

/// Root shell with a bottom tab bar: Map for discovery, Profile for account.
struct RootView: View {
    var body: some View {
        TabView {
            MapHomeView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .tint(AppTheme.forestGreen)
        .toolbarBackground(AppTheme.cream, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(SpotDataService())
        .environmentObject(LocationManager())
}
