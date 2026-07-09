import SwiftUI
import MapKit
import Combine

/// Main map screen for discovering and navigating to resting spots.
struct MapHomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var spotService: SpotDataService
    @EnvironmentObject private var locationManager: LocationManager
    @StateObject private var mapSearchService = MapSearchService()

    @State private var searchText = ""
    @State private var selectedSpot: RestingSpot?
    @State private var showUploadSheet = false
    @State private var showAuthSheet = false
    @State private var pendingUploadAfterAuth = false
    @State private var showSettings = false
    @State private var showMapSizeSheet = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var mapFocusCenter: CLLocationCoordinate2D?
    @State private var isSearchingArea = false
    @FocusState private var isSearchFieldFocused: Bool

    private var activeMapCenter: CLLocationCoordinate2D {
        mapFocusCenter ?? locationManager.userLocation ?? AppConstants.defaultMapCenter
    }

    private var visibleSpots: [RestingSpot] {
        spotService.spotsNear(activeMapCenter)
    }

    private var shouldShowSearchSuggestions: Bool {
        isSearchFieldFocused &&
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !mapSearchService.completions.isEmpty
    }

    private var mapSpan: MKCoordinateSpan {
        let delta = 0.15 - (appState.mapZoomLevel * 0.12)
        return MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
    }

    var body: some View {
        ZStack {
            AppTheme.forestGreen.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    searchBar

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
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .zIndex(1)

                mapSection
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                if let spot = selectedSpot {
                    spotDetailPanels(for: spot)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 0)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addButton
                }
                .padding(.trailing, 24)
                .padding(.bottom, selectedSpot == nil ? 32 : 16)
            }
        }
        .sheet(isPresented: $showUploadSheet) {
            UploadSpotView()
        }
        .fullScreenCover(isPresented: $showAuthSheet, onDismiss: {
            if !appState.isAuthenticated {
                pendingUploadAfterAuth = false
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
            guard mapFocusCenter == nil else { return }
            updateSearchRegion()
            updateCamera()
        }
        .onChange(of: appState.mapZoomLevel) { _, _ in
            updateCamera()
        }
        .onChange(of: searchText) { _, newValue in
            mapSearchService.updateQuery(newValue)
            updateSearchRegion()

            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                mapFocusCenter = nil
                selectedSpot = nil
                mapSearchService.clearCompletions()
                updateCamera()
            }
        }
        .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
            guard isAuthenticated, pendingUploadAfterAuth else { return }
            pendingUploadAfterAuth = false
            showUploadSheet = true
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.black.opacity(0.6))

            TextField("Search an Area", text: $searchText)
                .foregroundStyle(.black)
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .onSubmit {
                    Task { await performAreaSearch() }
                }

            if isSearchingArea {
                ProgressView()
                    .tint(.black.opacity(0.6))
            } else if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.black.opacity(0.45))
                }
            }

            Button {
                isSearchFieldFocused = false
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.black.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.cream)
        .clipShape(Capsule())
    }

    private var searchSuggestionsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(mapSearchService.completions.enumerated()), id: \.offset) { _, completion in
                    Button {
                        Task { await selectSearchCompletion(completion) }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(completion.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.black)
                            if !completion.subtitle.isEmpty {
                                Text(completion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.black.opacity(0.6))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .frame(maxHeight: 220)
        .background(AppTheme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }

    private var mapSection: some View {
        Map(position: $cameraPosition, selection: $selectedSpot) {
            ForEach(visibleSpots) { spot in
                Marker(spot.name, coordinate: spot.coordinate)
                    .tint(AppTheme.forestGreen)
                    .tag(spot)
            }
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .realistic))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxHeight: selectedSpot == nil ? .infinity : 220)
        .animation(.easeInOut(duration: 0.3), value: selectedSpot?.id)
        .onTapGesture(count: 2) {
            showMapSizeSheet = true
        }
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
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Text(spot.address)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            if let directions = spot.directions {
                Text(directions)
                    .font(.caption)
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

            Button {
                openNavigation(to: spot)
            } label: {
                Label("Navigate", systemImage: "location.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.cream)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(AppTheme.forestGreen.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.sageGreen, lineWidth: 1)
        )
    }

    private func reviewsPanel(for spot: RestingSpot) -> some View {
        let spotReviews = spotService.reviews(for: spot.id)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Reviews and Ratings")
                .font(.headline)
                .foregroundStyle(.white)

            if spotReviews.isEmpty {
                Text("No reviews yet. Be the first!")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                ForEach(spotReviews.prefix(2)) { review in
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
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.black)
                .frame(width: 56, height: 56)
                .background(AppTheme.cream)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
    }

    private func handleUploadTap() {
        if appState.isAuthenticated {
            showUploadSheet = true
        } else {
            pendingUploadAfterAuth = true
            showAuthSheet = true
        }
    }

    private func updateSearchRegion() {
        mapSearchService.updateSearchRegion(
            MKCoordinateRegion(center: activeMapCenter, span: mapSpan)
        )
    }

    private func updateCamera() {
        cameraPosition = .region(MKCoordinateRegion(center: activeMapCenter, span: mapSpan))
    }

    private func moveCamera(to region: MKCoordinateRegion) {
        mapFocusCenter = region.center
        cameraPosition = .region(region)
        updateSearchRegion()
    }

    private func performAreaSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isSearchingArea = true
        isSearchFieldFocused = false
        mapSearchService.clearCompletions()
        defer { isSearchingArea = false }

        if let region = await mapSearchService.region(for: query) {
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

        if let region = await mapSearchService.region(for: completion) {
            selectedSpot = nil
            moveCamera(to: region)
        }
    }

    private func openNavigation(to spot: RestingSpot) {
        spot.mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
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
