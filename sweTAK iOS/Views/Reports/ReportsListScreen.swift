import SwiftUI

/// Screen showing list of PEDARS reports with tabs for Incoming and Outgoing.
/// Mirrors Android ReportsListScreen functionality.
public struct ReportsListScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var reportsVM = ReportsViewModel.shared

    @State private var selectedTab = 0
    @State private var selectedReport: Report?
    @State private var showingDetail = false
    @State private var showingCreate = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("", selection: $selectedTab) {
                    HStack {
                        Text("Incoming (\(reportsVM.incomingReports.count))")
                        if reportsVM.unreadIncomingCount > 0 {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .tag(0)

                    Text("Outgoing (\(reportsVM.outgoingReports.count))")
                        .tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                if selectedTab == 0 {
                    incomingList
                } else {
                    outgoingList
                }
            }
            .navigationTitle("PEDARS Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let report = selectedReport {
                    ReportDetailScreen(report: report)
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateReportScreen()
            }
        }
    }

    private var incomingList: some View {
        Group {
            if reportsVM.incomingReports.isEmpty {
                emptyState(
                    icon: "doc.text",
                    title: "No incoming reports",
                    subtitle: "PEDARS reports sent to you will appear here."
                )
            } else {
                List {
                    ForEach(reportsVM.incomingReports) { report in
                        ReportListRow(report: report, statuses: [])
                            .onTapGesture {
                                reportsVM.markAsRead(reportId: report.id)
                                selectedReport = report
                                showingDetail = true
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let report = reportsVM.incomingReports[index]
                            reportsVM.deleteReport(reportId: report.id)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var outgoingList: some View {
        Group {
            if reportsVM.outgoingReports.isEmpty {
                emptyState(
                    icon: "paperplane",
                    title: "No outgoing reports",
                    subtitle: "PEDARS reports you send will appear here."
                )
            } else {
                List {
                    ForEach(reportsVM.outgoingReports) { report in
                        let statuses = reportsVM.getStatusesForReport(reportId: report.id)
                        ReportListRow(report: report, statuses: statuses)
                            .onTapGesture {
                                selectedReport = report
                                showingDetail = true
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let report = reportsVM.outgoingReports[index]
                            reportsVM.deleteReport(reportId: report.id)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Report List Row

private struct ReportListRow: View {
    let report: Report
    let statuses: [ReportRecipientStatus]

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        return formatter
    }

    var body: some View {
        HStack(spacing: 12) {
            // Unread indicator
            if report.direction == .incoming && !report.isRead {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Readiness badge
                    ReadinessBadge(readiness: report.readiness)

                    Spacer()

                    Text(dateFormatter.string(from: Date(timeIntervalSince1970: Double(report.createdAtMillis) / 1000)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if report.direction == .incoming {
                    Text("From: \(report.senderCallsign.isEmpty ? String(report.senderDeviceId.prefix(8)) : report.senderCallsign)")
                        .font(.subheadline)
                } else {
                    let totalRecipients = report.recipientDeviceIds.count
                    let deliveredCount = statuses.filter { $0.isDelivered }.count
                    let readCount = statuses.filter { $0.isRead }.count

                    Text("To: \(totalRecipients) recipient\(totalRecipients == 1 ? "" : "s")")
                        .font(.subheadline)

                    if totalRecipients > 0 {
                        Text("Delivered: \(deliveredCount), Read: \(readCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Personnel summary
                Text("Personnel: \(report.capableCount) capable, \(report.woundedCount) wounded, \(report.deadCount) dead")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Readiness Badge

private struct ReadinessBadge: View {
    let readiness: ReadinessLevel

    private var textColor: Color {
        switch readiness {
        case .yellow:
            return Color(red: 0.475, green: 0.337, blue: 0) // Dark amber for better contrast
        default:
            return readiness.color
        }
    }

    var body: some View {
        Text(readiness.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(readiness.color.opacity(0.15))
            .cornerRadius(4)
    }
}

// MARK: - Section Header

private struct ReportsSectionHeader: View {
    let letter: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Text(letter)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .cornerRadius(4)

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Preview

#Preview("PEDARS List") {
    ReportsListScreen()
}
