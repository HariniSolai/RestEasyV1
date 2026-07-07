import SwiftUI

/// Email and password login screen with social sign-in options.
struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var showSignUp = false

    var body: some View {
        ZStack {
            AppTheme.forestGreen.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text("Log In")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 60)
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
                                // Placeholder for password recovery flow
                            }
                            .font(.caption)
                            .foregroundStyle(AppTheme.cream.opacity(0.7))
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 24)

                    PrimaryButton(title: "Log in") {
                        appState.login(email: email, password: password)
                    }
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
                            appState.login(email: "demo@gmail.com", password: "demo")
                        }
                        SocialSignInButton(title: "Continue with Apple", systemImage: "apple.logo") {
                            appState.login(email: "demo@icloud.com", password: "demo")
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .fullScreenCover(isPresented: $showSignUp) {
            SignUpView()
        }
        .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated { dismiss() }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}
