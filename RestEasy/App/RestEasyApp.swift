import SwiftUI

@main
struct RestEasyApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var spotService = SpotDataService()
    @StateObject private var locationManager = LocationManager()

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

/// Launches directly into the map; auth is required only for uploads.
struct RootView: View {
    var body: some View {
        MapHomeView()
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(SpotDataService())
        .environmentObject(LocationManager())
}
