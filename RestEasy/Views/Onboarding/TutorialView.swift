import SwiftUI

// MARK: - Tutorial Target

/// Identifies an on-screen feature that the guided tour can spotlight.
///
/// Each case corresponds to a real view in `MapHomeView` tagged with
/// `.tutorialAnchor(_:)`, letting the overlay find that view's exact frame.
enum TutorialTarget: String {
    case search
    case filters
    case zoom
    case addSpot
}

// MARK: - Tutorial Step

/// A single coach-mark in the guided tour.
struct TutorialStep: Identifiable {
    let id = UUID()

    /// The feature to spotlight, or `nil` for a centered welcome/finish card.
    let target: TutorialTarget?
    let title: String
    let message: String
    let systemImage: String
}

extension TutorialStep {
    /// The ordered coach-marks shown to first-time users on the map screen.
    static let mapTour: [TutorialStep] = [
        TutorialStep(
            target: nil,
            title: "Welcome to RestEasy",
            message: "Find comfortable places to rest nearby. Here's a quick tour of the main features.",
            systemImage: "leaf.fill"
        ),
        TutorialStep(
            target: .search,
            title: "Search",
            message: "Look up a neighborhood, or search by amenity like \"bench\" or \"restroom.\"",
            systemImage: "magnifyingglass"
        ),
        TutorialStep(
            target: .filters,
            title: "Filter by Amenity",
            message: "Tap these chips to show only spots that have the features you need.",
            systemImage: "line.3.horizontal.decrease.circle"
        ),
        TutorialStep(
            target: .zoom,
            title: "Explore the Map",
            message: "Zoom in and out here, double-tap the map to resize it, and tap any pin for details.",
            systemImage: "map"
        ),
        TutorialStep(
            target: .addSpot,
            title: "Add a Spot",
            message: "Know a good resting place we're missing? Add it so others can find it too.",
            systemImage: "plus.circle.fill"
        ),
        TutorialStep(
            target: nil,
            title: "You're All Set",
            message: "Tap a pin to see photos, reviews, and step-by-step directions. Manage your account anytime from the Profile tab.",
            systemImage: "checkmark.circle.fill"
        )
    ]
}

// MARK: - Tutorial Coordinator

/// Drives the guided tutorial: which step is showing and whether it is active.
///
/// This is intentionally view-agnostic so it can be unit tested without any UI.
@MainActor
final class TutorialCoordinator: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var currentIndex = 0

    let steps: [TutorialStep]

    /// Creates a coordinator for an ordered list of steps.
    /// - Parameter steps: The coach-marks to present, in order.
    init(steps: [TutorialStep] = TutorialStep.mapTour) {
        self.steps = steps
    }

    /// The step currently being presented, if any.
    var currentStep: TutorialStep? {
        steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
    }

    /// Whether the current step is the final one in the tour.
    var isLastStep: Bool {
        currentIndex >= steps.count - 1
    }

    /// Human-readable progress label, e.g. "2 of 6".
    var progressText: String {
        "\(currentIndex + 1) of \(steps.count)"
    }

    /// Starts the tour from the first step.
    func start() {
        guard !steps.isEmpty else { return }
        currentIndex = 0
        isActive = true
    }

    /// Advances to the next step, finishing after the last one.
    func advance() {
        if isLastStep {
            finish()
        } else {
            currentIndex += 1
        }
    }

    /// Ends the tour immediately (used by Skip and after the final step).
    func finish() {
        isActive = false
    }
}

// MARK: - Anchor Collection

/// Collects the on-screen frames of tutorial targets through the preference system.
///
/// Children publish their bounds with `.tutorialAnchor(_:)`; a parent reads the
/// merged dictionary with `.overlayPreferenceValue(TutorialAnchorKey.self)`.
struct TutorialAnchorKey: PreferenceKey {
    static let defaultValue: [TutorialTarget: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [TutorialTarget: Anchor<CGRect>],
        nextValue: () -> [TutorialTarget: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { _, latest in latest }
    }
}

extension View {
    /// Registers this view as a spotlight target for the tutorial.
    /// - Parameter target: The feature identifier used to locate this view.
    /// - Returns: The view, publishing its bounds to `TutorialAnchorKey`.
    func tutorialAnchor(_ target: TutorialTarget) -> some View {
        anchorPreference(key: TutorialAnchorKey.self, value: .bounds) { anchor in
            [target: anchor]
        }
    }

