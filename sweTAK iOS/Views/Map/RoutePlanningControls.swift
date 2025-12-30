import SwiftUI
import CoreLocation

// MARK: - Route Planning Controls

/// Route planning controls displayed when user is in route planning mode.
/// Shows point count, undo, done, and cancel buttons.
public struct RoutePlanningControls: View {
    let waypointCount: Int
    let onUndo: () -> Void
    let onDone: () -> Void
    let onCancel: () -> Void

    public init(
        waypointCount: Int,
        onUndo: @escaping () -> Void,
        onDone: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.waypointCount = waypointCount
        self.onUndo = onUndo
        self.onDone = onDone
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 4) {
            // Header
            Text("Planning")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("\(waypointCount) pts")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))

            // Control buttons
            HStack(spacing: 4) {
                // Undo last point
                PlanningButton(
                    icon: "minus",
                    isEnabled: waypointCount > 0,
                    action: onUndo
                )

                // Done (requires at least 2 points for a valid route)
                PlanningButton(
                    icon: "checkmark",
                    isEnabled: waypointCount >= 2,
                    action: onDone
                )

                // Cancel
                PlanningButton(
                    icon: "xmark",
                    isEnabled: true,
                    action: onCancel
                )
            }
        }
        .padding(8)
        .background(Color.cyan.opacity(0.9))
        .cornerRadius(8)
    }
}

// MARK: - Planning Button

private struct PlanningButton: View {
    let icon: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isEnabled ? .white : .white.opacity(0.3))
                .frame(width: 36, height: 36)
                .background(isEnabled ? Color.white.opacity(0.2) : Color.clear)
                .clipShape(Circle())
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Route Planning State

/// Observable state for route planning
public class RoutePlanningState: ObservableObject {
    @Published public var isPlanning: Bool = false
    @Published public var waypoints: [CLLocationCoordinate2D] = []

    public init() {}

    /// Start planning a new route
    public func startPlanning() {
        isPlanning = true
        waypoints = []
    }

    /// Add a waypoint at the specified coordinate
    public func addWaypoint(_ coordinate: CLLocationCoordinate2D) {
        waypoints.append(coordinate)
    }

    /// Remove the last waypoint
    public func undoLastWaypoint() {
        if !waypoints.isEmpty {
            waypoints.removeLast()
        }
    }

    /// Complete the route and return it
    public func completeRoute(name: String? = nil) -> PlannedRoute? {
        guard waypoints.count >= 2 else { return nil }

        let route = PlannedRoute(
            name: name ?? "Route \(Date().formatted(date: .abbreviated, time: .shortened))",
            waypoints: waypoints.map { RouteWaypoint(coordinate: $0) },
            createdAt: Date()
        )

        cancelPlanning()
        return route
    }

    /// Cancel planning and discard waypoints
    public func cancelPlanning() {
        isPlanning = false
        waypoints = []
    }

    /// Total distance of the current route in meters
    public var totalDistance: Double {
        guard waypoints.count >= 2 else { return 0 }

        var total: Double = 0
        for i in 0..<(waypoints.count - 1) {
            total += haversineDistance(from: waypoints[i], to: waypoints[i + 1])
        }
        return total
    }

    private func haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let earthRadius: Double = 6371000 // meters

        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1) * cos(lat2) *
                sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
    }
}

// MARK: - Route Planning Overlay

/// Full overlay for route planning mode with controls and visual feedback
public struct RoutePlanningOverlay: View {
    @ObservedObject var planningState: RoutePlanningState
    let onComplete: (PlannedRoute) -> Void

    @State private var showingNameDialog = false
    @State private var routeName = ""

    public init(
        planningState: RoutePlanningState,
        onComplete: @escaping (PlannedRoute) -> Void
    ) {
        self.planningState = planningState
        self.onComplete = onComplete
    }

    public var body: some View {
        if planningState.isPlanning {
            VStack {
                // Instructions
                HStack {
                    Text("Tap map to add waypoints")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)

                    Spacer()
                }
                .padding()

                Spacer()

                // Distance indicator
                if planningState.waypoints.count >= 2 {
                    HStack {
                        Spacer()

                        Text(formatDistance(planningState.totalDistance))
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.cyan.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                }

                // Controls
                HStack {
                    Spacer()

                    RoutePlanningControls(
                        waypointCount: planningState.waypoints.count,
                        onUndo: {
                            planningState.undoLastWaypoint()
                        },
                        onDone: {
                            showingNameDialog = true
                        },
                        onCancel: {
                            planningState.cancelPlanning()
                        }
                    )
                }
                .padding()
            }
            .alert("Name Route", isPresented: $showingNameDialog) {
                TextField("Route name", text: $routeName)
                Button("Cancel", role: .cancel) {
                    routeName = ""
                }
                Button("Save") {
                    if let route = planningState.completeRoute(name: routeName.isEmpty ? nil : routeName) {
                        onComplete(route)
                    }
                    routeName = ""
                }
            } message: {
                Text("Enter a name for this route")
            }
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.2f km", meters / 1000)
        }
    }
}

// MARK: - Waypoint Marker

/// Visual marker for a route waypoint
public struct WaypointMarker: View {
    let index: Int
    let isFirst: Bool
    let isLast: Bool

    public init(index: Int, isFirst: Bool = false, isLast: Bool = false) {
        self.index = index
        self.isFirst = isFirst
        self.isLast = isLast
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(markerColor)
                .frame(width: 24, height: 24)

            if isFirst {
                Image(systemName: "flag.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            } else if isLast {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            } else {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    private var markerColor: Color {
        if isFirst {
            return .green
        } else if isLast {
            return .red
        } else {
            return .cyan
        }
    }
}

// MARK: - Previews

#Preview("Route Planning Controls") {
    ZStack {
        Color.gray.opacity(0.3)

        VStack {
            Spacer()

            HStack {
                Spacer()

                VStack(spacing: 20) {
                    RoutePlanningControls(
                        waypointCount: 0,
                        onUndo: {},
                        onDone: {},
                        onCancel: {}
                    )

                    RoutePlanningControls(
                        waypointCount: 3,
                        onUndo: {},
                        onDone: {},
                        onCancel: {}
                    )
                }
            }
            .padding()
        }
    }
}

#Preview("Waypoint Markers") {
    HStack(spacing: 20) {
        WaypointMarker(index: 0, isFirst: true)
        WaypointMarker(index: 1)
        WaypointMarker(index: 2)
        WaypointMarker(index: 3, isLast: true)
    }
    .padding()
}
