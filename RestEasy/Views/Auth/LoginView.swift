import SwiftUI

/// Email and password login screen with social sign-in options.
struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var showSignUp = false
    @State private var showResetConfirmation = false

    var body: some View {
        ZStack {
            AppTheme.forestGreen.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3.bold())
                                .foregroundStyle(AppTheme.cream)
                        }
                        .accessibilityLabel("Close login")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    Text("Log In")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 20)
                        .padding(.bottom, 20)

                    VStack(spacing: 16) {
                        CreamTextField(placeholder: "Email address", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)

                        CreamTextField(
                            placeholder: "Password",
                            text: $password,
                            isSecure: true,
                            isPasswordVisible: $isPasswordVisible
                        )
                        .textContentType(.password)

                        HStack {
                            Button("forgot password?") {
                                Task {
                                    await appState.sendPasswordReset(email: email)
                                    showResetConfirmation = true
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(AppTheme.cream.opacity(0.7))
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 24)

                    PrimaryButton(title: appState.isAuthLoading ? "Logging in..." : "Log in") {
                        Task {
                            await appState.login(email: email, password: password)
                        }
                    }
                    .disabled(appState.isAuthLoading || email.isEmpty || password.isEmpty)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    Button {
                        showSignUp = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundStyle(AppTheme.cream.opacity(0.8))
                            Text("Sign Up")
                                .foregroundStyle(AppTheme.linkGreen)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }

                    OrDivider()
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)

                    VStack(spacing: 12) {
                        SocialSignInButton(title: "Continue with Google", systemImage: "g.circle.fill") {
                            Task { await appState.signInWithGoogle() }
                        }
                        .disabled(appState.isAuthLoading)

                        SocialSignInButton(title: "Continue with Apple", systemImage: "apple.logo") {
                            Task { await appState.signInWithApple() }
                        }
                        .disabled(appState.isAuthLoading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }

            if appState.isAuthLoading {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView()
                    .tint(.white)
            }
        }
        .fullScreenCover(isPresented: $showSignUp) {
            SignUpView()
        }
        .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated { dismiss() }
        }
        .alert("Sign In Error", isPresented: authErrorBinding) {
            Button("OK", role: .cancel) {
                appState.authErrorMessage = nil
            }
        } message: {
            Text(appState.authErrorMessage ?? "Unable to sign in.")
        }
        .alert("Password Reset", isPresented: $showResetConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = appState.authErrorMessage {
                Text(error)
            } else {
                Text("If an account exists for that email, a reset link has been sent.")
            }
        }
    }

    private var authErrorBinding: Binding<Bool> {
        Binding(
            get: { appState.authErrorMessage != nil && !showResetConfirmation },
            set: { isPresented in
                if !isPresented {
                    appState.authErrorMessage = nil
                }
            }
        )
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}
