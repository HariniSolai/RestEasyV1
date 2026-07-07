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
                    Text("Sign Up")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.cream)
                        .padding(.top, 60)
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

                    PrimaryButton(title: "Sign up") {
                        guard passwordsMatch else { return }
                        appState.signUp(fullName: fullName, email: email, password: password)
                    }
                    .opacity(passwordsMatch ? 1 : 0.6)
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
                            appState.signUp(fullName: "Google User", email: "demo@gmail.com", password: "demo123")
                        }
                        SocialSignInButton(title: "Continue with Apple", systemImage: "apple.logo") {
                            appState.signUp(fullName: "Apple User", email: "demo@icloud.com", password: "demo123")
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
        }
        .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated { dismiss() }
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AppState())
}
