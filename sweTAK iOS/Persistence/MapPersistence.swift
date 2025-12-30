import Foundation
import CoreLocation

// MARK: - Map Persistence

/// Comprehensive persistence layer for map-related data
/// Mirrors Android MapPersistence.kt functionality
public final class MapPersistence {

    // MARK: - Singleton

    public static let shared = MapPersistence()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let contacts = "swetak.contacts"
        static let blockedDevices = "swetak.blocked_devices"
        static let pins = "swetak.pins"
        static let breadcrumbRoutes = "swetak.breadcrumb_routes"
        static let plannedRoutes = "swetak.planned_routes"
        static let orders = "swetak.orders"
        static let reports = "swetak.reports"
        static let methaneRequests = "swetak.methane_requests"
        static let medevacReports = "swetak.medevac_reports"
        static let photos = "swetak.photos"
        static let chatMessages = "swetak.chat_messages"
        static let settings = "swetak.settings"
    }

    // MARK: - Private

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.swetak.persistence", qos: .utility)

    // MARK: - Init

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .millisecondsSince1970
        decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    // MARK: - Contacts

    /// Saves contacts map (deviceId -> ContactProfile)
    public func saveContacts(_ contacts: [String: ContactProfile]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try self.encoder.encode(contacts)
                self.defaults.set(data, forKey: Keys.contacts)
            } catch {
                print("[MapPersistence] Failed to save contacts: \(error)")
            }
        }
    }

    /// Loads contacts map
    public func loadContacts() -> [String: ContactProfile] {
        guard let data = defaults.data(forKey: Keys.contacts) else { return [:] }
        do {
            return try decoder.decode([String: ContactProfile].self, from: data)
        } catch {
            print("[MapPersistence] Failed to load contacts: \(error)")
            return [:]
        }
    }

    /// Saves a single contact
    public func saveContact(_ contact: ContactProfile) {
        var contacts = loadContacts()
        contacts[contact.deviceId] = contact
        saveContacts(contacts)
    }

    /// Removes a contact
    public func removeContact(deviceId: String) {
        var contacts = loadContacts()
        contacts.removeValue(forKey: deviceId)
        saveContacts(contacts)
    }

    // MARK: - Blocked Devices

    /// Saves blocked device IDs
    public func saveBlockedDevices(_ deviceIds: Set<String>) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.defaults.set(Array(deviceIds), forKey: Keys.blockedDevices)
        }
    }

    /// Loads blocked device IDs
    public func loadBlockedDevices() -> Set<String> {
        let array = defaults.stringArray(forKey: Keys.blockedDevices) ?? []
        return Set(array)
    }

    /// Adds a blocked device
    public func blockDevice(_ deviceId: String) {
        var blocked = loadBlockedDevices()
        blocked.insert(deviceId)
        saveBlockedDevices(blocked)
    }

    /// Removes a blocked device
    public func unblockDevice(_ deviceId: String) {
        var blocked = loadBlockedDevices()
        blocked.remove(deviceId)
        saveBlockedDevices(blocked)
    }

    // MARK: - Pins

    /// Saves pins list
    public func savePins(_ pins: [PersistablePin]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try self.encoder.encode(pins)
                self.defaults.set(data, forKey: Keys.pins)
            } catch {
                print("[MapPersistence] Failed to save pins: \(error)")
            }
        }
    }

    /// Loads pins list
    public func loadPins() -> [PersistablePin] {
        guard let data = defaults.data(forKey: Keys.pins) else { return [] }
        do {
            return try decoder.decode([PersistablePin].self, from: data)
        } catch {
            print("[MapPersistence] Failed to load pins: \(error)")
            return []
        }
    }

    /// Adds a pin
    public func addPin(_ pin: PersistablePin) {
        var pins = loadPins()
        pins.append(pin)
        savePins(pins)
    }

    /// Removes a pin by ID
    public func removePin(id: String) {
        var pins = loadPins()
        pins.removeAll { $0.id == id }
        savePins(pins)
    }

    /// Updates a pin
    public func updatePin(_ pin: PersistablePin) {
        var pins = loadPins()
        if let index = pins.firstIndex(where: { $0.id == pin.id }) {
            pins[index] = pin
            savePins(pins)
        }
    }

    // MARK: - Breadcrumb Routes

    /// Saves breadcrumb routes
    public func saveBreadcrumbRoutes(_ routes: [PersistableBreadcrumbRoute]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try self.encoder.encode(routes)
                self.defaults.set(data, forKey: Keys.breadcrumbRoutes)
            } catch {
                print("[MapPersistence] Failed to save breadcrumb routes: \(error)")
            }
        }
    }

    /// Loads breadcrumb routes
    public func loadBreadcrumbRoutes() -> [PersistableBreadcrumbRoute] {
        guard let data = defaults.data(forKey: Keys.breadcrumbRoutes) else { return [] }
        do {
            return try decoder.decode([PersistableBreadcrumbRoute].self, from: data)
        } catch {
            print("[MapPersistence] Failed to load breadcrumb routes: \(error)")
            return []
        }
    }

    // MARK: - Planned Routes

    /// Saves planned routes
    public func savePlannedRoutes(_ routes: [PersistablePlannedRoute]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try self.encoder.encode(routes)
                self.defaults.set(data, forKey: Keys.plannedRoutes)
            } catch {
                print("[MapPersistence] Failed to save planned routes: \(error)")
            }
        }
    }

    /// Loads planned routes
    public func loadPlannedRoutes() -> [PersistablePlannedRoute] {
        guard let data = defaults.data(forKey: Keys.plannedRoutes) else { return [] }
        do {
            return try decoder.decode([PersistablePlannedRoute].self, from: data)
        } catch {
            print("[MapPersistence] Failed to load planned routes: \(error)")
            return []
        }
    }

    // MARK: - Orders

    /// Saves military orders
    public func saveOrders(_ orders: [PersistableOrder]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try self.encoder.encode(orders)
                self.defaults.set(data, forKey: Keys.orders)
            } catch {
                print("[MapPersistence] Failed to save orders: \(error)")
            }
        }
    }

    /// Loads military orders
    public func loadOrders() -> [PersistableOrder] {
        guard let data = defaults.data(forKey: Keys.orders) else { return [] }
        do {
            return try decoder.decode([PersistableOrder].self, from: data)
        } catch {
            print("[MapPersistence] Failed to load orders: \(error)")
            return []
        }
    }

    /// Adds an order
    public func addOrder(_ order: PersistableOrder) {
        var orders = loadOrders()
        orders.append(order)
        saveOrders(orders)
    }

    // MARK: - Reports

    /// Saves status reports
    public func saveReports(_ reports: [PersistableReport]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try self.encoder.encode(reports)
                self.defaults.set(data, forKey: Keys.reports)
            } catch {
                print("[MapPersistence] Failed to save reports: \(error)")
            }
        }
    }

    /// Loads status reports
    public func loadReports() -> [PersistableReport] {
        guard let data = defaults.data(forKey: Keys.reports) else { return [] }
        do {
            return try decoder.decode([PersistableReport].self, from: data)
        } catch {
            print("[MapPersistence] Failed to load reports: \(error)")
            return []
        }
    }

    /// Adds a report
    public func addReport(_ report: PersistableReport) {
        var reports = loadReports()
        reports.append(report)
        saveReports(reports)
    }

    // MARK: - METHANE Requests

    /// Saves METHANE emergency requests
    public func saveMethaneRequests(_ requests: [PersistableMethaneRequest]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try self.encoder.encode(requests)
                self.defaults.set(data, forKey: Keys.methaneRequests)
            } catch {
                print("[MapPersistence] Failed to save METHANE requests: \(error)")
            }
        }
    }

    /// Loads METHANE emergency requests
    public func loadMethaneRequests() -> [PersistableMethaneRequest] {
        guard let data = defaults.data(forKey: Keys.methaneRequests) else { return [] }
        do {
            return try decoder.decode([PersistableMethaneRequest].self, from: data)
        } catch {
            print("[MapPersistence] Failed to load METHANE requests: \(error)")
            return []
        }
    }

    /// Adds a METHANE request
    public func addMethaneRequest(_ request: PersistableMethaneRequest) {
        var requests = loadMethaneRequests()
        requests.append(request)
        saveMethaneRequests(requests)
    }

    // MARK: - MEDEVAC Reports

    /// Saves MEDEVAC handover reports
    public func saveMedevacReports(_ reports: [PersistableMedevacReport]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try self.encoder.encode(reports)
                self.defaults.set(data, forKey: Keys.medevacReports)
            } catch {
                print("[MapPersistence] Failed to save MEDEVAC reports: \(error)")
            }
        }
    }

    /// Loads MEDEVAC handover reports
    public func loadMedevacReports() -> [PersistableMedevacReport] {
        guard let data = defaults.data(forKey: Keys.medevacReports) else { return [] }
        do {
            return try decoder.decode([PersistableMedevacReport].self, from: data)
        } catch {
            print("[MapPersistence] Failed to load MEDEVAC reports: \(error)")
            return []
        }
    }

    /// Adds a MEDEVAC report
    public func addMedevacReport(_ report: PersistableMedevacReport) {
        var reports = loadMedevacReports()
        reports.append(report)
        saveMedevacReports(reports)
    }

    // MARK: - Photos

    /// Saves photo metadata
    public func savePhotoMetadata(_ photos: [PersistablePhotoMetadata]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try self.encoder.encode(photos)
                self.defaults.set(data, forKey: Keys.photos)
            } catch {
                print("[MapPersistence] Failed to save photo metadata: \(error)")
            }
        }
    }

    /// Loads photo metadata
    public func loadPhotoMetadata() -> [PersistablePhotoMetadata] {
        guard let data = defaults.data(forKey: Keys.photos) else { return [] }
        do {
            return try decoder.decode([PersistablePhotoMetadata].self, from: data)
        } catch {
            print("[MapPersistence] Failed to load photo metadata: \(error)")
            return []
        }
    }

    // MARK: - Chat Messages

    /// Saves chat messages for a conversation
    public func saveChatMessages(_ messages: [PersistableChatMessage], conversationId: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                var allChats = self.loadAllChatMessages()
                allChats[conversationId] = messages
                let data = try self.encoder.encode(allChats)
                self.defaults.set(data, forKey: Keys.chatMessages)
            } catch {
                print("[MapPersistence] Failed to save chat messages: \(error)")
            }
        }
    }

    /// Loads chat messages for a conversation
    public func loadChatMessages(conversationId: String) -> [PersistableChatMessage] {
        loadAllChatMessages()[conversationId] ?? []
    }

    /// Loads all chat messages
    private func loadAllChatMessages() -> [String: [PersistableChatMessage]] {
        guard let data = defaults.data(forKey: Keys.chatMessages) else { return [:] }
        do {
            return try decoder.decode([String: [PersistableChatMessage]].self, from: data)
        } catch {
            print("[MapPersistence] Failed to load chat messages: \(error)")
            return [:]
        }
    }

    // MARK: - Settings

    /// Saves app settings
    public func saveSettings(_ settings: PersistableSettings) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try self.encoder.encode(settings)
                self.defaults.set(data, forKey: Keys.settings)
            } catch {
                print("[MapPersistence] Failed to save settings: \(error)")
            }
        }
    }

    /// Loads app settings
    public func loadSettings() -> PersistableSettings {
        guard let data = defaults.data(forKey: Keys.settings) else {
            return PersistableSettings()
        }
        do {
            return try decoder.decode(PersistableSettings.self, from: data)
        } catch {
            print("[MapPersistence] Failed to load settings: \(error)")
            return PersistableSettings()
        }
    }

    // MARK: - Bulk Operations

    /// Clears all persisted data
    public func clearAll() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let keys = [
                Keys.contacts,
                Keys.blockedDevices,
                Keys.pins,
                Keys.breadcrumbRoutes,
                Keys.plannedRoutes,
                Keys.orders,
                Keys.reports,
                Keys.methaneRequests,
                Keys.medevacReports,
                Keys.photos,
                Keys.chatMessages
            ]
            keys.forEach { self.defaults.removeObject(forKey: $0) }
        }
    }

    /// Exports all data as JSON
    public func exportAllData() -> Data? {
        let export = ExportedData(
            contacts: loadContacts(),
            blockedDevices: loadBlockedDevices(),
            pins: loadPins(),
            breadcrumbRoutes: loadBreadcrumbRoutes(),
            plannedRoutes: loadPlannedRoutes(),
            orders: loadOrders(),
            reports: loadReports(),
            methaneRequests: loadMethaneRequests(),
            medevacReports: loadMedevacReports(),
            photos: loadPhotoMetadata(),
            settings: loadSettings()
        )

        do {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(export)
        } catch {
            print("[MapPersistence] Failed to export data: \(error)")
            return nil
        }
    }

    /// Imports data from JSON
    public func importData(_ data: Data) -> Bool {
        do {
            let imported = try decoder.decode(ExportedData.self, from: data)
            saveContacts(imported.contacts)
            saveBlockedDevices(imported.blockedDevices)
            savePins(imported.pins)
            saveBreadcrumbRoutes(imported.breadcrumbRoutes)
            savePlannedRoutes(imported.plannedRoutes)
            saveOrders(imported.orders)
            saveReports(imported.reports)
            saveMethaneRequests(imported.methaneRequests)
            saveMedevacReports(imported.medevacReports)
            savePhotoMetadata(imported.photos)
            saveSettings(imported.settings)
            return true
        } catch {
            print("[MapPersistence] Failed to import data: \(error)")
            return false
        }
    }
}

