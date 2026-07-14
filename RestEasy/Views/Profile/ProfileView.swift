import PhotosUI
import SwiftUI

/// Profile tab: signed-in account details, or a guest landing page with sign-up.
struct ProfileView: View {
    @EnvironmentObject private var appState: AppState

    @State private var showAuthSheet = false
    @State private var showSettings = false
    @State private var showEditDisplayName = false
    @State private var editedDisplayName = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoUploadErrorMessage: String?

    var body: some View {
        ZStack {
            AppTheme.forestGreen.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Text("Profile")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.cream)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    if appState.isAuthenticated {
                        signedInContent
                    } else {
                        guestContent
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .fullScreenCover(isPresented: $showAuthSheet) {
            WelcomeView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showEditDisplayName) {
            editDisplayNameSheet
        }
        .alert("Profile Photo", isPresented: photoUploadErrorBinding) {
            Button("OK", role: .cancel) {
                photoUploadErrorMessage = nil
            }
        } message: {
            Text(photoUploadErrorMessage ?? "Unable to update your profile photo.")
        }
    }

    /// Account card and actions for a signed-in Firebase user.
    private var signedInContent: some View {
        VStack(spacing: 20) {
            editableProfileAvatar

            VStack(spacing: 6) {
                Text(appState.userDisplayName.isEmpty ? "RestEasy Member" : appState.userDisplayName)
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.cream)
                    .multilineTextAlignment(.center)

                Text("Signed in")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.cream.opacity(0.75))
            }

            accountInfoSection

            VStack(spacing: 12) {
                Button {
                    appState.authErrorMessage = nil
                    editedDisplayName = appState.userDisplayName
                    showEditDisplayName = true
                } label: {
                    profileActionLabel(title: "Edit Display Name", systemImage: "pencil")
                }

                Button {
                    showSettings = true
                } label: {
                    profileActionLabel(title: "Preferences", systemImage: "gearshape.fill")
                }

                Button {
                    appState.logout()
                } label: {
                    Text("Log Out")
                        .font(.headline.bold())
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.cream)
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppTheme.sageGreen)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Tappable avatar that opens the photo library and uploads to Firebase.
    private var editableProfileAvatar: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                profilePhotoView(fallbackSystemImage: "person.crop.circle.fill")

                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppTheme.forestGreen, AppTheme.cream)
                    .accessibilityHidden(true)
            }
        }
        .disabled(appState.isAuthLoading)
        .accessibilityLabel("Change profile photo")
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                await uploadSelectedProfilePhoto(from: newItem)
            }
        }
        .overlay {
            if appState.isAuthLoading {
                ProgressView()
                    .tint(AppTheme.cream)
                    .padding(12)
                    .background(AppTheme.forestGreen.opacity(0.75))
                    .clipShape(Circle())
            }
        }
    }

    /// Loads picker image data and sends it through AppState to Firebase.
    /// - Parameter item: The PhotosPicker selection chosen by the user.
    private func uploadSelectedProfilePhoto(from item: PhotosPickerItem) async {
        appState.authErrorMessage = nil
        photoUploadErrorMessage = nil

        do {
            guard let imageData = try await item.loadTransferable(type: Data.self) else {
                photoUploadErrorMessage = "That image couldn’t be loaded. Try a different photo."
                selectedPhoto = nil
                return
            }

            await appState.updateProfilePhoto(imageData: imageData)
            if let errorMessage = appState.authErrorMessage, !errorMessage.isEmpty {
                photoUploadErrorMessage = errorMessage
            }
        } catch {
            photoUploadErrorMessage = error.localizedDescription
        }

        selectedPhoto = nil
    }

    /// Binding that presents an alert when a photo upload fails.
    private var photoUploadErrorBinding: Binding<Bool> {
        Binding(
            get: { photoUploadErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    photoUploadErrorMessage = nil
                }
            }
        )
    }

    /// Read-only account fields such as the signup email.
    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.cream.opacity(0.85))

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(AppTheme.cream.opacity(0.85))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.caption)
                        .foregroundStyle(AppTheme.cream.opacity(0.7))

                    Text(displayEmail)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppTheme.cream)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.forestGreen.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Email shown on profile, with a clear fallback when Firebase has none.
    private var displayEmail: String {
        if appState.userEmail.isEmpty {
            return "Not available for this account"
        }
        return appState.userEmail
    }

    /// Sheet that lets a signed-in user change their display name.
    private var editDisplayNameSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.forestGreen.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("This name appears on your profile and on reviews you post.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.cream.opacity(0.85))

                    CreamTextField(
                        placeholder: "Display name",
                        text: $editedDisplayName
                    )

                    if let errorMessage = appState.authErrorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.red.opacity(0.9))
                    }

                    PrimaryButton(title: appState.isAuthLoading ? "Saving…" : "Save") {
                        Task {
                            await appState.updateDisplayName(editedDisplayName)
                            if appState.authErrorMessage == nil {
                                showEditDisplayName = false
                            }
                        }
                    }
                    .disabled(appState.isAuthLoading || editedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(editedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Edit Display Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showEditDisplayName = false
                    }
                    .foregroundStyle(AppTheme.cream)
                }
            }
            .toolbarBackground(AppTheme.forestGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium])
    }

    /// Guest landing with a clear path to create or sign into an account.
    private var guestContent: some View {
        VStack(spacing: 20) {
            profilePhotoView(fallbackSystemImage: "person.crop.circle")

            VStack(spacing: 8) {
                Text("Guest")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.cream)

                Text("You’re browsing as a guest. Create an account to upload resting spots and leave reviews.")
                    .font(.body)
                    .foregroundStyle(AppTheme.cream.opacity(0.85))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    showAuthSheet = true
                } label: {
                    Text("Sign Up / Log In")
                        .font(.headline.bold())
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.primaryButton)
                        .clipShape(Capsule())
                }

                Button {
                    showSettings = true
                } label: {
                    profileActionLabel(title: "Preferences", systemImage: "gearshape.fill")
                }
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppTheme.sageGreen)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Circular avatar that prefers the Firebase photo URL when available.
    /// - Parameter fallbackSystemImage: SF Symbol used when no photo is set.
    /// - Returns: A circular profile image view.
    private func profilePhotoView(fallbackSystemImage: String) -> some View {
        Group {
            if let photoURL = appState.userPhotoURL {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: fallbackSystemImage)
                            .font(.system(size: 72))
                            .foregroundStyle(AppTheme.cream)
                    case .empty:
                        ProgressView()
                            .tint(AppTheme.cream)
                    @unknown default:
                        Image(systemName: fallbackSystemImage)
                            .font(.system(size: 72))
                            .foregroundStyle(AppTheme.cream)
                    }
                }
            } else {
                Image(systemName: fallbackSystemImage)
                    .font(.system(size: 72))
                    .foregroundStyle(AppTheme.cream)
            }
        }
        .frame(width: 96, height: 96)
        .background(AppTheme.forestGreen.opacity(0.25))
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(AppTheme.cream.opacity(0.35), lineWidth: 2)
        )
        .accessibilityHidden(true)
    }

    /// Secondary row-style button used for non-primary profile actions.
    /// - Parameters:
    ///   - title: Button label text.
    ///   - systemImage: Leading SF Symbol.
    /// - Returns: A styled label for a profile action button.
    private func profileActionLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
            Text(title)
                .font(.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(AppTheme.cream)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(AppTheme.forestGreen.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Guest") {
    ProfileView()
        .environmentObject(AppState())
}

#Preview("Signed In") {
    let state = AppState()
    return ProfileView()
        .environmentObject(state)
}
