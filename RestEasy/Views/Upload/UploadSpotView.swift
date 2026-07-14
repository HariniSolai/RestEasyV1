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

    @State private var address = ""
    @State private var directions = ""
    @State private var selectedFeatures: Set<SpotFeature> = []
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: Image?
    @State private var selectedImageData: Data?
    @State private var cameraPosition: MapCameraPosition = .region(AppConstants.defaultMapRegion)
    @State private var isUploading = false
    @State private var uploadErrorMessage: String?

    var body: some View {
        ZStack {
            AppTheme.forestGreen.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
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
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    VStack(spacing: 16) {
                        Map(position: $cameraPosition) {
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
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 20)
                        .onAppear {
                            cameraPosition = .region(MKCoordinateRegion(
                                center: locationManager.userLocation,
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            ))
                        }

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            VStack(spacing: 8) {
                                if let selectedImage {
                                    selectedImage
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                } else {
                                    Image(systemName: "arrow.up.circle")
                                        .font(.system(size: 32))
                                    Text("Upload Image")
                                        .font(.headline)
                                }
                            }
                            .foregroundStyle(.black.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal, 20)
                        .onChange(of: selectedPhoto) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    selectedImageData = data
                                    selectedImage = Image(uiImage: uiImage)
                                }
                            }
                        }

                        TextField("Enter address", text: $address)
                            .padding()
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 20)

                        TextField("Directions (optional)", text: $directions)
                            .padding()
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                            .disabled(isUploading || address.isEmpty)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                    .padding(.vertical, 16)
                    .background(AppTheme.sageGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 12)
                }
            }

            if isUploading {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView("Saving spot...")
                    .tint(.white)
                    .foregroundStyle(.white)
            }
        }
        .presentationDetents([.large])
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

            Text("Select amenities like Bench, Restroom, or Park.")
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

    /// Validates input and uploads the spot to Firestore for all users.
    private func submitSpot() async {
        guard !address.isEmpty, let userID = appState.currentUserID else { return }

        isUploading = true
        uploadErrorMessage = nil

        let coordinate = locationManager.userLocation
        let spot = RestingSpot(
            id: UUID(),
            name: address.components(separatedBy: ",").first ?? "New Spot",
            address: address,
            directions: directions.isEmpty ? nil : directions,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            features: Array(selectedFeatures),
            imageNames: [],
            imageURL: nil,
            averageRating: 0,
            reviewCount: 0,
            createdBy: userID
        )

        do {
            try await spotService.uploadSpot(spot, imageData: selectedImageData, userID: userID)
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
}

#Preview {
    UploadSpotView()
        .environmentObject(AppState())
        .environmentObject(SpotDataService())
        .environmentObject(LocationManager())
}
