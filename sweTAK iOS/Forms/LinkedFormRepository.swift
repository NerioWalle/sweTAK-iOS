import Foundation
import Combine
import os.log

// MARK: - Linked Form Repository

/// Repository for managing linked forms attached to OP pins
/// Provides CRUD operations and persistence
@MainActor
public final class LinkedFormRepository: ObservableObject {

    private static let logger = Logger(subsystem: "com.swetak", category: "LinkedFormRepository")

    // MARK: - Published State

    /// All linked forms
    @Published public private(set) var forms: [LinkedForm] = []

    /// Forms grouped by OP pin ID
    @Published public private(set) var formsByOpPin: [Int64: [LinkedForm]] = [:]

    // MARK: - Singleton

    public static let shared = LinkedFormRepository()

    // MARK: - Persistence Keys

    private static let linkedFormsKey = "linked_forms_v1"

    // MARK: - Initialization

    private init() {
        loadForms()
    }

    // MARK: - CRUD Operations

    /// Add a new linked form
    public func addForm(_ form: LinkedForm) {
        forms.append(form)
        updateGroupedForms()
        saveForms()
        Self.logger.info("Added linked form: type=\(form.formType), opPin=\(form.opPinId)")
    }

    /// Add multiple forms at once
    public func addForms(_ newForms: [LinkedForm]) {
        forms.append(contentsOf: newForms)
        updateGroupedForms()
        saveForms()
        Self.logger.info("Added \(newForms.count) linked forms")
    }

    /// Update an existing form
    public func updateForm(_ form: LinkedForm) {
        guard let index = forms.firstIndex(where: { $0.id == form.id }) else {
            Self.logger.warning("Form not found for update: \(form.id)")
            return
        }
        forms[index] = form
        updateGroupedForms()
        saveForms()
        Self.logger.info("Updated linked form: \(form.id)")
    }

    /// Delete a form by ID
    public func deleteForm(id: Int64) {
        forms.removeAll { $0.id == id }
        updateGroupedForms()
        saveForms()
        Self.logger.info("Deleted linked form: \(id)")
    }

    /// Delete all forms for a specific OP pin
    public func deleteFormsForOpPin(opPinId: Int64, opOriginDeviceId: String) {
        let beforeCount = forms.count
        forms.removeAll {
            $0.opPinId == opPinId && $0.opOriginDeviceId == opOriginDeviceId
        }
        let deletedCount = beforeCount - forms.count
        updateGroupedForms()
        saveForms()
        Self.logger.info("Deleted \(deletedCount) forms for OP pin: \(opPinId)")
    }

    /// Delete all forms
    public func deleteAllForms() {
        forms.removeAll()
        formsByOpPin.removeAll()
        saveForms()
        Self.logger.info("Deleted all linked forms")
    }

    // MARK: - Queries

    /// Get all forms for a specific OP pin
    public func formsForOpPin(opPinId: Int64, opOriginDeviceId: String) -> [LinkedForm] {
        return forms.filter {
            $0.opPinId == opPinId && $0.opOriginDeviceId == opOriginDeviceId
        }.sorted { $0.submittedAtMillis > $1.submittedAtMillis }
    }

    /// Get forms by type
    public func formsByType(_ type: LinkedFormType) -> [LinkedForm] {
        return forms.filter { $0.formType == type.rawValue }
            .sorted { $0.submittedAtMillis > $1.submittedAtMillis }
    }

    /// Get forms by type string
    public func formsByType(_ typeString: String) -> [LinkedForm] {
        return forms.filter { $0.formType == typeString }
            .sorted { $0.submittedAtMillis > $1.submittedAtMillis }
    }

    /// Get forms by author
    public func formsByAuthor(_ callsign: String) -> [LinkedForm] {
        return forms.filter {
            $0.authorCallsign.lowercased() == callsign.lowercased()
        }.sorted { $0.submittedAtMillis > $1.submittedAtMillis }
    }

    /// Get recent forms (last N)
    public func recentForms(limit: Int = 20) -> [LinkedForm] {
        return Array(
            forms.sorted { $0.submittedAtMillis > $1.submittedAtMillis }
                .prefix(limit)
        )
    }

