import Foundation
import Combine
import CoreLocation

/// ViewModel for managing breadcrumb and planned routes
/// Centralizes route state, persistence, and visibility
public final class RoutesViewModel: ObservableObject {

    // MARK: - Singleton

    public static let shared = RoutesViewModel()

    // MARK: - Published Properties

    @Published public private(set) var breadcrumbRoutes: [BreadcrumbRoute] = []
    @Published public private(set) var plannedRoutes: [PlannedRoute] = []
    @Published public private(set) var activeRecordingRoute: BreadcrumbRoute?

    // MARK: - Constants

    private let breadcrumbRoutesKey = "swetak_breadcrumb_routes"
    private let plannedRoutesKey = "swetak_planned_routes"
    private let maxBreadcrumbRoutes = 50
    private let maxPlannedRoutes = 50

    // MARK: - Initialization

    private init() {
        loadRoutes()
    }

    // MARK: - Breadcrumb Route Management

    /// Add a new breadcrumb route
    public func addBreadcrumbRoute(_ route: BreadcrumbRoute) {
        var updatedRoutes = breadcrumbRoutes
        updatedRoutes.insert(route, at: 0)

        // Limit to max routes
        if updatedRoutes.count > maxBreadcrumbRoutes {
            updatedRoutes = Array(updatedRoutes.prefix(maxBreadcrumbRoutes))
        }

        breadcrumbRoutes = updatedRoutes
        saveBreadcrumbRoutes()
    }

    /// Update an existing breadcrumb route
    public func updateBreadcrumbRoute(_ route: BreadcrumbRoute) {
        guard let index = breadcrumbRoutes.firstIndex(where: { $0.id == route.id }) else {
            return
        }
        breadcrumbRoutes[index] = route
        saveBreadcrumbRoutes()
    }

    /// Delete a breadcrumb route
    public func deleteBreadcrumbRoute(id: String) {
        breadcrumbRoutes.removeAll { $0.id == id }
        saveBreadcrumbRoutes()
    }

    /// Delete breadcrumb routes at indices
    public func deleteBreadcrumbRoutes(at offsets: IndexSet) {
        breadcrumbRoutes.remove(atOffsets: offsets)
        saveBreadcrumbRoutes()
    }

    /// Toggle visibility of a breadcrumb route
    public func toggleBreadcrumbVisibility(id: String) {
        guard let index = breadcrumbRoutes.firstIndex(where: { $0.id == id }) else {
            return
        }
        var route = breadcrumbRoutes[index]
        route.isVisible.toggle()
        breadcrumbRoutes[index] = route
        saveBreadcrumbRoutes()
    }

    /// Get all visible breadcrumb routes
    public var visibleBreadcrumbRoutes: [BreadcrumbRoute] {
        breadcrumbRoutes.filter { $0.isVisible }
    }

    // MARK: - Planned Route Management

    /// Add a new planned route
    public func addPlannedRoute(_ route: PlannedRoute) {
        var updatedRoutes = plannedRoutes
        updatedRoutes.insert(route, at: 0)

        // Limit to max routes
        if updatedRoutes.count > maxPlannedRoutes {
            updatedRoutes = Array(updatedRoutes.prefix(maxPlannedRoutes))
        }

        plannedRoutes = updatedRoutes
        savePlannedRoutes()
    }

    /// Update an existing planned route
    public func updatePlannedRoute(_ route: PlannedRoute) {
        guard let index = plannedRoutes.firstIndex(where: { $0.id == route.id }) else {
            return
        }
        plannedRoutes[index] = route
        savePlannedRoutes()
    }

    /// Delete a planned route
    public func deletePlannedRoute(id: String) {
        plannedRoutes.removeAll { $0.id == id }
        savePlannedRoutes()
    }

    /// Delete planned routes at indices
    public func deletePlannedRoutes(at offsets: IndexSet) {
        plannedRoutes.remove(atOffsets: offsets)
        savePlannedRoutes()
    }

    /// Toggle visibility of a planned route
    public func togglePlannedRouteVisibility(id: String) {
        guard let index = plannedRoutes.firstIndex(where: { $0.id == id }) else {
            return
        }
        var route = plannedRoutes[index]
        route.isVisible.toggle()
        plannedRoutes[index] = route
        savePlannedRoutes()
    }

    /// Get all visible planned routes
    public var visiblePlannedRoutes: [PlannedRoute] {
        plannedRoutes.filter { $0.isVisible }
    }

    // MARK: - Statistics

    /// Total count of all routes
    public var totalRouteCount: Int {
        breadcrumbRoutes.count + plannedRoutes.count
    }

    /// Total distance of all breadcrumb routes in meters
    public var totalBreadcrumbDistance: Float {
        breadcrumbRoutes.reduce(0) { $0 + $1.totalDistanceMeters }
    }

    /// Total distance of all planned routes in meters
    public var totalPlannedDistance: Float {
        plannedRoutes.reduce(0) { sum, route in
            sum + route.totalDistanceMeters
        }
    }

    // MARK: - Persistence

    private func loadRoutes() {
        // Load breadcrumb routes
        if let data = UserDefaults.standard.data(forKey: breadcrumbRoutesKey),
           let routes = try? JSONDecoder().decode([BreadcrumbRoute].self, from: data) {
            breadcrumbRoutes = routes
        }

        // Load planned routes
        if let data = UserDefaults.standard.data(forKey: plannedRoutesKey),
           let routes = try? JSONDecoder().decode([PlannedRoute].self, from: data) {
            plannedRoutes = routes
        }
    }

    private func saveBreadcrumbRoutes() {
        if let data = try? JSONEncoder().encode(breadcrumbRoutes) {
            UserDefaults.standard.set(data, forKey: breadcrumbRoutesKey)
        }
    }

    private func savePlannedRoutes() {
        if let data = try? JSONEncoder().encode(plannedRoutes) {
            UserDefaults.standard.set(data, forKey: plannedRoutesKey)
        }
    }

    /// Clear all routes (for testing or reset)
    public func clearAllRoutes() {
        breadcrumbRoutes = []
        plannedRoutes = []
        UserDefaults.standard.removeObject(forKey: breadcrumbRoutesKey)
        UserDefaults.standard.removeObject(forKey: plannedRoutesKey)
    }

    // MARK: - Route Import/Export

    /// Export all routes as JSON data
    public func exportRoutes() -> Data? {
        let exportData = RouteExportData(
            breadcrumbRoutes: breadcrumbRoutes,
            plannedRoutes: plannedRoutes,
            exportedAt: Date()
        )
        return try? JSONEncoder().encode(exportData)
    }

    /// Import routes from JSON data
    public func importRoutes(from data: Data) -> Bool {
        guard let importData = try? JSONDecoder().decode(RouteExportData.self, from: data) else {
            return false
        }

        // Merge with existing routes
        for route in importData.breadcrumbRoutes {
            if !breadcrumbRoutes.contains(where: { $0.id == route.id }) {
                breadcrumbRoutes.append(route)
            }
        }

        for route in importData.plannedRoutes {
            if !plannedRoutes.contains(where: { $0.id == route.id }) {
                plannedRoutes.append(route)
            }
        }

        saveBreadcrumbRoutes()
        savePlannedRoutes()

        return true
    }
}

// MARK: - Route Export Data

/// Container for exporting/importing routes
private struct RouteExportData: Codable {
    let breadcrumbRoutes: [BreadcrumbRoute]
    let plannedRoutes: [PlannedRoute]
    let exportedAt: Date
}

// Note: PlannedRoute.totalDistanceMeters is defined in LocationManager.swift
