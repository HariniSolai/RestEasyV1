import SwiftUI
import MapKit
import PhotosUI
import UIKit

/// Form for users to contribute a new resting spot.
struct UploadSpotView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var spotService: SpotDataService
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var mapSearchService = MapSearchService()

    @State private var address = ""
    @State private var directions = ""
    @State private var selectedFeatures: Set<SpotFeature> = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [Image] = []
    @State private var selectedImagesData: [Data] = []
    private let maxPhotoCount = 5
    @State private var cameraPosition: MapCameraPosition = .region(AppConstants.defaultMapRegion)
    @State private var droppedPinCoordinate = AppConstants.defaultMapCenter
    @State private var mapZoomLevel = AppConstants.defaultMapZoomLevel
    @State private var isResolvingAddress = false
    @State private var isUploading = false
    @State private var uploadErrorMessage: String?

    private let zoomStep = 0.1

    private var mapSpan: MKCoordinateSpan {
        let delta = AppConstants.mapSpanDelta(for: mapZoomLevel)
        return MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
    }

    private var canZoomIn: Bool {
        mapZoomLevel < AppConstants.mapZoomRange.upperBound
    }

    private var canZoomOut: Bool {
        mapZoomLevel > AppConstants.mapZoomRange.lowerBound
    }

    var body: some View {
        ZStack {
            AppTheme.forestGreen.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.title3.bold())
                                    .foregroundStyle(.black)
                            }
                        }
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tap the map to place the resting spot")
                                .font(.caption)
                                .foregroundStyle(.black.opacity(0.6))

                            ZStack(alignment: .topTrailing) {
                                MapReader { proxy in
                                    Map(position: $cameraPosition) {
                                        Annotation("Resting Spot", coordinate: droppedPinCoordinate) {
                                            Image(systemName: "mappin.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(AppTheme.forestGreen)
                                                .accessibilityLabel("Resting spot pin")
                                        }

                                        Annotation("You", coordinate: locationManager.userLocation) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.white)
                                                    .frame(width: 22, height: 22)
                                                Circle()
                                                    .fill(AppTheme.accentBlue)
                                                    .frame(width: 14, height: 14)
                                            }
                                        }
                                    }
                                    .mapStyle(.standard)
                                    .onTapGesture { screenPoint in
                                        guard let coordinate = proxy.convert(screenPoint, from: .local) else {
                                            return
                                        }
                                        droppedPinCoordinate = coordinate
                                        Task {
                                            await updateAddress(for: coordinate)
                                        }
                                    }
                                }

                                zoomControls
                                    .padding(8)
                            }
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.horizontal, 20)

                        PhotosPicker(
                            selection: $selectedPhotos,
                            maxSelectionCount: maxPhotoCount,
                            matching: .images
                        ) {
                            VStack(spacing: 8) {
                                if selectedImages.isEmpty {
                                    Image(systemName: "arrow.up.circle")
                                        .font(.system(size: 32))
                                    Text("Upload Photos")
                                        .font(.headline)
                                    Text("Up to \(maxPhotoCount) images")
                                        .font(.caption)
                                } else {
                                    TabView {
                                        ForEach(selectedImages.indices, id: \.self) { index in
                                            selectedImages[index]
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 120)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .accessibilityLabel("Selected photo \(index + 1)")
                                        }
                                    }
                                    .frame(height: 120)
                                    .tabViewStyle(.page(indexDisplayMode: .automatic))

                                    Text("\(selectedImages.count) photo\(selectedImages.count == 1 ? "" : "s") selected")
                                        .font(.caption)
                                }
                            }
                            .foregroundStyle(.black.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal, 20)
                        .onChange(of: selectedPhotos) { _, newItems in
                            Task {
                                await loadSelectedPhotos(from: newItems)
                            }
                        }

                        HStack {
                            TextField("", text: $address, prompt: Text("Enter address")
                                .foregroundStyle(AppTheme.inputPlaceholder))
                                .foregroundStyle(AppTheme.inputText)
                                .padding()
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .colorScheme(.light)

                            if isResolvingAddress {
                                ProgressView()
                                    .tint(AppTheme.forestGreen)
                                    .padding(.trailing, 8)
                            }
                        }
                        .padding(.horizontal, 20)

                        TextField("", text: $directions, prompt: Text("Directions (optional)")
                            .foregroundStyle(AppTheme.inputPlaceholder))
                            .foregroundStyle(AppTheme.inputText)
                            .padding()
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .colorScheme(.light)
                            .padding(.horizontal, 20)

                        featureChecklist

                        HStack {
                            Spacer()
                            Button(isUploading ? "Uploading..." : "Upload") {
                                Task { await submitSpot() }
                            }
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(AppTheme.cream)
                            .clipShape(Capsule())
                            .disabled(isUploading || isResolvingAddress || address.isEmpty)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                    .padding(.vertical, 16)
                    .background(AppTheme.mutedGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
            }

            if isUploading {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView(uploadProgressMessage)
                    .tint(.white)
                    .foregroundStyle(.white)
            }
        }
        .presentationDetents([.large])
        .onAppear {
            droppedPinCoordinate = locationManager.userLocation
            updateCamera()
            Task {
                await updateAddress(for: droppedPinCoordinate)
            }
        }
        .alert("Upload Error", isPresented: uploadErrorBinding) {
            Button("OK", role: .cancel) {
                uploadErrorMessage = nil
            }
        } message: {
            Text(uploadErrorMessage ?? "Unable to upload this spot.")
        }
    }

    private var featureChecklist: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tag this spot (helps others search):")
                .font(.subheadline.bold())
                .foregroundStyle(.black.opacity(0.7))

            Text("Select amenities like Seating, Restroom, or Park.")
                .font(.caption)
                .foregroundStyle(.black.opacity(0.55))

            ForEach(SpotFeature.allCases) { feature in
                Button {
                    if selectedFeatures.contains(feature) {
                        selectedFeatures.remove(feature)
                    } else {
                        selectedFeatures.insert(feature)
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedFeatures.contains(feature) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(AppTheme.forestGreen)
                        Label(feature.rawValue, systemImage: feature.systemImage)
                            .foregroundStyle(.black)
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    /// Message shown while the spot and any photos are being saved.
    private var uploadProgressMessage: String {
        selectedImagesData.isEmpty ? "Saving spot..." : "Uploading photos..."
    }

    /// Loads preview images and upload bytes from the selected photo picker items.
    /// - Parameter items: Photos chosen in the picker.
    private func loadSelectedPhotos(from items: [PhotosPickerItem]) async {
        var images: [Image] = []
        var imageDataList: [Data] = []

        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                continue
            }
            imageDataList.append(data)
            images.append(Image(uiImage: uiImage))
        }

        selectedImagesData = imageDataList
        selectedImages = images
    }

    /// Reverse-geocodes the dropped pin and updates the address field.
    /// - Parameter coordinate: The map coordinate selected by the user.
    private func updateAddress(for coordinate: CLLocationCoordinate2D) async {
        isResolvingAddress = true
        defer { isResolvingAddress = false }

        do {
            address = try await mapSearchService.reverseGeocode(coordinate)
        } catch {
            address = "Unknown location"
        }
    }

    /// Validates input and uploads the spot to Firestore for all users.
    private func submitSpot() async {
        guard !address.isEmpty, let userID = appState.currentUserID else { return }

        isUploading = true
        uploadErrorMessage = nil

        let spot = RestingSpot(
            id: UUID(),
            name: address.components(separatedBy: ",").first ?? "New Spot",
            address: address,
            directions: directions.isEmpty ? nil : directions,
            latitude: droppedPinCoordinate.latitude,
            longitude: droppedPinCoordinate.longitude,
            features: Array(selectedFeatures),
            imageNames: [],
            imageURL: nil,
            imageURLs: [],
            averageRating: 0,
            reviewCount: 0,
            createdBy: userID
        )

        do {
            try await spotService.uploadSpot(spot, imagesData: selectedImagesData, userID: userID)
            dismiss()
        } catch {
            uploadErrorMessage = error.localizedDescription
        }

        isUploading = false
    }

    private var uploadErrorBinding: Binding<Bool> {
        Binding(
            get: { uploadErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    uploadErrorMessage = nil
                }
            }
        )
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

    /// Recenters the upload map on the dropped pin at the current zoom level.
    private func updateCamera() {
        cameraPosition = .region(MKCoordinateRegion(
            center: droppedPinCoordinate,
            span: mapSpan
        ))
    }

    /// Adjusts the upload map zoom level and recenters on the dropped pin.
    /// - Parameter delta: Positive values zoom in; negative values zoom out.
    private func adjustZoom(by delta: Double) {
        let newLevel = min(
            AppConstants.mapZoomRange.upperBound,
            max(AppConstants.mapZoomRange.lowerBound, mapZoomLevel + delta)
        )
        guard newLevel != mapZoomLevel else { return }
        mapZoomLevel = newLevel
        updateCamera()
    }
}

#Preview {
    UploadSpotView()
        .environmentObject(AppState())
        .environmentObject(SpotDataService())
        .environmentObject(LocationManager())
}