    /// Get forms within time range
    public func formsInTimeRange(start: Int64, end: Int64) -> [LinkedForm] {
        return forms.filter {
            $0.submittedAtMillis >= start && $0.submittedAtMillis <= end
        }.sorted { $0.submittedAtMillis > $1.submittedAtMillis }
    }

    /// Find form by ID
    public func findForm(id: Int64) -> LinkedForm? {
        return forms.first { $0.id == id }
    }

    /// Check if OP pin has any linked forms
    public func hasFormsForOpPin(opPinId: Int64, opOriginDeviceId: String) -> Bool {
        return forms.contains {
            $0.opPinId == opPinId && $0.opOriginDeviceId == opOriginDeviceId
        }
    }

    /// Count forms for OP pin
    public func formCountForOpPin(opPinId: Int64, opOriginDeviceId: String) -> Int {
        return forms.filter {
            $0.opPinId == opPinId && $0.opOriginDeviceId == opOriginDeviceId
        }.count
    }

    // MARK: - Form Creation Helpers

    /// Create and add a Call for Fire form
    public func createCallForFire(
        opPinId: Int64,
        opOriginDeviceId: String,
        authorCallsign: String,
        data: CallForFireData,
        targetCoordinate: (lat: Double, lon: Double)? = nil,
        observerCoordinate: (lat: Double, lon: Double)? = nil
    ) -> LinkedForm? {
        guard let formDataJson = data.toJSONString() else {
            Self.logger.error("Failed to serialize CFF data")
            return nil
        }

        let form = LinkedForm(
            id: LinkedForm.generateId(),
            opPinId: opPinId,
            opOriginDeviceId: opOriginDeviceId,
            formType: LinkedFormType.callForFire.rawValue,
            formData: formDataJson,
            authorCallsign: authorCallsign,
            targetLat: targetCoordinate?.lat,
            targetLon: targetCoordinate?.lon,
            observerLat: observerCoordinate?.lat,
            observerLon: observerCoordinate?.lon
        )

        addForm(form)
        return form
    }

    /// Create and add a Spot Report form
    public func createSpotReport(
        opPinId: Int64,
        opOriginDeviceId: String,
        authorCallsign: String,
        data: SpotReportData,
        targetCoordinate: (lat: Double, lon: Double)? = nil,
        observerCoordinate: (lat: Double, lon: Double)? = nil
    ) -> LinkedForm? {
        guard let formDataJson = data.toJSONString() else {
            Self.logger.error("Failed to serialize spot report data")
            return nil
        }

        let form = LinkedForm(
            id: LinkedForm.generateId(),
            opPinId: opPinId,
            opOriginDeviceId: opOriginDeviceId,
            formType: LinkedFormType.spot.rawValue,
            formData: formDataJson,
            authorCallsign: authorCallsign,
            targetLat: targetCoordinate?.lat,
            targetLon: targetCoordinate?.lon,
            observerLat: observerCoordinate?.lat,
            observerLon: observerCoordinate?.lon
        )

        addForm(form)
        return form
    }

    /// Create and add a Contact Report form
    public func createContactReport(
        opPinId: Int64,
        opOriginDeviceId: String,
        authorCallsign: String,
        data: ContactReportData,
        targetCoordinate: (lat: Double, lon: Double)? = nil,
        observerCoordinate: (lat: Double, lon: Double)? = nil
    ) -> LinkedForm? {
        guard let formDataJson = data.toJSONString() else {
            Self.logger.error("Failed to serialize contact report data")
            return nil
        }

        let form = LinkedForm(
            id: LinkedForm.generateId(),
            opPinId: opPinId,
            opOriginDeviceId: opOriginDeviceId,
            formType: LinkedFormType.contact.rawValue,
            formData: formDataJson,
            authorCallsign: authorCallsign,
            targetLat: targetCoordinate?.lat,
            targetLon: targetCoordinate?.lon,
            observerLat: observerCoordinate?.lat,
            observerLon: observerCoordinate?.lon
        )

        addForm(form)
        return form
    }

    /// Create and add an Observation Note
    public func createObservation(
        opPinId: Int64,
        opOriginDeviceId: String,
        authorCallsign: String,
        data: ObservationNoteData,
        observerCoordinate: (lat: Double, lon: Double)? = nil
    ) -> LinkedForm? {
        guard let formDataJson = data.toJSONString() else {
            Self.logger.error("Failed to serialize observation data")
            return nil
        }

        let form = LinkedForm(
            id: LinkedForm.generateId(),
            opPinId: opPinId,
            opOriginDeviceId: opOriginDeviceId,
            formType: LinkedFormType.observation.rawValue,
            formData: formDataJson,
            authorCallsign: authorCallsign,
            observerLat: observerCoordinate?.lat,
            observerLon: observerCoordinate?.lon
        )

        addForm(form)
        return form
    }