    /// Masks the view with the inverse of the given content, punching a hole in it.
    /// - Parameter mask: The shape to cut out of this view.
    /// - Returns: The view with a transparent cut-out where `mask` is drawn.
    @ViewBuilder
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle()
                .overlay(alignment: .topLeading) {
                    mask()
                        .blendMode(.destinationOut)
                }
        }
    }
}

// MARK: - Tutorial Overlay

/// A dimmed overlay that spotlights one feature at a time with an explanatory card.
///
/// It receives the collected feature anchors and a `GeometryProxy` so it can
/// resolve each target's frame in its own coordinate space.
struct TutorialOverlay: View {
    @ObservedObject var coordinator: TutorialCoordinator
    let anchors: [TutorialTarget: Anchor<CGRect>]
    let proxy: GeometryProxy

    private let dimOpacity = 0.72
    private let highlightPadding: CGFloat = 10
    private let highlightCornerRadius: CGFloat = 16

    /// The current step's target frame in this view's coordinate space, if any.
    private var highlightRect: CGRect? {
        guard let target = coordinator.currentStep?.target,
              let anchor = anchors[target] else { return nil }
        return proxy[anchor]
    }

    var body: some View {
        ZStack {
            dimmingLayer

            if let rect = highlightRect {
                spotlightBorder(around: rect)
            }

            calloutContainer
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.currentIndex)
    }

    /// Full-screen dim with a cut-out hole around the highlighted feature.
    private var dimmingLayer: some View {
        Rectangle()
            .fill(Color.black.opacity(dimOpacity))
            .reverseMask {
                if let rect = highlightRect {
                    RoundedRectangle(cornerRadius: highlightCornerRadius)
                        .frame(
                            width: rect.width + highlightPadding * 2,
                            height: rect.height + highlightPadding * 2
                        )
                        .position(x: rect.midX, y: rect.midY)
                }
            }
            // Absorb taps so the underlying UI stays inactive during the tour.
            .contentShape(Rectangle())
            .onTapGesture {}
    }

    /// A bright ring drawn around the cut-out to draw the user's eye.
    /// - Parameter rect: The target frame to outline.
    /// - Returns: A rounded stroke positioned over the highlight.
    private func spotlightBorder(around rect: CGRect) -> some View {
        RoundedRectangle(cornerRadius: highlightCornerRadius)
            .stroke(AppTheme.cream, lineWidth: 3)
            .frame(
                width: rect.width + highlightPadding * 2,
                height: rect.height + highlightPadding * 2
            )
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }

    /// Positions the explanatory card away from the highlighted feature.
    ///
    /// Top-half targets push the card to the bottom, bottom-half targets push it
    /// to the top, and target-less steps (welcome/finish) center the card.
    private var calloutContainer: some View {
        VStack(spacing: 0) {
            if highlightRect == nil {
                Spacer()
                calloutCard
                Spacer()
            } else if isTargetInTopHalf {
                Spacer()
                calloutCard
            } else {
                calloutCard
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 48)
    }

    private var isTargetInTopHalf: Bool {
        guard let rect = highlightRect else { return false }
        return rect.midY < proxy.size.height / 2
    }

    @ViewBuilder
    private var calloutCard: some View {
        if let step = coordinator.currentStep {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: step.systemImage)
                        .font(.title2)
                        .foregroundStyle(AppTheme.forestGreen)
                    Text(step.title)
                        .font(.headline)
                        .foregroundStyle(.black)
                    Spacer(minLength: 0)
                }

                Text(step.message)
                    .font(.subheadline)
                    .foregroundStyle(.black.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text(coordinator.progressText)
                        .font(.caption)
                        .foregroundStyle(.black.opacity(0.5))

                    Spacer()

                    if !coordinator.isLastStep {
                        Button("Skip") {
                            coordinator.finish()
                        }
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.linkGreen)
                    }

                    Button(coordinator.isLastStep ? "Done" : "Next") {
                        coordinator.advance()
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(AppTheme.forestGreen)
                    .clipShape(Capsule())
                }
            }
            .padding(18)
            .background(AppTheme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            .colorScheme(.light)
        }
    }
}

#Preview {
    // A lightweight preview that shows the centered welcome card (no anchors).
    GeometryReader { proxy in
        TutorialOverlay(
            coordinator: {
                let coordinator = TutorialCoordinator()
                coordinator.start()
                return coordinator
            }(),
            anchors: [:],
            proxy: proxy
        )
    }
    .background(AppTheme.sageGreen)
}
