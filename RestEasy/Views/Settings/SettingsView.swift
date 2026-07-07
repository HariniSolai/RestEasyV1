import SwiftUI

/// Accessibility and display preference settings.
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.forestGreen.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Setting Preferences")
                    .font(.title.bold())
                    .foregroundStyle(AppTheme.cream)
                    .padding(.top, 40)

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display and Text Size")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.cream.opacity(0.85))

                        Slider(value: $appState.textSizeScale, in: 0.8...1.4)
                            .tint(AppTheme.accentBlue)
                    }

                    Button {
                        appState.isHighContrastEnabled.toggle()
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(appState.isHighContrastEnabled ? .white : .clear)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle().stroke(.white, lineWidth: 2)
                                )
                            Text("High Contrast")
                                .foregroundStyle(AppTheme.cream.opacity(0.85))
                            Spacer()
                        }
                    }

                    if appState.isAuthenticated {
                        Divider()
                            .background(AppTheme.cream.opacity(0.3))

                        Button {
                            appState.logout()
                            dismiss()
                        } label: {
                            Text("Log Out")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.cream)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(24)
                .background(AppTheme.sageGreen)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .font(.headline)
                .foregroundStyle(AppTheme.cream)
                .padding(.bottom, 32)
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
