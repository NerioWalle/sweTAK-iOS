import Foundation
import Combine
import os.log

/// ViewModel for managing MEDEVAC handover reports.
/// Mirrors Android's MEDEVAC report management functionality.
public final class MedevacViewModel: ObservableObject {

    // MARK: - Singleton

    public static let shared = MedevacViewModel()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "MedevacViewModel")

    // MARK: - Published State

    @Published public private(set) var reports: [MedevacReport] = []
    @Published public private(set) var recipientStatuses: [MedevacRecipientStatus] = []
    @Published public private(set) var unreadIncomingCount: Int = 0

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let medevacReports = "swetak_medevac_reports"
        static let medevacStatuses = "swetak_medevac_statuses"
    }

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadReports()
        loadStatuses()
        updateUnreadCount()
        setupListeners()
    }

    // MARK: - Listeners

    private func setupListeners() {
        TransportCoordinator.shared.medevacListener = self
    }

    // MARK: - Computed Properties

    public var incomingReports: [MedevacReport] {
        reports
            .filter { $0.direction == .incoming }
            .sorted { $0.createdAtMillis > $1.createdAtMillis }
    }

    public var outgoingReports: [MedevacReport] {
        reports
            .filter { $0.direction == .outgoing }
            .sorted { $0.createdAtMillis > $1.createdAtMillis }
    }

    // MARK: - Report Management

    /// Send a new MEDEVAC report.
    public func sendMedevacReport(_ report: MedevacReport) {
        var outgoingReport = report
        // Ensure direction is outgoing for sent reports
        if outgoingReport.direction != .outgoing {
            outgoingReport = MedevacReport(
                id: report.id,
                createdAtMillis: report.createdAtMillis,
                senderDeviceId: report.senderDeviceId,
                senderCallsign: report.senderCallsign,
                soldierName: report.soldierName,
                priority: report.priority,
                ageInfo: report.ageInfo,
                incidentTime: report.incidentTime,
                mechanismOfInjury: report.mechanismOfInjury,
                injuryDescription: report.injuryDescription,
                signsSymptoms: report.signsSymptoms,
                pulse: report.pulse,
                bodyTemperature: report.bodyTemperature,
                treatmentActions: report.treatmentActions,
                medicinesGiven: report.medicinesGiven,
                caretakerName: report.caretakerName,
                recipientDeviceIds: report.recipientDeviceIds,
                direction: .outgoing,
                isRead: true
            )
        }

        // Add to local storage
        reports.append(outgoingReport)
        saveReports()

        // Create recipient statuses
        for recipientId in outgoingReport.recipientDeviceIds {
            let status = MedevacRecipientStatus(
                medevacId: outgoingReport.id,
                recipientDeviceId: recipientId,
                recipientCallsign: ContactsViewModel.shared.contacts.first { $0.deviceId == recipientId }?.callsign,
                sentAtMillis: Date.currentMillis
            )
            recipientStatuses.append(status)
        }
        saveStatuses()

        // Send via transport
        TransportCoordinator.shared.sendMedevac(outgoingReport)

        logger.info("Sent MEDEVAC report: \(outgoingReport.id) to \(outgoingReport.recipientDeviceIds.count) recipients")
    }

    /// Add a received MEDEVAC report.
    public func addReceivedReport(_ report: MedevacReport) {
        // Avoid duplicates
        guard !reports.contains(where: { $0.id == report.id }) else {
            logger.debug("Duplicate MEDEVAC report received, ignoring: \(report.id)")
            return
        }

        // Create incoming report
        let incomingReport = MedevacReport(
            id: report.id,
            createdAtMillis: report.createdAtMillis,
            senderDeviceId: report.senderDeviceId,
            senderCallsign: report.senderCallsign,
            soldierName: report.soldierName,
            priority: report.priority,
            ageInfo: report.ageInfo,
            incidentTime: report.incidentTime,
            mechanismOfInjury: report.mechanismOfInjury,
            injuryDescription: report.injuryDescription,
            signsSymptoms: report.signsSymptoms,
            pulse: report.pulse,
            bodyTemperature: report.bodyTemperature,
            treatmentActions: report.treatmentActions,
            medicinesGiven: report.medicinesGiven,
            caretakerName: report.caretakerName,
            recipientDeviceIds: report.recipientDeviceIds,
            direction: .incoming,
            isRead: false
        )

        reports.append(incomingReport)
        saveReports()
        updateUnreadCount()

        // Send delivery ACK
        sendAck(reportId: incomingReport.id, toDeviceId: incomingReport.senderDeviceId, ackType: .delivered)

        logger.info("Received MEDEVAC report: \(incomingReport.id) from \(incomingReport.senderCallsign)")
    }

    /// Mark a report as read.
    public func markAsRead(reportId: String) {
        guard let index = reports.firstIndex(where: { $0.id == reportId }) else { return }

        var report = reports[index]
        guard !report.isRead else { return }

        report.isRead = true
        reports[index] = report
        saveReports()
        updateUnreadCount()

        // Send read ACK for incoming reports
        if report.direction == .incoming {
            sendAck(reportId: reportId, toDeviceId: report.senderDeviceId, ackType: .read)
        }

        logger.debug("Marked MEDEVAC report as read: \(reportId)")
    }

    /// Delete a report.
    public func deleteReport(reportId: String) {
        reports.removeAll { $0.id == reportId }
        recipientStatuses.removeAll { $0.medevacId == reportId }
        saveReports()
        saveStatuses()
        updateUnreadCount()

        logger.debug("Deleted MEDEVAC report: \(reportId)")
    }

    /// Get a report by ID.
    public func getReport(id: String) -> MedevacReport? {
        reports.first { $0.id == id }
    }

    /// Get recipient statuses for a report.
    public func getStatusesForReport(reportId: String) -> [MedevacRecipientStatus] {
        recipientStatuses.filter { $0.medevacId == reportId }
    }

    // MARK: - ACK Handling

    private func sendAck(reportId: String, toDeviceId: String, ackType: MedevacAckType) {
        let ack = MedevacAck(
            medevacId: reportId,
            fromDeviceId: TransportCoordinator.shared.deviceId,
            toDeviceId: toDeviceId,
            ackType: ackType
        )
        TransportCoordinator.shared.sendMedevacAck(ack)
        logger.debug("Sent MEDEVAC ACK: \(ackType.rawValue) for report \(reportId)")
    }

    /// Handle received ACK.
    public func handleReceivedAck(_ ack: MedevacAck) {
        guard let statusIndex = recipientStatuses.firstIndex(where: {
            $0.medevacId == ack.medevacId && $0.recipientDeviceId == ack.fromDeviceId
        }) else {
            logger.warning("Received ACK for unknown recipient status: \(ack.medevacId)")
            return
        }

        var status = recipientStatuses[statusIndex]

        switch ack.ackType {
        case .delivered:
            status.deliveredAtMillis = ack.timestampMillis
        case .read:
            status.readAtMillis = ack.timestampMillis
        }

        recipientStatuses[statusIndex] = status
        saveStatuses()

        logger.debug("Updated MEDEVAC status: \(ack.ackType.rawValue) for report \(ack.medevacId)")
    }

    // MARK: - Persistence

    private func saveReports() {
        do {
            let data = try JSONEncoder().encode(reports)
            UserDefaults.standard.set(data, forKey: Keys.medevacReports)
        } catch {
            logger.error("Failed to save MEDEVAC reports: \(error.localizedDescription)")
        }
    }

    private func loadReports() {
        guard let data = UserDefaults.standard.data(forKey: Keys.medevacReports) else { return }
        do {
            reports = try JSONDecoder().decode([MedevacReport].self, from: data)
        } catch {
            logger.error("Failed to load MEDEVAC reports: \(error.localizedDescription)")
        }
    }

    private func saveStatuses() {
        do {
            let data = try JSONEncoder().encode(recipientStatuses)
            UserDefaults.standard.set(data, forKey: Keys.medevacStatuses)
        } catch {
            logger.error("Failed to save MEDEVAC statuses: \(error.localizedDescription)")
        }
    }

    private func loadStatuses() {
        guard let data = UserDefaults.standard.data(forKey: Keys.medevacStatuses) else { return }
        do {
            recipientStatuses = try JSONDecoder().decode([MedevacRecipientStatus].self, from: data)
        } catch {
            logger.error("Failed to load MEDEVAC statuses: \(error.localizedDescription)")
        }
    }

    private func updateUnreadCount() {
        unreadIncomingCount = incomingReports.filter { !$0.isRead }.count
    }

    // MARK: - Clear All

    public func clearAllReports() {
        reports.removeAll()
        recipientStatuses.removeAll()
        saveReports()
        saveStatuses()
        updateUnreadCount()
    }
}

// MARK: - MedevacListener

extension MedevacViewModel: MedevacListener {
    public func onMedevacReceived(medevac: MedevacReport) {
        DispatchQueue.main.async { [weak self] in
            self?.addReceivedReport(medevac)
        }
    }

    public func onMedevacAckReceived(ack: MedevacAck) {
        DispatchQueue.main.async { [weak self] in
            self?.handleReceivedAck(ack)
        }
    }
}
