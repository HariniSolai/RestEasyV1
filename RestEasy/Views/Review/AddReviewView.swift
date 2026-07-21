import SwiftUI

/// Sheet for adding a star rating and written review to a resting spot.
struct AddReviewView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var spotService: SpotDataService
    @Environment(\.dismiss) private var dismiss

    let spot: RestingSpot

    @State private var rating = 5
    @State private var comment = ""
    @State private var didSubmit = false
    @State private var isSubmitting = false
    @State private var submitErrorMessage: String?

    private var canSubmit: Bool {
        (1...5).contains(rating) && !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.forestGreen.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    Text(spot.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text(spot.address)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your rating")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack(spacing: 10) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    rating = star
                                } label: {
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .font(.title2)
                                        .foregroundStyle(.yellow)
                                }
                                .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your review")
                            .font(.headline)
                            .foregroundStyle(.white)

                        TextEditor(text: $comment)
                            .frame(minHeight: 120)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(AppTheme.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.black)
                    }

                    PrimaryButton(title: isSubmitting ? "Submitting..." : "Submit Review") {
                        Task {
                            await submitReview()
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                    .opacity(canSubmit && !isSubmitting ? 1 : 0.6)

                    Spacer()
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.bold())
                            .foregroundStyle(AppTheme.cream)
                    }
                    .accessibilityLabel("Close add review")
                }
            }
            .alert("Thanks for your review!", isPresented: $didSubmit) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your review was added to \(spot.name).")
            }
            .alert("Review Error", isPresented: submitErrorBinding) {
                Button("OK", role: .cancel) {
                    submitErrorMessage = nil
                }
            } message: {
                Text(submitErrorMessage ?? "Unable to submit your review.")
            }
        }
    }

    /// Saves the review to Firestore using the signed-in user's profile details.
    private func submitReview() async {
        isSubmitting = true
        submitErrorMessage = nil
        defer { isSubmitting = false }

        do {
            try await spotService.addReview(
                spotID: spot.id,
                authorName: appState.userDisplayName,
                authorUserID: appState.currentUserID,
                rating: rating,
                comment: comment
            )
            didSubmit = true
        } catch {
            submitErrorMessage = error.localizedDescription
        }
    }

    /// Binding that presents an alert when review submission fails.
    private var submitErrorBinding: Binding<Bool> {
        Binding(
            get: { submitErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    submitErrorMessage = nil
                }
            }
        )
    }
}

#Preview {
    AddReviewView(
        spot: RestingSpot(
            id: UUID(),
            name: "Sample Spot",
            address: "123 Main St",
            directions: "Near the entrance",
            latitude: 41.87,
            longitude: -87.65,
            features: [.bench],
            imageNames: [],
            averageRating: 4,
            reviewCount: 1
        )
    )
    .environmentObject(AppState())
    .environmentObject(SpotDataService())
}
