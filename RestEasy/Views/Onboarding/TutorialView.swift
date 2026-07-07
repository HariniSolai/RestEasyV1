import SwiftUI

/// Onboarding tutorial screen with video placeholder.
struct TutorialView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            AppTheme.forestGreen.ignoresSafeArea()

            VStack(spacing: 32) {
                Text("Quick Tutorial")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .padding(.top, 60)

                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.cream)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(AppTheme.forestGreen)
                            Text("Video")
                                .font(.title2)
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 420)
                    .padding(.horizontal, 32)

                Spacer()

                PrimaryButton(title: "Continue") {
                    appState.hasCompletedTutorial = true
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    TutorialView()
        .environmentObject(AppState())
}
