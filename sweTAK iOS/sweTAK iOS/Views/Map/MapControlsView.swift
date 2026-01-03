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
    @State private var selectedTab = 0

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Breadcrumbs (\(routesVM.breadcrumbRoutes.count))").tag(0)
                    Text("Planned (\(routesVM.plannedRoutes.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == 0 {
                    breadcrumbsList
                } else {
                    plannedRoutesList
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

    private var breadcrumbsList: some View {
        Group {
            if routesVM.breadcrumbRoutes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No recorded routes")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(routesVM.breadcrumbRoutes) { route in
                        RouteRow(route: route, onToggleVisibility: {
                            routesVM.toggleBreadcrumbVisibility(id: route.id)
                        })
                    }
                    .onDelete { offsets in
                        routesVM.deleteBreadcrumbRoutes(at: offsets)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var plannedRoutesList: some View {
        Group {
            if routesVM.plannedRoutes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No planned routes")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(routesVM.plannedRoutes) { route in
                        PlannedRouteRow(route: route, onToggleVisibility: {
                            routesVM.togglePlannedRouteVisibility(id: route.id)
                        })
                    }
                    .onDelete { offsets in
                        routesVM.deletePlannedRoutes(at: offsets)
                    }
                }
                .listStyle(.plain)
            }
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
