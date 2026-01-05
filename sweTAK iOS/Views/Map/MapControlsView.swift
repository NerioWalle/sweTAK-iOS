import SwiftUI
import MapKit

/// Map control buttons for zoom, follow mode, and recording
/// Mirrors Android MapControlButtons functionality
public struct MapControlsView: View {
    @ObservedObject private var mapVM = MapViewModel.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var settingsVM = SettingsViewModel.shared
    @ObservedObject private var routesVM = RoutesViewModel.shared

    // Callbacks
    var onCenterOnMe: (() -> Void)?
    var onAddPin: (() -> Void)?
    var onShowRoutes: (() -> Void)?

    @State private var showingRecordingControls = false

    public init(
        onCenterOnMe: (() -> Void)? = nil,
        onAddPin: (() -> Void)? = nil,
        onShowRoutes: (() -> Void)? = nil
    ) {
        self.onCenterOnMe = onCenterOnMe
        self.onAddPin = onAddPin
        self.onShowRoutes = onShowRoutes
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Follow me / Center button
            MapButton(
                icon: mapVM.followMe ? "location.fill" : "location",
                isActive: mapVM.followMe
            ) {
                mapVM.toggleFollowMe()
                onCenterOnMe?()
            }

            // Compass / North up
            MapButton(icon: "location.north.fill") {
                mapVM.updateMapBearing(0)
            }
            .rotationEffect(.degrees(mapVM.mapBearing))

            Divider()
                .frame(width: 40)
                .background(Color.white.opacity(0.3))

            // Add pin
            MapButton(icon: "mappin.and.ellipse") {
                onAddPin?()
            }

            // Routes menu
            MapButton(icon: "point.topleft.down.curvedto.point.bottomright.up") {
                onShowRoutes?()
            }

            // Recording controls
            if locationManager.isRecordingBreadcrumbs {
                recordingButton
            } else {
                MapButton(icon: "record.circle") {
                    showingRecordingControls = true
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .confirmationDialog("Breadcrumb Recording", isPresented: $showingRecordingControls) {
            Button("Start Recording") {
                locationManager.startRecordingBreadcrumbs()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var recordingButton: some View {
        VStack(spacing: 4) {
            MapButton(
                icon: "stop.fill",
                tint: .red
            ) {
                if let route = locationManager.stopRecordingBreadcrumbs() {
                    // Save route
                    saveBreadcrumbRoute(route)
                }
            }

            Text(formatDuration(locationManager.recordingStartTime))
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red)
                .cornerRadius(4)
        }
    }

    private func formatDuration(_ startTime: Date?) -> String {
        guard let start = startTime else { return "0:00" }
        let duration = Date().timeIntervalSince(start)
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func saveBreadcrumbRoute(_ route: BreadcrumbRoute) {
        routesVM.addBreadcrumbRoute(route)
    }
}

// MARK: - Map Button

struct MapButton: View {
    let icon: String
    var isActive: Bool = false
    var tint: Color = .blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? tint : .primary)
                .frame(width: 44, height: 44)
        }
    }
}

// MARK: - Routes List Sheet

public struct RoutesListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var routesVM = RoutesViewModel.shared

    public init() {}

    /// Unified route item for display
    private enum UnifiedRoute: Identifiable {
        case recorded(BreadcrumbRoute)
        case planned(PlannedRoute)

        var id: String {
            switch self {
            case .recorded(let route): return "recorded_\(route.id)"
            case .planned(let route): return "planned_\(route.id)"
            }
        }

        var createdAt: Date {
            switch self {
            case .recorded(let route): return route.startTime
            case .planned(let route): return route.createdAt
            }
        }

        var name: String {
            switch self {
            case .recorded(let route): return route.name ?? "Untitled Route"
            case .planned(let route): return route.name
            }
        }

        var isVisible: Bool {
            switch self {
            case .recorded(let route): return route.isVisible
            case .planned(let route): return route.isVisible
            }
        }

        var typeLabel: String {
            switch self {
            case .recorded: return "Recorded"
            case .planned: return "Planned"
            }
        }

        var typeColor: Color {
            switch self {
            case .recorded: return .orange
            case .planned: return .cyan
            }
        }
    }

    /// All routes combined and sorted by creation date (newest first)
    private var allRoutes: [UnifiedRoute] {
        let recorded = routesVM.breadcrumbRoutes.map { UnifiedRoute.recorded($0) }
        let planned = routesVM.plannedRoutes.map { UnifiedRoute.planned($0) }
        return (recorded + planned).sorted { $0.createdAt > $1.createdAt }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if allRoutes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No routes")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Create a route by tapping\n\"Create Route\" in the map menu")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(allRoutes) { route in
                            UnifiedRouteRow(
                                route: route,
                                onToggleVisibility: { toggleVisibility(for: route) },
                                onDelete: { deleteRoute(route) }
                            )
                        }
                        .onDelete { offsets in
                            for offset in offsets {
                                deleteRoute(allRoutes[offset])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func toggleVisibility(for route: UnifiedRoute) {
        switch route {
        case .recorded(let r):
            routesVM.toggleBreadcrumbVisibility(id: r.id)
        case .planned(let r):
            routesVM.togglePlannedRouteVisibility(id: r.id)
        }
    }

    private func deleteRoute(_ route: UnifiedRoute) {
        switch route {
        case .recorded(let r):
            routesVM.deleteBreadcrumbRoute(id: r.id)
        case .planned(let r):
            routesVM.deletePlannedRoute(id: r.id)
        }
    }

    // MARK: - Unified Route Row (nested)

    private struct UnifiedRouteRow: View {
        let route: UnifiedRoute
        let onToggleVisibility: () -> Void
        let onDelete: () -> Void

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(route.name)
                            .font(.headline)

                        // Type tag
                        Text(route.typeLabel)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(route.typeColor)
                            .cornerRadius(4)
                    }

                    routeDetails
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formatDate(route.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { route.isVisible },
                    set: { _ in onToggleVisibility() }
                ))
                .labelsHidden()
            }
            .padding(.vertical, 4)
        }

        @ViewBuilder
        private var routeDetails: some View {
            switch route {
            case .recorded(let r):
                HStack(spacing: 12) {
                    Label(r.distanceString, systemImage: "ruler")
                    Label(r.durationString, systemImage: "clock")
                }
            case .planned(let r):
                HStack(spacing: 12) {
                    Label(r.distanceString, systemImage: "ruler")
                    Label("\(r.waypoints.count) pts", systemImage: "mappin")
                }
            }
        }

        private func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Route Row

struct RouteRow: View {
    let route: BreadcrumbRoute
    var onToggleVisibility: (() -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(route.name ?? "Untitled Route")
                    .font(.headline)

                HStack(spacing: 12) {
                    Label(route.distanceString, systemImage: "ruler")
                    Label(route.durationString, systemImage: "clock")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Text(formatDate(route.startTime))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { route.isVisible },
                set: { _ in onToggleVisibility?() }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Planned Route Row

struct PlannedRouteRow: View {
    let route: PlannedRoute
    var onToggleVisibility: (() -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(route.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label(route.distanceString, systemImage: "ruler")
                    Label("\(route.waypoints.count) waypoints", systemImage: "mappin")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Text(formatDate(route.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { route.isVisible },
                set: { _ in onToggleVisibility?() }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("Map Controls") {
    ZStack {
        Color.gray.opacity(0.3)
        HStack {
            Spacer()
            MapControlsView()
        }
        .padding()
    }
}

#Preview("Routes List") {
    RoutesListSheet()
}
