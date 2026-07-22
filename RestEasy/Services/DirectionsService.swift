import Foundation
import MapKit
import CoreLocation

/// Travel modes available for in-app directions to a resting spot.
enum TravelMode: String, CaseIterable, Identifiable {
    // Declaration order drives the picker order; `walking` is first so it is the
    // default (see `DirectionsService.travelMode`) and the main option.
    case walking
    case cycling
    case automobile
    case transit

    var id: String { rawValue }

    /// User-facing label for the travel mode picker.
    var title: String {
        switch self {
        case .walking: return "Walk"
        case .cycling: return "Bike"
        case .automobile: return "Drive"
        case .transit: return "Transit"
        }
    }

    /// SF Symbol used in the travel mode picker.
    var systemImage: String {
        switch self {
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .automobile: return "car.fill"
        case .transit: return "bus.fill"
        }
    }

    /// MapKit transport type used when requesting directions.
    ///
    /// MapKit has no dedicated cycling route type, so `cycling` reuses walking
    /// paths, which best approximate bike-friendly routes for short city trips.
    var mapKitTransportType: MKDirectionsTransportType {
        switch self {
        case .walking: return .walking
        case .cycling: return .walking
        case .automobile: return .automobile
        case .transit: return .transit
        }
    }
}

/// A single turn-by-turn instruction along an in-app route.
struct RouteStep: Identifiable {
    let id: UUID
    let instruction: String
    let distanceMeters: CLLocationDistance
    let coordinates: [CLLocationCoordinate2D]

    /// Creates a route step from MapKit step data.
    /// - Parameters:
    ///   - instruction: The spoken/written guidance for this maneuver.
    ///   - distanceMeters: Distance covered by this step in meters.
    ///   - coordinates: Polyline points for this step.
    init(
        instruction: String,
        distanceMeters: CLLocationDistance,
        coordinates: [CLLocationCoordinate2D]
    ) {
        self.id = UUID()
        self.instruction = instruction
        self.distanceMeters = distanceMeters
        self.coordinates = coordinates
    }

    /// Human-readable distance for this step.
    /// - Returns: A short distance string such as `400 ft` or `0.2 mi`.
    var formattedDistance: String {
        Self.formatDistance(distanceMeters)
    }

    /// Formats a meter distance for navigation banners and step lists.
    /// - Parameter meters: Distance in meters.
    /// - Returns: A short readable distance string.
    static func formatDistance(_ meters: CLLocationDistance) -> String {
        let miles = meters / 1609.344
        if miles >= 0.1 {
            return String(format: "%.1f mi", miles)
        }
        let feet = meters * 3.28084
        return "\(max(1, Int(feet.rounded()))) ft"
    }

    /// End coordinate of this step, used as the next maneuver target.
    var endCoordinate: CLLocationCoordinate2D? {
        coordinates.last
    }
}

/// Live progress through an active route during confirmed navigation.
struct LiveRouteProgress {
    let stepIndex: Int
    let instruction: String
    let distanceToManeuverMeters: CLLocationDistance
    let remainingDistanceMeters: CLLocationDistance
    let remainingTravelTime: TimeInterval

    /// Banner text such as "Turn left in 200 ft".
    var bannerText: String {
        "\(instruction) in \(RouteStep.formatDistance(distanceToManeuverMeters))"
    }

    /// Remaining ETA for the live guidance panel.
    var formattedRemainingETA: String {
        let totalMinutes = max(1, Int(ceil(remainingTravelTime / 60)))
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 {
            return "\(hours) hr"
        }
        return "\(hours) hr \(minutes) min"
    }
}

/// A calculated route from the user to a resting spot, including ETA and path geometry.
struct SpotRoute {
    let distanceMeters: CLLocationDistance
    let expectedTravelTime: TimeInterval
    let coordinates: [CLLocationCoordinate2D]
    let steps: [RouteStep]
    let travelMode: TravelMode

    /// Human-readable travel time (for example, "12 min").
    /// - Returns: A short ETA string suitable for the spot detail panel.
    var formattedETA: String {
        let totalMinutes = max(1, Int(ceil(expectedTravelTime / 60)))
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 {
            return "\(hours) hr"
        }
        return "\(hours) hr \(minutes) min"
    }