    /// Create and add a Fire Adjustment form
    public func createFireAdjustment(
        opPinId: Int64,
        opOriginDeviceId: String,
        authorCallsign: String,
        data: FireAdjustmentData
    ) -> LinkedForm? {
        guard let formDataJson = data.toJSONString() else {
            Self.logger.error("Failed to serialize fire adjustment data")
            return nil
        }

        let form = LinkedForm(
            id: LinkedForm.generateId(),
            opPinId: opPinId,
            opOriginDeviceId: opOriginDeviceId,
            formType: LinkedFormType.adjustment.rawValue,
            formData: formDataJson,
            authorCallsign: authorCallsign
        )

        addForm(form)
        return form
    }

    // MARK: - Persistence

    /// Load forms from UserDefaults
    private func loadForms() {
        guard let data = UserDefaults.standard.data(forKey: Self.linkedFormsKey),
              let decoded = try? JSONDecoder().decode([LinkedForm].self, from: data) else {
            Self.logger.info("No saved linked forms found")
            return
        }

        forms = decoded
        updateGroupedForms()
        Self.logger.info("Loaded \(forms.count) linked forms")
    }

    /// Save forms to UserDefaults
    private func saveForms() {
        guard let data = try? JSONEncoder().encode(forms) else {
            Self.logger.error("Failed to encode linked forms")
            return
        }

        UserDefaults.standard.set(data, forKey: Self.linkedFormsKey)
    }

    /// Update grouped forms dictionary
    private func updateGroupedForms() {
        formsByOpPin = Dictionary(grouping: forms) { $0.opPinId }
    }

    // MARK: - Import/Export

    /// Export forms as JSON data for sync
    public func exportForms() -> Data? {
        return try? JSONEncoder().encode(forms)
    }

    /// Export forms for specific OP pin
    public func exportFormsForOpPin(opPinId: Int64, opOriginDeviceId: String) -> Data? {
        let pinForms = formsForOpPin(opPinId: opPinId, opOriginDeviceId: opOriginDeviceId)
        return try? JSONEncoder().encode(pinForms)
    }

    /// Import forms from JSON data
    public func importForms(_ data: Data, merge: Bool = true) -> Int {
        guard let imported = try? JSONDecoder().decode([LinkedForm].self, from: data) else {
            Self.logger.error("Failed to decode imported forms")
            return 0
        }

        if merge {
            // Merge: add forms that don't exist by ID
            let existingIds = Set(forms.map { $0.id })
            let newForms = imported.filter { !existingIds.contains($0.id) }
            forms.append(contentsOf: newForms)
            updateGroupedForms()
            saveForms()
            Self.logger.info("Merged \(newForms.count) new forms")
            return newForms.count
        } else {
            // Replace all
            forms = imported
            updateGroupedForms()
            saveForms()
            Self.logger.info("Replaced with \(imported.count) forms")
            return imported.count
        }
    }
}

// MARK: - Form Statistics

extension LinkedFormRepository {

    /// Statistics about linked forms
    public struct FormStatistics {
        public let totalCount: Int
        public let countByType: [String: Int]
        public let countByAuthor: [String: Int]
        public let oldestForm: LinkedForm?
        public let newestForm: LinkedForm?
        public let opPinsWithForms: Int
    }

    /// Get statistics about current forms
    public var statistics: FormStatistics {
        let byType = Dictionary(grouping: forms) { $0.formType }
            .mapValues { $0.count }

        let byAuthor = Dictionary(grouping: forms) { $0.authorCallsign }
            .mapValues { $0.count }

        let sorted = forms.sorted { $0.submittedAtMillis < $1.submittedAtMillis }

        return FormStatistics(
            totalCount: forms.count,
            countByType: byType,
            countByAuthor: byAuthor,
            oldestForm: sorted.first,
            newestForm: sorted.last,
            opPinsWithForms: formsByOpPin.keys.count
        )
    }
}
