import SwiftUI
import MapKit
import Combine
import UIKit

/// Main map screen for discovering and navigating to resting spots.
struct MapHomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var spotService: SpotDataService
    @EnvironmentObject private var locationManager: LocationManager
    @StateObject private var mapSearchService = MapSearchService()
    @StateObject private var directionsService = DirectionsService()

    @State private var searchText = ""
    @State private var selectedFeatureFilters: Set<SpotFeature> = []
    @State private var selectedSpot: RestingSpot?
    @State private var showUploadSheet = false
    @State private var spotPendingReview: RestingSpot?
    @State private var showAuthSheet = false
    @State private var pendingUploadAfterAuth = false
    @State private var pendingReviewAfterAuth = false
    @State private var showSettings = false
    @State private var showMapSizeSheet = false
    @State private var cameraPosition: MapCameraPosition = .region(AppConstants.defaultMapRegion)
    @State private var mapFocusCenter: CLLocationCoordinate2D?
    @State private var isSearchingArea = false
    @State private var isNavigating = false
    @State private var isLiveGuidance = false
    @FocusState private var isSearchFieldFocused: Bool

    /// Origin used for routing: live GPS when available, otherwise Chicago.
    private var routeOrigin: CLLocationCoordinate2D {
        locationManager.userLocation
    }

    private var isUsingFallbackOrigin: Bool {
        locationManager.isApproximateLocation
    }

    private var activeMapCenter: CLLocationCoordinate2D {
        mapFocusCenter ?? locationManager.userLocation
    }

    private var visibleSpots: [RestingSpot] {
        spotService.spotsNear(
            activeMapCenter,
            requiredFeatures: selectedFeatureFilters
        )
    }

    private var matchingSpotSuggestions: [RestingSpot] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSearchFieldFocused, !trimmedQuery.isEmpty else { return [] }
        return Array(
            spotService.spotsNear(
                activeMapCenter,
                requiredFeatures: selectedFeatureFilters,
                query: trimmedQuery
            ).prefix(5)
        )
    }

    private var matchingFeatureSuggestions: [SpotFeature] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSearchFieldFocused, !trimmedQuery.isEmpty else { return [] }
        return SpotFeature.features(matching: trimmedQuery)
            .filter { !selectedFeatureFilters.contains($0) }
    }

    private var shouldShowSearchSuggestions: Bool {
        isSearchFieldFocused &&
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (
            !mapSearchService.completions.isEmpty ||
            !matchingSpotSuggestions.isEmpty ||
            !matchingFeatureSuggestions.isEmpty
        )
    }

    private var mapSpan: MKCoordinateSpan {
        let delta = AppConstants.mapSpanDelta(for: appState.mapZoomLevel)
        return MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
    }

    private let zoomStep = 0.1

    private var canZoomIn: Bool {
        appState.mapZoomLevel < AppConstants.mapZoomRange.upperBound
    }

    private var canZoomOut: Bool {
        appState.mapZoomLevel > AppConstants.mapZoomRange.lowerBound
    }

    var body: some View {
        ZStack {
            AppTheme.forestGreen.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    searchBar

                    featureFilterChips

                    if shouldShowSearchSuggestions {
                        searchSuggestionsList
                    }

                    if let searchError = mapSearchService.searchError {
                        Text(searchError)
                            .font(.caption)
                            .foregroundStyle(AppTheme.cream.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                    }

                    if !selectedFeatureFilters.isEmpty && visibleSpots.isEmpty {
                        Text("No resting spots match those filters nearby.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.cream.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .zIndex(1)

                mapSection
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if let spot = selectedSpot {
                    if isLiveGuidance {
                        liveGuidancePanel(for: spot)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if isNavigating {
                        activeNavigationPanel(for: spot)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        spotDetailPanels(for: spot)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // Leaves a clear band above the root tab bar so the map is cropped short.
                Spacer(minLength: 12)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if !isNavigating && !isLiveGuidance {
                        addButton
                    }
                }
                .padding(.trailing, 24)
                .padding(.bottom, selectedSpot == nil || isNavigating || isLiveGuidance ? 24 : 16)
            }
        }
        .sheet(isPresented: $showUploadSheet) {
            UploadSpotView()
        }
        .sheet(item: $spotPendingReview, onDismiss: {
            refreshSelectedSpotFromService()
        }) { spot in
            AddReviewView(spot: spot)
        }
        .fullScreenCover(isPresented: $showAuthSheet, onDismiss: {
            if !appState.isAuthenticated {
                pendingUploadAfterAuth = false
                pendingReviewAfterAuth = false
            }
        }) {
            WelcomeView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showMapSizeSheet) {
            MapSizeSheet(cameraPosition: $cameraPosition)
        }
        .onAppear {
            locationManager.requestLocation()
            updateSearchRegion()
            updateCamera()
        }
        .onReceive(locationManager.$userLocation) { _ in
            if isLiveGuidance {
                handleLiveLocationUpdate()
            } else {
                recenterOnUserIfNeeded()
            }
        }
        .onReceive(locationManager.$headingDegrees) { _ in
            guard isLiveGuidance else { return }
            updateFollowCamera()
        }
        .onChange(of: appState.mapZoomLevel) { _, _ in
            guard !isLiveGuidance else { return }
            updateCamera()
        }
        .onChange(of: searchText) { _, newValue in
            mapSearchService.updateQuery(newValue)
            updateSearchRegion()

            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                clearSearchAndSelection()
            }
        }
        .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
            guard isAuthenticated else { return }

            if pendingUploadAfterAuth {
                pendingUploadAfterAuth = false
                showUploadSheet = true
            } else if pendingReviewAfterAuth {
                pendingReviewAfterAuth = false
                spotPendingReview = selectedSpot
            }
        }
        .onChange(of: selectedSpot) { _, spot in
            if spot == nil {
                endAllNavigation()
            }
            guard !isLiveGuidance else { return }
            Task { await refreshDirections(for: spot) }
        }
        .onChange(of: directionsService.travelMode) { _, _ in
            guard !isLiveGuidance else { return }
            Task { await refreshDirections(for: selectedSpot) }
        }
        .onChange(of: locationManager.isApproximateLocation) { _, isApproximate in
            guard !isApproximate, selectedSpot != nil, !isLiveGuidance else { return }
            Task { await refreshDirections(for: selectedSpot) }
        }
    }

    /// Recenters the map on the user when they have not manually moved the focus.
    private func recenterOnUserIfNeeded() {
        guard mapFocusCenter == nil, !isNavigating, !isLiveGuidance else { return }
        updateSearchRegion()
        updateCamera()
    }

    /// Clears search text side effects and restores the default map focus.
    private func clearSearchAndSelection() {
        mapFocusCenter = nil
        selectedSpot = nil
        endAllNavigation()
        directionsService.clear()
        mapSearchService.clearCompletions()
        updateCamera()
    }

    /// Clears amenity filters and restores the unfiltered nearby map.
    private func clearFeatureFilters() {
        selectedFeatureFilters.removeAll()
    }

    /// Leaves both route-review and live-guidance modes.
    private func endAllNavigation() {
        isNavigating = false
        isLiveGuidance = false
        locationManager.stopHeadingUpdates()
        directionsService.clearLiveProgressOnly()
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.inputPlaceholder)

            TextField("", text: $searchText, prompt: Text("Search area, bench, restroom…")
                .foregroundStyle(AppTheme.inputPlaceholder))
                .foregroundStyle(AppTheme.inputText)
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .onSubmit {
                    Task { await performExpandedSearch() }
                }

            if isSearchingArea {
                ProgressView()
                    .tint(AppTheme.inputPlaceholder)
            } else if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.inputPlaceholder)
                }
            }

            Button {
                isSearchFieldFocused = false
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(AppTheme.inputPlaceholder)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.cream)
        .clipShape(Capsule())
        .colorScheme(.light)
    }

    /// Horizontal amenity chips so users can filter spots by tagged needs.
    private var featureFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SpotFeature.allCases) { feature in
                    let isSelected = selectedFeatureFilters.contains(feature)
                    Button {
                        toggleFeatureFilter(feature)
                    } label: {
                        Label(feature.rawValue, systemImage: feature.systemImage)
                            // Preference Search button size — change font and padding here
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? AppTheme.forestGreen : .black.opacity(0.75))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(isSelected ? AppTheme.cream : AppTheme.cream.opacity(0.55))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? AppTheme.sageGreen : Color.clear, lineWidth: 1.5)
                            )
                    }
                    .accessibilityLabel("\(feature.rawValue) filter")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }

                if !selectedFeatureFilters.isEmpty {
                    Button {
                        clearFeatureFilters()
                    } label: {
                        Text("Clear")
                            // Clear chip size — keep in sync with the filter chips above
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(AppTheme.cream.opacity(0.4))
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel("Clear amenity filters")
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var searchSuggestionsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !matchingFeatureSuggestions.isEmpty {
                    suggestionSectionHeader("Amenities")
                    ForEach(matchingFeatureSuggestions) { feature in
                        Button {
                            applyFeatureSuggestion(feature)
                        } label: {
                            suggestionRow(
                                title: feature.rawValue,
                                subtitle: "Filter resting spots tagged \(feature.rawValue.lowercased())",
                                systemImage: feature.systemImage
                            )
                        }
                        Divider().padding(.leading, 16)
                    }
                }

                if !matchingSpotSuggestions.isEmpty {
                    suggestionSectionHeader("Resting Spots")
                    ForEach(matchingSpotSuggestions) { spot in
                        Button {
                            selectSpotSuggestion(spot)
                        } label: {
                            suggestionRow(
                                title: spot.name,
                                subtitle: spotFeatureSummary(for: spot),
                                systemImage: "mappin.circle.fill"
                            )
                        }
                        Divider().padding(.leading, 16)
                    }
                }

                if !mapSearchService.completions.isEmpty {
                    suggestionSectionHeader("Areas")
                    ForEach(Array(mapSearchService.completions.enumerated()), id: \.offset) { _, completion in
                        Button {
                            Task { await selectSearchCompletion(completion) }
                        } label: {
                            suggestionRow(
                                title: completion.title,
                                subtitle: completion.subtitle.isEmpty ? "Map area" : completion.subtitle,
                                systemImage: "map"
                            )
                        }
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
        .frame(maxHeight: 260)
        .background(AppTheme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }

    /// Section label inside the combined search suggestions dropdown.
    /// - Parameter title: The section name to display.
    /// - Returns: A small header view for grouping suggestions.
    private func suggestionSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.black.opacity(0.45))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }

    /// A single row in the search suggestions list.
    /// - Parameters:
    ///   - title: Primary suggestion text.
    ///   - subtitle: Supporting detail under the title.
    ///   - systemImage: Leading SF Symbol name.
    /// - Returns: A styled suggestion row.
    private func suggestionRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.forestGreen)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.black.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// Short amenity summary used under spot search suggestions.
    /// - Parameter spot: The resting spot being suggested.
    /// - Returns: A comma-separated feature list or a fallback address.
    private func spotFeatureSummary(for spot: RestingSpot) -> String {
        if spot.features.isEmpty {
            return spot.address
        }
        return spot.features.map(\.rawValue).joined(separator: " · ")
    }

    /// Toggles an amenity chip on or off in the active filter set.
    /// - Parameter feature: The amenity tag to toggle.
    private func toggleFeatureFilter(_ feature: SpotFeature) {
        if selectedFeatureFilters.contains(feature) {
            selectedFeatureFilters.remove(feature)
        } else {
            selectedFeatureFilters.insert(feature)
        }

        if let selectedSpot, !visibleSpots.contains(where: { $0.id == selectedSpot.id }) {
            self.selectedSpot = nil
            endAllNavigation()
            directionsService.clear()
        }
    }

    /// Applies an amenity suggestion as an active filter chip.
    /// - Parameter feature: The amenity chosen from search suggestions.
    private func applyFeatureSuggestion(_ feature: SpotFeature) {
        selectedFeatureFilters.insert(feature)
        searchText = feature.rawValue
        isSearchFieldFocused = false
        mapSearchService.clearCompletions()
    }

    /// Selects a resting spot from search suggestions and centers the map on it.
    /// - Parameter spot: The suggested resting spot.
    private func selectSpotSuggestion(_ spot: RestingSpot) {
        searchText = spot.name
        isSearchFieldFocused = false
        mapSearchService.clearCompletions()
        selectedSpot = spot
        moveCamera(
            to: MKCoordinateRegion(
                center: spot.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
    }

    private var mapSection: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $cameraPosition, selection: $selectedSpot) {
                ForEach(visibleSpots) { spot in
                    Marker(spot.name, coordinate: spot.coordinate)
                        .tint(AppTheme.forestGreen)
                        .tag(spot)
                }

                if let routeCoordinates = directionsService.route?.coordinates,
                   routeCoordinates.count >= 2 {
                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(AppTheme.accentBlue, lineWidth: 5)
                }

                userLocationMarker
            }
            .mapStyle(.standard(elevation: .realistic))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(maxHeight: selectedSpot == nil || isNavigating || isLiveGuidance ? .infinity : 220)
            .animation(.easeInOut(duration: 0.3), value: selectedSpot?.id)
            .animation(.easeInOut(duration: 0.3), value: isNavigating)
            .animation(.easeInOut(duration: 0.3), value: isLiveGuidance)
            .onTapGesture(count: 2) {
                showMapSizeSheet = true
            }

            zoomControls
                .padding(12)
        }
    }

    /// Blue "you are here" pin; rotates with compass heading during live guidance.
    @MapContentBuilder
    private var userLocationMarker: some MapContent {
        Annotation("You", coordinate: locationManager.userLocation) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                Image(systemName: isLiveGuidance ? "location.north.fill" : "circle.fill")
                    .font(isLiveGuidance ? .body : .caption)
                    .foregroundStyle(AppTheme.accentBlue)
                    .rotationEffect(.degrees(isLiveGuidance ? (locationManager.headingDegrees ?? 0) : 0))
            }
            .accessibilityLabel(
                locationManager.isApproximateLocation
                ? "Your location, Chicago default"
                : "Your current location"
            )
        }
    }

    private var zoomControls: some View {
        VStack(spacing: 8) {
            zoomButton(
                systemName: "plus",
                accessibilityLabel: "Zoom in",
                isEnabled: canZoomIn
            ) {
                adjustZoom(by: zoomStep)
            }

            zoomButton(
                systemName: "minus",
                accessibilityLabel: "Zoom out",
                isEnabled: canZoomOut
            ) {
                adjustZoom(by: -zoomStep)
            }
        }
    }

    private func zoomButton(
        systemName: String,
        accessibilityLabel: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.bold())
                .foregroundStyle(isEnabled ? .black : .black.opacity(0.35))
                .frame(width: 40, height: 40)
                .background(AppTheme.cream)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
        }
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private func spotDetailPanels(for spot: RestingSpot) -> some View {
        VStack(spacing: 8) {
            infoPanel(for: spot)
            reviewsPanel(for: spot)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func infoPanel(for spot: RestingSpot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(spot.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    selectedSpot = nil
                    endAllNavigation()
                    directionsService.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            if !spot.imageURLs.isEmpty {
                remoteSpotPhotoGallery(for: spot)
            } else {
                seedSpotPhotoGallery(for: spot)
            }

            // Spot address text size — change `.body` here to adjust
            Text(spot.address)
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))

            // Spot directions text size — change `.subheadline` here to adjust
            if let directions = spot.directions {
                Text(directions)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack {
                Label(String(format: "%.1f", spot.averageRating), systemImage: "star.fill")
                    .foregroundStyle(.yellow)
                Text("(\(spot.reviewCount) reviews)")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.caption)
            }

            FlowLayout(spacing: 6) {
                ForEach(spot.features) { feature in
                    Text(feature.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.cream.opacity(0.2))
                        .clipShape(Capsule())
                        .foregroundStyle(.white)
                }
            }

            directionsSection(for: spot)
        }
        .padding(16)
        .background(AppTheme.forestGreen.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.sageGreen, lineWidth: 1)
        )
    }

    /// Swipeable gallery for Firebase Storage photos on user-uploaded spots.
    /// - Parameter spot: The resting spot whose `imageURLs` should be shown.
    /// - Returns: A paging gallery, or an empty view when no remote photos exist.
    @ViewBuilder
    private func remoteSpotPhotoGallery(for spot: RestingSpot) -> some View {
        let validURLs = spot.imageURLs.compactMap(URL.init(string:))

        if validURLs.isEmpty {
            EmptyView()
        } else if validURLs.count == 1, let url = validURLs.first {
            remoteSpotPhoto(url: url, spotName: spot.name)
        } else {
            TabView {
                ForEach(validURLs, id: \.absoluteString) { url in
                    remoteSpotPhoto(url: url, spotName: spot.name)
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
    }

    /// Single remote spot photo loaded from Firebase Storage.
    /// - Parameters:
    ///   - url: The image download URL.
    ///   - spotName: The resting spot name used for accessibility.
    /// - Returns: A styled remote image view.
    private func remoteSpotPhoto(url: URL, spotName: String) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.5))
            default:
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Photo of \(spotName)")
    }

    /// Swipeable gallery for asset-catalog photos listed on a seed spot.
    /// - Parameter spot: The resting spot whose `imageNames` should be shown.
    /// - Returns: A paging gallery, or an empty view when no assets are available.
    @ViewBuilder
    private func seedSpotPhotoGallery(for spot: RestingSpot) -> some View {
        let availableImageNames = spot.imageNames.filter { UIImage(named: $0) != nil }

        if availableImageNames.isEmpty {
            EmptyView()
        } else if availableImageNames.count == 1, let imageName = availableImageNames.first {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Photo of \(spot.name)")
        } else {
            TabView {
                ForEach(availableImageNames, id: \.self) { imageName in
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .clipped()
                        .accessibilityLabel("Photo of \(spot.name)")
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
    }

    /// Shows travel mode, ETA, and in-app navigation controls for a selected spot.
    /// - Parameter spot: The resting spot currently selected on the map.
    /// - Returns: The directions controls shown in the spot detail panel.
    @ViewBuilder
    private func directionsSection(for spot: RestingSpot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Directions")
                .font(.subheadline.bold())
                .foregroundStyle(.white)

            Picker("Travel mode", selection: $directionsService.travelMode) {
                ForEach(TravelMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Travel mode")

            if directionsService.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("Calculating route…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
            } else if let route = directionsService.route {
                HStack(spacing: 16) {
                    Label(route.formattedETA, systemImage: "clock.fill")
                    Label(route.formattedDistance, systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.cream)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Estimated time \(route.formattedETA), distance \(route.formattedDistance)")

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isNavigating = true
                        isLiveGuidance = false
                    }
                    fitCamera(to: route.coordinates, destination: spot.coordinate)
                } label: {
                    Label("Review Route", systemImage: "list.bullet")
                        .font(.subheadline.bold())
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.cream)
                        .clipShape(Capsule())
                }
                .accessibilityHint("Shows the full path, ETA, and turn list before you start walking")
            } else if let errorMessage = directionsService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    /// Route-review panel: full path overview, ETA, and step list before confirming the trip.
    /// - Parameter spot: The destination resting spot.
    /// - Returns: The review UI shown after tapping Review Route.
    private func activeNavigationPanel(for spot: RestingSpot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Route to")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Text(spot.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isNavigating = false
                    }
                } label: {
                    Text("Back")
                        .font(.subheadline.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.cream)
                        .clipShape(Capsule())
                }
                .accessibilityLabel("Back to spot details")
            }

            if let route = directionsService.route {
                HStack(spacing: 16) {
                    Label(route.formattedETA, systemImage: "clock.fill")
                    Label(route.formattedDistance, systemImage: directionsService.travelMode.systemImage)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.cream)

                if route.steps.isEmpty {
                    Text("Follow the blue route on the map to reach this spot.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(route.steps.enumerated()), id: \.element.id) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.black)
                                        .frame(width: 22, height: 22)
                                        .background(AppTheme.cream)
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(step.instruction)
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                        Text(step.formattedDistance)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 140)
                }

                Button {
                    beginLiveGuidance(to: spot)
                } label: {
                    Label("Confirm & Go", systemImage: "location.north.line.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.cream)
                        .clipShape(Capsule())
                }
                .accessibilityHint("Starts live guidance that follows you along the route")
            } else if directionsService.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("Updating directions…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .padding(16)
        .background(AppTheme.forestGreen.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.sageGreen, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// Live guidance panel with the next-turn banner after the user confirms the trip.
    /// - Parameter spot: The destination resting spot.
    /// - Returns: The compact live-navigation UI.
    private func liveGuidancePanel(for spot: RestingSpot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Going to")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Text(spot.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
                Button {
                    endLiveGuidance(returnToReview: true)
                } label: {
                    Text("End")
                        .font(.subheadline.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.cream)
                        .clipShape(Capsule())
                }
                .accessibilityLabel("End live navigation")
            }

            if directionsService.isRerouting {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("Recalculating route…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
            } else if let progress = directionsService.liveProgress {
                Text(progress.bannerText)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.cream)
                    .accessibilityLabel(progress.bannerText)

                HStack(spacing: 16) {
                    Label(progress.formattedRemainingETA, systemImage: "clock.fill")
                    Label(
                        RouteStep.formatDistance(progress.remainingDistanceMeters),
                        systemImage: directionsService.travelMode.systemImage
                    )
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            } else if let route = directionsService.route {
                Text("Follow the blue route to \(spot.name).")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.cream)
                Label(route.formattedETA, systemImage: "clock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            if isUsingFallbackOrigin {
                Text("Live GPS follow works best on a real device with location allowed.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(16)
        .background(AppTheme.forestGreen.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.sageGreen, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func reviewsPanel(for spot: RestingSpot) -> some View {
        let spotReviews = spotService.reviews(for: spot.id)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Reviews and Ratings")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    handleAddReviewTap()
                } label: {
                    Label("Add", systemImage: "square.and.pencil")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.cream)
                        .clipShape(Capsule())
                }
                .accessibilityLabel("Add a review")
            }

            if spotReviews.isEmpty {
                Text("No reviews yet. Be the first!")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                ForEach(spotReviews.prefix(5)) { review in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(review.authorName)
                                .font(.caption.bold())
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= review.rating ? "star.fill" : "star")
                                        .font(.caption2)
                                        .foregroundStyle(.yellow)
                                }
                            }
                        }
                        Text(review.comment)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.sageGreen)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var addButton: some View {
        Button {
            handleUploadTap()
        } label: {
            Text("Add Spot")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.cream)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color(red: 61 / 255, green: 95 / 255, blue: 61 / 255))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
        .accessibilityLabel("Add Spot")
    }

    private func handleUploadTap() {
        if appState.isAuthenticated {
            showUploadSheet = true
        } else {
            pendingUploadAfterAuth = true
            showAuthSheet = true
        }
    }

    /// Opens the add-review sheet, prompting login first when the user is a guest.
    private func handleAddReviewTap() {
        if appState.isAuthenticated {
            spotPendingReview = selectedSpot
        } else {
            pendingReviewAfterAuth = true
            showAuthSheet = true
        }
    }

    /// Refreshes the selected spot so updated ratings appear after a new review.
    private func refreshSelectedSpotFromService() {
        guard let selectedID = selectedSpot?.id,
              let updatedSpot = spotService.spots.first(where: { $0.id == selectedID }) else {
            return
        }
        selectedSpot = updatedSpot
    }

    private func updateSearchRegion() {
        mapSearchService.updateSearchRegion(
            MKCoordinateRegion(center: activeMapCenter, span: mapSpan)
        )
    }

    private func updateCamera() {
        cameraPosition = .region(MKCoordinateRegion(center: activeMapCenter, span: mapSpan))
    }

    /// Adjusts the map zoom level and recenters on the active map area.
    /// - Parameter delta: Positive values zoom in; negative values zoom out.
    private func adjustZoom(by delta: Double) {
        let newLevel = min(
            AppConstants.mapZoomRange.upperBound,
            max(AppConstants.mapZoomRange.lowerBound, appState.mapZoomLevel + delta)
        )
        guard newLevel != appState.mapZoomLevel else { return }
        appState.mapZoomLevel = newLevel
    }

    private func moveCamera(to region: MKCoordinateRegion) {
        mapFocusCenter = region.center
        cameraPosition = .region(region)
        updateSearchRegion()
    }

    private func performExpandedSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isSearchFieldFocused = false
        mapSearchService.clearCompletions()

        let matchingFeatures = SpotFeature.features(matching: query)
        if let firstFeature = matchingFeatures.first {
            selectedFeatureFilters.insert(firstFeature)
        }

        let matchingSpots = spotService.spotsNear(
            activeMapCenter,
            requiredFeatures: selectedFeatureFilters,
            query: query
        )

        if let firstSpot = matchingSpots.first, matchingFeatures.isEmpty == false || matchingSpots.count == 1 {
            selectedSpot = firstSpot
            moveCamera(
                to: MKCoordinateRegion(
                    center: firstSpot.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            )
            return
        }

        if !matchingSpots.isEmpty {
            let center = matchingSpots[0].coordinate
            moveCamera(
                to: MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                )
            )
            return
        }

        isSearchingArea = true
        defer { isSearchingArea = false }

        if let region = await mapSearchService.region(for: query, near: routeOrigin) {
            selectedSpot = nil
            moveCamera(to: region)
        }
    }

    private func selectSearchCompletion(_ completion: MKLocalSearchCompletion) async {
        searchText = completion.title
        isSearchFieldFocused = false
        isSearchingArea = true
        mapSearchService.clearCompletions()
        defer { isSearchingArea = false }

        if let region = await mapSearchService.region(for: completion, near: routeOrigin) {
            selectedSpot = nil
            moveCamera(to: region)
        }
    }

    /// Requests an in-app route and ETA for the selected resting spot.
    /// - Parameter spot: The spot to navigate to, or `nil` to clear directions.
    private func refreshDirections(for spot: RestingSpot?) async {
        guard let spot else {
            directionsService.clear()
            return
        }

        await directionsService.calculateRoute(from: routeOrigin, to: spot.coordinate)

        if let route = directionsService.route, !isLiveGuidance {
            fitCamera(to: route.coordinates, destination: spot.coordinate)
        }
    }

    /// Starts live follow-mode guidance after the user confirms the reviewed route.
    /// - Parameter spot: The destination resting spot.
    private func beginLiveGuidance(to spot: RestingSpot) {
        withAnimation(.easeInOut(duration: 0.3)) {
            isLiveGuidance = true
            isNavigating = true
        }
        locationManager.startHeadingUpdates()
        directionsService.updateLiveProgress(at: locationManager.userLocation)
        updateFollowCamera()
    }

    /// Ends live guidance and optionally returns to the route-review panel.
    /// - Parameter returnToReview: When `true`, keeps the reviewed route visible.
    private func endLiveGuidance(returnToReview: Bool) {
        locationManager.stopHeadingUpdates()
        directionsService.clearLiveProgressOnly()
        withAnimation(.easeInOut(duration: 0.3)) {
            isLiveGuidance = false
            isNavigating = returnToReview
        }

        if returnToReview, let route = directionsService.route, let spot = selectedSpot {
            fitCamera(to: route.coordinates, destination: spot.coordinate)
        }
    }

    /// Updates step progress, follow camera, and reroutes when the user leaves the path.
    private func handleLiveLocationUpdate() {
        guard isLiveGuidance, let spot = selectedSpot else { return }

        directionsService.updateLiveProgress(at: locationManager.userLocation)
        updateFollowCamera()

        guard directionsService.isOffRoute(at: locationManager.userLocation),
              directionsService.canRerouteNow() else { return }

        Task {
            await directionsService.calculateRoute(
                from: locationManager.userLocation,
                to: spot.coordinate,
                isReroute: true
            )
            directionsService.updateLiveProgress(at: locationManager.userLocation)
            updateFollowCamera()
        }
    }

    /// Zooms the camera onto the user and rotates with heading during live guidance.
    private func updateFollowCamera() {
        guard isLiveGuidance else { return }

        let heading = locationManager.headingDegrees ?? 0
        cameraPosition = .camera(
            MapCamera(
                centerCoordinate: locationManager.userLocation,
                distance: AppConstants.liveNavigationCameraDistance,
                heading: heading,
                pitch: 50
            )
        )
        mapFocusCenter = locationManager.userLocation
        updateSearchRegion()
    }

    /// Zooms the map so the full route from the user to the spot is visible.
    /// - Parameters:
    ///   - coordinates: The route polyline coordinates.
    ///   - destination: The resting spot coordinate used as a fallback endpoint.
    private func fitCamera(
        to coordinates: [CLLocationCoordinate2D],
        destination: CLLocationCoordinate2D
    ) {
        var points = coordinates
        points.append(routeOrigin)
        points.append(destination)

        guard let firstPoint = points.first else { return }

        var minLatitude = firstPoint.latitude
        var maxLatitude = firstPoint.latitude
        var minLongitude = firstPoint.longitude
        var maxLongitude = firstPoint.longitude

        for point in points.dropFirst() {
            minLatitude = min(minLatitude, point.latitude)
            maxLatitude = max(maxLatitude, point.latitude)
            minLongitude = min(minLongitude, point.longitude)
            maxLongitude = max(maxLongitude, point.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLatitude - minLatitude) * 1.4, 0.005),
            longitudeDelta: max((maxLongitude - minLongitude) * 1.4, 0.005)
        )

        mapFocusCenter = center
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        updateSearchRegion()
    }
}

/// Simple flow layout for feature tags.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

#Preview {
    MapHomeView()
        .environmentObject(AppState())
        .environmentObject(SpotDataService())
        .environmentObject(LocationManager())
}
