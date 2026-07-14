import FirebaseCore
import SwiftUI

@main
struct RestEasyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var spotService = SpotDataService()
    @StateObject private var locationManager = LocationManager()

    init() {
        FirebaseApp.configure()
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
}

/// Root shell with a bottom tab bar so users can switch Map ↔ Profile.
struct RootView: View {
    init() {
        configureTabBarAppearance()
    }

    var body: some View {
        TabView {
            MapHomeView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(AppTheme.forestGreen)
        .toolbarBackground(AppTheme.cream, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
    }

    /// Styles the tab bar to match the search bar’s cream background.
    private func configureTabBarAppearance() {
        // Same RGB as AppTheme.cream used by the map search bar.
        let barBackground = UIColor(red: 0.95, green: 0.94, blue: 0.89, alpha: 1.0)
        let selectedTint = UIColor(red: 0.24, green: 0.36, blue: 0.24, alpha: 1.0)
        let unselectedTint = selectedTint.withAlphaComponent(0.45)

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = barBackground
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.12)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = unselectedTint
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: unselectedTint
        ]
        itemAppearance.selected.iconColor = selectedTint
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedTint
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = false
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(SpotDataService())
        .environmentObject(LocationManager())
}
