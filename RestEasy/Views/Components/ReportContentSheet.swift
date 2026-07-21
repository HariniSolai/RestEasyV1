import SwiftUI

/// Sheet for reporting inappropriate resting spot or review content.
struct ReportContentSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let target: ContentReportTarget
    let spot: RestingSpot
    let review: Review?

    @State private var selectedReason = ContentReportReason.inappropriatePhoto
    @State private var details = ""
    @State private var showSuccessAlert = false

    private var title: String {
        switch target {
        case .spot:
            return "Report Spot"
        case .review:
            return "Report Review"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.forestGreen.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    Text(spot.name)
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.cream)

                    if let review {
                        Text("Review by \(review.authorName)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.cream.opacity(0.85))

                        Text(review.comment)
                            .font(.caption)
                            .foregroundStyle(AppTheme.cream.opacity(0.75))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.forestGreen.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reason")
                            .font(.headline)
                            .foregroundStyle(AppTheme.cream)

                        Picker("Reason", selection: $selectedReason) {
                            ForEach(ContentReportReason.allCases) { reason in
                                Text(reason.displayName).tag(reason)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppTheme.cream)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppTheme.sageGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .colorScheme(.light)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional details (optional)")
                            .font(.headline)
                            .foregroundStyle(AppTheme.cream)

                        TextEditor(text: $details)
                            .frame(minHeight: 100)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(AppTheme.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(AppTheme.inputText)
                            .colorScheme(.light)
                    }

                    PrimaryButton(
                        title: appState.isSubmittingReport ? "Submitting..." : "Submit Report"
                    ) {
                        Task {
                            await submitReport()
                        }
                    }
                    .disabled(appState.isSubmittingReport)

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.cream)
                }
            }
            .toolbarBackground(AppTheme.forestGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Report Submitted", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thanks for letting us know. Our team will review this report.")
            }
            .alert("Report Error", isPresented: reportErrorBinding) {
                Button("OK", role: .cancel) {
                    appState.reportErrorMessage = nil
                }
            } message: {
                Text(appState.reportErrorMessage ?? "Unable to submit this report.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Sends the selected report to Firestore for admin review.
    private func submitReport() async {
        let didSubmit = await appState.submitContentReport(
            target: target,
            spot: spot,
            review: review,
            reason: selectedReason,
            details: details
        )

        if didSubmit {
            showSuccessAlert = true
        }
    }

    /// Binding that presents an alert when report submission fails.
    private var reportErrorBinding: Binding<Bool> {
        Binding(
            get: { appState.reportErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    appState.reportErrorMessage = nil
                }
            }
        )
    }
}