    /// Human-readable distance (miles when ≥ 0.1 mi, otherwise feet).
    /// - Returns: A short distance string suitable for the spot detail panel.
    var formattedDistance: String {
        RouteStep.formatDistance(distanceMeters)
    }
}

/// Calculates walking, driving, or transit routes to resting spots using MapKit.
@MainActor
final class DirectionsService: ObservableObject {
    @Published private(set) var route: SpotRoute?
    @Published private(set) var liveProgress: LiveRouteProgress?
    @Published private(set) var isLoading = false
    @Published private(set) var isRerouting = false
    @Published private(set) var errorMessage: String?
    @Published var travelMode: TravelMode = .walking

    private var activeRequestID = UUID()
    private var lastRerouteDate: Date?

    /// Clears live step progress without removing the reviewed route.
    func clearLiveProgressOnly() {
        liveProgress = nil
        isRerouting = false
    }

    /// Clears any active route, progress, and error state.
    func clear() {
        activeRequestID = UUID()
        route = nil
        liveProgress = nil
        errorMessage = nil
        isLoading = false
        isRerouting = false
        lastRerouteDate = nil
    }

    /// Requests directions from an origin coordinate to a destination coordinate.
    /// - Parameters:
    ///   - origin: The starting coordinate (usually the user, or Chicago as a fallback).
    ///   - destination: The resting spot coordinate.
    ///   - isReroute: When `true`, keeps the previous route visible while recalculating.
    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        isReroute: Bool = false
    ) async {
        let requestID = UUID()
        activeRequestID = requestID

        if isReroute {
            isRerouting = true
        } else {
            isLoading = true
            errorMessage = nil
            route = nil
            liveProgress = nil
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = travelMode.mapKitTransportType
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)

        do {
            let response = try await directions.calculate()
            guard activeRequestID == requestID else { return }

            guard let mapRoute = response.routes.first else {
                errorMessage = "No route found to this spot."
                isLoading = false
                isRerouting = false
                return
            }

            route = SpotRoute(
                distanceMeters: mapRoute.distance,
                expectedTravelTime: mapRoute.expectedTravelTime,
                coordinates: Self.coordinates(from: mapRoute.polyline),
                steps: Self.steps(from: mapRoute),
                travelMode: travelMode
            )
            isLoading = false
            isRerouting = false
            if isReroute {
                lastRerouteDate = Date()
            }
        } catch {
            guard activeRequestID == requestID else { return }
            if !isReroute {
                route = nil
            }
            errorMessage = Self.userFacingMessage(for: error)
            isLoading = false
            isRerouting = false
        }
    }

    /// Updates the current step banner from the user's live position along the route.
    /// - Parameter userLocation: The latest GPS coordinate.
    func updateLiveProgress(at userLocation: CLLocationCoordinate2D) {
        guard let route, !route.steps.isEmpty else {
            liveProgress = nil
            return
        }

        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        var bestStepIndex = 0
        var bestDistance = Double.greatestFiniteMagnitude

        for (index, step) in route.steps.enumerated() {
            guard let endCoordinate = step.endCoordinate else { continue }
            let endLocation = CLLocation(latitude: endCoordinate.latitude, longitude: endCoordinate.longitude)
            let distance = userCLLocation.distance(from: endLocation)
            if distance < bestDistance {
                bestDistance = distance
                bestStepIndex = index
            }
        }

        // Prefer the earliest unfinished step whose end is still reasonably ahead.
        for (index, step) in route.steps.enumerated() {
            guard let endCoordinate = step.endCoordinate else { continue }
            let endLocation = CLLocation(latitude: endCoordinate.latitude, longitude: endCoordinate.longitude)
            let distance = userCLLocation.distance(from: endLocation)
            if distance > AppConstants.liveStepCompletionRadiusMeters {
                bestStepIndex = index
                bestDistance = distance
                break
            }
            if index == route.steps.count - 1 {
                bestStepIndex = index
                bestDistance = distance
            }
        }

        let currentStep = route.steps[bestStepIndex]
        let remainingDistance = remainingDistance(from: userLocation, startingAtStep: bestStepIndex, in: route)
        let speedMetersPerSecond = max(route.distanceMeters / max(route.expectedTravelTime, 1), 0.7)
        let remainingTime = remainingDistance / speedMetersPerSecond

        liveProgress = LiveRouteProgress(
            stepIndex: bestStepIndex,
            instruction: currentStep.instruction,
            distanceToManeuverMeters: bestDistance,
            remainingDistanceMeters: remainingDistance,
            remainingTravelTime: remainingTime
        )
    }

    /// Returns whether the user has drifted far enough from the route to need a new path.
    /// - Parameter userLocation: The latest GPS coordinate.
    /// - Returns: `true` when the user is beyond the off-route threshold.
    func isOffRoute(at userLocation: CLLocationCoordinate2D) -> Bool {
        guard let route, route.coordinates.count >= 2 else { return false }
        let distance = minimumDistance(from: userLocation, to: route.coordinates)
        return distance > AppConstants.liveOffRouteThresholdMeters
    }

    /// Returns whether enough time has passed to allow another reroute request.
    /// - Returns: `true` when a reroute may be requested.
    func canRerouteNow() -> Bool {
        guard !isRerouting else { return false }
        guard let lastRerouteDate else { return true }
        return Date().timeIntervalSince(lastRerouteDate) >= AppConstants.liveRerouteCooldownSeconds
    }

    /// Estimates remaining path distance from the user through the unfinished steps.
    /// - Parameters:
    ///   - userLocation: The latest GPS coordinate.
    ///   - stepIndex: The current step index.
    ///   - route: The active route.
    /// - Returns: Remaining meters to the destination.
    private func remainingDistance(
        from userLocation: CLLocationCoordinate2D,
        startingAtStep stepIndex: Int,
        in route: SpotRoute
    ) -> CLLocationDistance {
        guard route.steps.indices.contains(stepIndex) else { return route.distanceMeters }

        var total = 0.0
        if let endCoordinate = route.steps[stepIndex].endCoordinate {
            let user = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            let end = CLLocation(latitude: endCoordinate.latitude, longitude: endCoordinate.longitude)
            total += user.distance(from: end)
        }

        if stepIndex + 1 < route.steps.count {
            for laterStep in route.steps[(stepIndex + 1)...] {
                total += laterStep.distanceMeters
            }
        }

        return total
    }

    /// Finds the shortest distance from a coordinate to any segment of a polyline.
    /// - Parameters:
    ///   - coordinate: The user's location.
    ///   - polyline: Route coordinates.
    /// - Returns: Distance in meters to the nearest point on the path.
    private func minimumDistance(
        from coordinate: CLLocationCoordinate2D,
        to polyline: [CLLocationCoordinate2D]
    ) -> CLLocationDistance {
        let user = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var minimum = Double.greatestFiniteMagnitude

        for point in polyline {
            let candidate = CLLocation(latitude: point.latitude, longitude: point.longitude)
            minimum = min(minimum, user.distance(from: candidate))
        }

        return minimum
    }

    /// Builds readable turn-by-turn steps from a MapKit route.
    /// - Parameter mapRoute: The route returned by `MKDirections`.
    /// - Returns: Non-empty instruction steps for in-app navigation.
    private static func steps(from mapRoute: MKRoute) -> [RouteStep] {
        mapRoute.steps.compactMap { step in
            let instruction = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !instruction.isEmpty else { return nil }
            return RouteStep(
                instruction: instruction,
                distanceMeters: step.distance,
                coordinates: coordinates(from: step.polyline)
            )
        }
    }

    /// Extracts ordered coordinates from a MapKit polyline.
    /// - Parameter polyline: The route geometry returned by MapKit.
    /// - Returns: Coordinates suitable for drawing a `MapPolyline`.
    private static func coordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var coordinates = Array(
            repeating: CLLocationCoordinate2D(),
            count: polyline.pointCount
        )
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))
        return coordinates
    }

    /// Converts a MapKit directions error into a short user-facing message.
    /// - Parameter error: The error thrown by `MKDirections`.
    /// - Returns: A readable explanation for the UI.
    private static func userFacingMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == MKErrorDomain {
            switch MKError.Code(rawValue: UInt(nsError.code)) {
            case .directionsNotFound:
                return "No route found for this travel mode."
            case .loadingThrottled:
                return "Directions are temporarily unavailable. Try again shortly."
            case .serverFailure, .placemarkNotFound:
                return "Unable to calculate directions right now."
            default:
                break
            }
        }
        return error.localizedDescription
    }
}
