import SwiftUI

/// Auth gate shown when a guest tries to upload a resting spot.
struct WelcomeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showLogin = false
    @State private var showSignUp = false
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            AppTheme.forestGreen.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.bold())
                            .foregroundStyle(AppTheme.cream)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.primaryButton)
                        .overlay(alignment: .bottom) {
                            Image(systemName: "chair.lounge.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(AppTheme.cream)
                                .offset(y: 20)
                        }
                        .padding(.bottom, 24)

                    Text("Welcome to RestEasy")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.cream)
                        .multilineTextAlignment(.center)

                    Text("Sign in to share resting spots with the community")
                        .font(.body)
                        .foregroundStyle(AppTheme.cream.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? AppTheme.cream : AppTheme.cream.opacity(0.35))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 8)

                Spacer()

                HStack(spacing: 16) {
                    Button("LOGIN") {
                        showLogin = true
                    }
                    .font(.headline.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.cream)
                    .clipShape(Capsule())

                    Button("SIGN UP") {
                        showSignUp = true
                    }
                    .font(.headline.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.cream)
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
        }
        .fullScreenCover(isPresented: $showSignUp) {
            SignUpView()
        }
        .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AppState())
}
