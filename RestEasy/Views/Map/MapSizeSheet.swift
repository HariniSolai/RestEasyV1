import SwiftUI
import MapKit

/// Sheet for adjusting map zoom level before confirming.
struct MapSizeSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Binding var cameraPosition: MapCameraPosition

    var body: some View {
        ZStack {
            AppTheme.forestGreen.ignoresSafeArea()

            VStack {
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

                VStack(spacing: 20) {
                    Map(position: $cameraPosition) {
                        UserAnnotation()
                    }
                    .mapStyle(.standard)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(height: 280)
                    .padding(.horizontal, 20)

                    Text("Map Size")
                        .font(.headline)
                        .foregroundStyle(AppTheme.forestGreen.opacity(0.8))

                    Slider(value: $appState.mapZoomLevel, in: 0...1)
                        .tint(AppTheme.forestGreen)
                        .padding(.horizontal, 32)

                    HStack(spacing: 16) {
                        Button("Back") {
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.cream)
                        .clipShape(Capsule())

                        Button("Confirm") {
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.cream)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
                .background(AppTheme.sageGreen)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    MapSizeSheet(cameraPosition: .constant(.automatic))
        .environmentObject(AppState())
}
