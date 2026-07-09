import SwiftUI
import MapKit
import PhotosUI

/// Form for users to contribute a new resting spot.
struct UploadSpotView: View {
    @EnvironmentObject private var spotService: SpotDataService
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    @State private var address = ""
    @State private var directions = ""
    @State private var selectedFeatures: Set<SpotFeature> = []
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: Image?
    @State private var cameraPosition: MapCameraPosition = .automatic

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
                            if let location = locationManager.userLocation {
                                Marker("Your Location", coordinate: location)
                            }
                        }
                        .mapStyle(.standard)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 20)
                        .onAppear {
                            if let location = locationManager.userLocation {
                                cameraPosition = .region(MKCoordinateRegion(
                                    center: location,
                                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                ))
                            }
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
                            Button("Upload") {
                                submitSpot()
                            }
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(AppTheme.cream)
                            .clipShape(Capsule())
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
        }
        .presentationDetents([.large])
    }

    private var featureChecklist: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Check all that apply:")
                .font(.subheadline.bold())
                .foregroundStyle(.black.opacity(0.7))

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
                        Text(feature.rawValue)
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

    private func submitSpot() {
        guard !address.isEmpty else { return }
        let coordinate = locationManager.userLocation ?? AppConstants.defaultMapCenter

        let spot = RestingSpot(
            id: UUID(),
            name: address.components(separatedBy: ",").first ?? "New Spot",
            address: address,
            directions: directions.isEmpty ? nil : directions,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            features: Array(selectedFeatures),
            imageName: nil,
            averageRating: 0,
            reviewCount: 0
        )

        spotService.addSpot(spot)
        dismiss()
    }
}

#Preview {
    UploadSpotView()
        .environmentObject(SpotDataService())
        .environmentObject(LocationManager())
}