// MARK: - Persistable Models

/// Pin data for persistence
public struct PersistablePin: Codable, Identifiable {
    public let id: String
    public let latitude: Double
    public let longitude: Double
    public let natoType: String
    public let label: String?
    public let notes: String?
    public let createdAt: Date
    public let createdBy: String?
    public let photoId: String?

    public init(
        id: String = UUID().uuidString,
        latitude: Double,
        longitude: Double,
        natoType: String,
        label: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        createdBy: String? = nil,
        photoId: String? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.natoType = natoType
        self.label = label
        self.notes = notes
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.photoId = photoId
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Breadcrumb route for persistence
public struct PersistableBreadcrumbRoute: Codable, Identifiable {
    public let id: String
    public let deviceId: String
    public let callsign: String?
    public let points: [PersistableRoutePoint]
    public let color: String?
    public let lastUpdated: Date

    public init(
        id: String = UUID().uuidString,
        deviceId: String,
        callsign: String? = nil,
        points: [PersistableRoutePoint] = [],
        color: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.deviceId = deviceId
        self.callsign = callsign
        self.points = points
        self.color = color
        self.lastUpdated = lastUpdated
    }
}

/// Route point for persistence
public struct PersistableRoutePoint: Codable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double?
    public let timestamp: Date

    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        timestamp: Date = Date()
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Planned route for persistence
public struct PersistablePlannedRoute: Codable, Identifiable {
    public let id: String
    public let name: String
    public let waypoints: [PersistableWaypoint]
    public let createdAt: Date
    public let createdBy: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        waypoints: [PersistableWaypoint] = [],
        createdAt: Date = Date(),
        createdBy: String? = nil
    ) {
        self.id = id
        self.name = name
        self.waypoints = waypoints
        self.createdAt = createdAt
        self.createdBy = createdBy
    }
}

/// Waypoint for persistence
public struct PersistableWaypoint: Codable, Identifiable {
    public let id: String
    public let latitude: Double
    public let longitude: Double
    public let name: String?
    public let order: Int

