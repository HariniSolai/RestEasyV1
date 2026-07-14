import SwiftUI

/// Registration screen for new RestEasy users.
struct SignUpView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmVisible = false
    @State private var showLogin = false

    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

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
                        .accessibilityLabel("Close sign up")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    Text("Sign Up")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.cream)
                        .padding(.top, 20)
                        .padding(.bottom, 20)

                    VStack(spacing: 16) {
                        CreamTextField(placeholder: "Full Name", text: $fullName)
                        CreamTextField(placeholder: "Email", text: $email)
                            .keyboardType(.emailAddress)
                        CreamTextField(
                            placeholder: "Password",
                            text: $password,
                            isSecure: true,
                            isPasswordVisible: $isPasswordVisible
                        )
                        CreamTextField(
                            placeholder: "Confirm your password",
                            text: $confirmPassword,
                            isSecure: true,
                            isPasswordVisible: $isConfirmVisible
                        )
                    }
                    .padding(.horizontal, 24)

                    PrimaryButton(title: appState.isAuthLoading ? "Creating account..." : "Sign up") {
                        guard passwordsMatch, password.count >= 6 else { return }
                        Task {
                            await appState.signUp(fullName: fullName, email: email, password: password)
                        }
                    }
                    .opacity(canSubmit ? 1 : 0.6)
                    .disabled(!canSubmit || appState.isAuthLoading)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    Button {
                        showLogin = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundStyle(AppTheme.cream.opacity(0.8))
                            Text("Login")
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
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
        }
        .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated { dismiss() }
        }
        .alert("Sign Up Error", isPresented: authErrorBinding) {
            Button("OK", role: .cancel) {
                appState.authErrorMessage = nil
            }
        } message: {
            Text(appState.authErrorMessage ?? "Unable to create an account.")
        }
    }

    private var canSubmit: Bool {
        passwordsMatch
            && password.count >= 6
            && !fullName.isEmpty
            && !email.isEmpty
    }

    private var authErrorBinding: Binding<Bool> {
        Binding(
            get: { appState.authErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    appState.authErrorMessage = nil
                }
            }
        )
    }
}

#Preview {
    SignUpView()
        .environmentObject(AppState())
}
