import Foundation
import Combine
import os.log

/// ViewModel for managing PEDARS status reports.
/// Mirrors Android's ReportsViewModel functionality.
public final class ReportsViewModel: ObservableObject {

    // MARK: - Singleton

    public static let shared = ReportsViewModel()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "ReportsViewModel")

    // MARK: - Published State

    @Published public private(set) var reports: [Report] = []
    @Published public private(set) var recipientStatuses: [ReportRecipientStatus] = []
    @Published public private(set) var unreadIncomingCount: Int = 0

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let reports = "swetak_reports"
        static let reportStatuses = "swetak_report_statuses"
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
        TransportCoordinator.shared.reportListener = self
    }

    // MARK: - Computed Properties

    public var incomingReports: [Report] {
        reports
            .filter { $0.direction == .incoming }
            .sorted { $0.createdAtMillis > $1.createdAtMillis }
    }

    public var outgoingReports: [Report] {
        reports
            .filter { $0.direction == .outgoing }
            .sorted { $0.createdAtMillis > $1.createdAtMillis }
    }

    // MARK: - Report Management

    /// Send a new PEDARS report.
    public func sendReport(_ report: Report) {
        var outgoingReport = report
        // Ensure direction is outgoing for sent reports
        if outgoingReport.direction != .outgoing {
            outgoingReport = Report(
                id: report.id,
                createdAtMillis: report.createdAtMillis,
                senderDeviceId: report.senderDeviceId,
                senderCallsign: report.senderCallsign,
                woundedCount: report.woundedCount,
                deadCount: report.deadCount,
                capableCount: report.capableCount,
                replenishment: report.replenishment,
                fuel: report.fuel,
                ammunition: report.ammunition,
                equipment: report.equipment,
                readiness: report.readiness,
                readinessDetails: report.readinessDetails,
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
            let status = ReportRecipientStatus(
                reportId: outgoingReport.id,
                recipientDeviceId: recipientId,
                recipientCallsign: ContactsViewModel.shared.contacts.first { $0.deviceId == recipientId }?.callsign,
                sentAtMillis: Date.currentMillis
            )
            recipientStatuses.append(status)
        }
        saveStatuses()

        // Send via transport
        TransportCoordinator.shared.sendReport(outgoingReport)

        logger.info("Sent PEDARS report: \(outgoingReport.id) to \(outgoingReport.recipientDeviceIds.count) recipients")
    }

    /// Add a received PEDARS report.
    public func addReceivedReport(_ report: Report) {
        // Avoid duplicates
        guard !reports.contains(where: { $0.id == report.id }) else {
            logger.debug("Duplicate PEDARS report received, ignoring: \(report.id)")
            return
        }

        // Create incoming report
        let incomingReport = Report(
            id: report.id,
            createdAtMillis: report.createdAtMillis,
            senderDeviceId: report.senderDeviceId,
            senderCallsign: report.senderCallsign,
            woundedCount: report.woundedCount,
            deadCount: report.deadCount,
            capableCount: report.capableCount,
            replenishment: report.replenishment,
            fuel: report.fuel,
            ammunition: report.ammunition,
            equipment: report.equipment,
            readiness: report.readiness,
            readinessDetails: report.readinessDetails,
            recipientDeviceIds: report.recipientDeviceIds,
            direction: .incoming,
            isRead: false
        )

        reports.append(incomingReport)
        saveReports()
        updateUnreadCount()

        // Send delivery ACK
        sendAck(reportId: incomingReport.id, toDeviceId: incomingReport.senderDeviceId, ackType: .delivered)

        logger.info("Received PEDARS report: \(incomingReport.id) from \(incomingReport.senderCallsign)")
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

        logger.debug("Marked PEDARS report as read: \(reportId)")
    }

    /// Delete a report.
    public func deleteReport(reportId: String) {
        reports.removeAll { $0.id == reportId }
        recipientStatuses.removeAll { $0.reportId == reportId }
        saveReports()
        saveStatuses()
        updateUnreadCount()

        logger.debug("Deleted PEDARS report: \(reportId)")
    }

    /// Get a report by ID.
    public func getReport(id: String) -> Report? {
        reports.first { $0.id == id }
    }

    /// Get recipient statuses for a report.
    public func getStatusesForReport(reportId: String) -> [ReportRecipientStatus] {
        recipientStatuses.filter { $0.reportId == reportId }
    }

    // MARK: - ACK Handling

    private func sendAck(reportId: String, toDeviceId: String, ackType: ReportAckType) {
        let ack = ReportAck(
            reportId: reportId,
            fromDeviceId: TransportCoordinator.shared.deviceId,
            toDeviceId: toDeviceId,
            ackType: ackType
        )
        TransportCoordinator.shared.sendReportAck(ack)
        logger.debug("Sent PEDARS ACK: \(ackType.rawValue) for report \(reportId)")
    }

    /// Handle received ACK.
    public func handleReceivedAck(_ ack: ReportAck) {
        guard let statusIndex = recipientStatuses.firstIndex(where: {
            $0.reportId == ack.reportId && $0.recipientDeviceId == ack.fromDeviceId
        }) else {
            logger.warning("Received ACK for unknown recipient status: \(ack.reportId)")
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

        logger.debug("Updated PEDARS status: \(ack.ackType.rawValue) for report \(ack.reportId)")
    }

    // MARK: - Persistence

    private func saveReports() {
        do {
            let data = try JSONEncoder().encode(reports)
            UserDefaults.standard.set(data, forKey: Keys.reports)
        } catch {
            logger.error("Failed to save PEDARS reports: \(error.localizedDescription)")
        }
    }

    private func loadReports() {
        guard let data = UserDefaults.standard.data(forKey: Keys.reports) else { return }
        do {
            reports = try JSONDecoder().decode([Report].self, from: data)
        } catch {
            logger.error("Failed to load PEDARS reports: \(error.localizedDescription)")
        }
    }

    private func saveStatuses() {
        do {
            let data = try JSONEncoder().encode(recipientStatuses)
            UserDefaults.standard.set(data, forKey: Keys.reportStatuses)
        } catch {
            logger.error("Failed to save PEDARS statuses: \(error.localizedDescription)")
        }
    }

    private func loadStatuses() {
        guard let data = UserDefaults.standard.data(forKey: Keys.reportStatuses) else { return }
        do {
            recipientStatuses = try JSONDecoder().decode([ReportRecipientStatus].self, from: data)
        } catch {
            logger.error("Failed to load PEDARS statuses: \(error.localizedDescription)")
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

// MARK: - ReportListener

extension ReportsViewModel: ReportListener {
    public func onReportReceived(report: Report) {
        DispatchQueue.main.async { [weak self] in
            self?.addReceivedReport(report)
        }
    }

    public func onReportAckReceived(ack: ReportAck) {
        DispatchQueue.main.async { [weak self] in
            self?.handleReceivedAck(ack)
        }
    }
}