    public init(
        id: String = UUID().uuidString,
        latitude: Double,
        longitude: Double,
        name: String? = nil,
        order: Int
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.order = order
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Military order for persistence
public struct PersistableOrder: Codable, Identifiable {
    public let id: String
    public let orderType: String // "OBO" or "5P"
    public let content: [String: String]
    public let createdAt: Date
    public let createdBy: String?
    public let latitude: Double?
    public let longitude: Double?

    public init(
        id: String = UUID().uuidString,
        orderType: String,
        content: [String: String],
        createdAt: Date = Date(),
        createdBy: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.orderType = orderType
        self.content = content
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Status report for persistence
public struct PersistableReport: Codable, Identifiable {
    public let id: String
    public let reportType: String // "7S", "IFS", "PEDARS", etc.
    public let content: [String: String]
    public let createdAt: Date
    public let createdBy: String?
    public let latitude: Double?
    public let longitude: Double?

    public init(
        id: String = UUID().uuidString,
        reportType: String,
        content: [String: String],
        createdAt: Date = Date(),
        createdBy: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.reportType = reportType
        self.content = content
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// METHANE emergency request for persistence
public struct PersistableMethaneRequest: Codable, Identifiable {
    public let id: String
    public let majorIncident: String
    public let exactLocation: String
    public let typeOfIncident: String
    public let hazards: String
    public let access: String
    public let numberOfCasualties: String
    public let emergencyServices: String
    public let createdAt: Date
    public let createdBy: String?
    public let latitude: Double?
    public let longitude: Double?

    public init(
        id: String = UUID().uuidString,
        majorIncident: String = "",
        exactLocation: String = "",
        typeOfIncident: String = "",
        hazards: String = "",
        access: String = "",
        numberOfCasualties: String = "",
        emergencyServices: String = "",
        createdAt: Date = Date(),
        createdBy: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.majorIncident = majorIncident
        self.exactLocation = exactLocation
        self.typeOfIncident = typeOfIncident
        self.hazards = hazards
        self.access = access
        self.numberOfCasualties = numberOfCasualties
        self.emergencyServices = emergencyServices
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// MEDEVAC handover report for persistence
public struct PersistableMedevacReport: Codable, Identifiable {
    public let id: String
    public let patientId: String?
    public let mechanism: String
    public let injuries: String
    public let signs: String
    public let treatment: String
    public let allergies: String?
    public let medications: String?
    public let pastHistory: String?
    public let lastOral: String?
    public let events: String?
    public let createdAt: Date
    public let createdBy: String?

    public init(
        id: String = UUID().uuidString,
        patientId: String? = nil,
        mechanism: String = "",
        injuries: String = "",
        signs: String = "",
        treatment: String = "",
        allergies: String? = nil,
        medications: String? = nil,
        pastHistory: String? = nil,
        lastOral: String? = nil,
        events: String? = nil,
        createdAt: Date = Date(),
        createdBy: String? = nil
    ) {
        self.id = id
        self.patientId = patientId
        self.mechanism = mechanism
        self.injuries = injuries
        self.signs = signs
        self.treatment = treatment
        self.allergies = allergies
        self.medications = medications
        self.pastHistory = pastHistory
        self.lastOral = lastOral
        self.events = events
        self.createdAt = createdAt
        self.createdBy = createdBy
    }
}

/// Photo metadata for persistence
public struct PersistablePhotoMetadata: Codable, Identifiable {
    public let id: String
    public let filename: String
    public let latitude: Double?
    public let longitude: Double?
    public let capturedAt: Date
    public let capturedBy: String?
    public let linkedPinId: String?
    public let base64Thumbnail: String?

    public init(
        id: String = UUID().uuidString,
        filename: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        capturedAt: Date = Date(),
        capturedBy: String? = nil,
        linkedPinId: String? = nil,
        base64Thumbnail: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.latitude = latitude
        self.longitude = longitude
        self.capturedAt = capturedAt
        self.capturedBy = capturedBy
        self.linkedPinId = linkedPinId
        self.base64Thumbnail = base64Thumbnail
    }
}

/// Chat message for persistence
public struct PersistableChatMessage: Codable, Identifiable {
    public let id: String
    public let conversationId: String
    public let senderId: String
    public let senderCallsign: String?
    public let content: String
    public let sentAt: Date
    public let isFromMe: Bool

    public init(
        id: String = UUID().uuidString,
        conversationId: String,
        senderId: String,
        senderCallsign: String? = nil,
        content: String,
        sentAt: Date = Date(),
        isFromMe: Bool
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderCallsign = senderCallsign
        self.content = content
        self.sentAt = sentAt
        self.isFromMe = isFromMe
    }
}

/// App settings for persistence
public struct PersistableSettings: Codable {
    public var coordMode: String
    public var mapType: String
    public var showBreadcrumbs: Bool
    public var showOtherUsers: Bool
    public var nightVisionEnabled: Bool
    public var nightVisionColor: String
    public var callsign: String?
    public var deviceId: String?

    public init(
        coordMode: String = "LATLON",
        mapType: String = "STANDARD",
        showBreadcrumbs: Bool = true,
        showOtherUsers: Bool = true,
        nightVisionEnabled: Bool = false,
        nightVisionColor: String = "GREEN",
        callsign: String? = nil,
        deviceId: String? = nil
    ) {
        self.coordMode = coordMode
        self.mapType = mapType
        self.showBreadcrumbs = showBreadcrumbs
        self.showOtherUsers = showOtherUsers
        self.nightVisionEnabled = nightVisionEnabled
        self.nightVisionColor = nightVisionColor
        self.callsign = callsign
        self.deviceId = deviceId
    }
}

/// Container for all exported data
private struct ExportedData: Codable {
    let contacts: [String: ContactProfile]
    let blockedDevices: Set<String>
    let pins: [PersistablePin]
    let breadcrumbRoutes: [PersistableBreadcrumbRoute]
    let plannedRoutes: [PersistablePlannedRoute]
    let orders: [PersistableOrder]
    let reports: [PersistableReport]
    let methaneRequests: [PersistableMethaneRequest]
    let medevacReports: [PersistableMedevacReport]
    let photos: [PersistablePhotoMetadata]
    let settings: PersistableSettings
}
