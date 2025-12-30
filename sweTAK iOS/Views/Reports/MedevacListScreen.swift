import SwiftUI

/// Screen showing list of MEDEVAC/MIST reports with tabs for Incoming and Outgoing.
/// Mirrors Android MedevacListScreen functionality.
public struct MedevacListScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var medevacVM = MedevacViewModel.shared

    @State private var selectedTab = 0
    @State private var selectedReport: MedevacReport?
    @State private var showingDetail = false
    @State private var showingCreate = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("", selection: $selectedTab) {
                    HStack {
                        Text("Incoming (\(medevacVM.incomingReports.count))")
                        if medevacVM.unreadIncomingCount > 0 {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .tag(0)

                    Text("Outgoing (\(medevacVM.outgoingReports.count))")
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
            .navigationTitle("MIST Reports")
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
                    MedevacDetailScreen(report: report)
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateMedevacScreen()
            }
        }
    }

    private var incomingList: some View {
        Group {
            if medevacVM.incomingReports.isEmpty {
                emptyState(
                    icon: "cross.case",
                    title: "No incoming reports",
                    subtitle: "MIST reports sent to you will appear here."
                )
            } else {
                List {
                    ForEach(medevacVM.incomingReports) { report in
                        MedevacListRow(report: report, statuses: [])
                            .onTapGesture {
                                medevacVM.markAsRead(reportId: report.id)
                                selectedReport = report
                                showingDetail = true
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let report = medevacVM.incomingReports[index]
                            medevacVM.deleteReport(reportId: report.id)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var outgoingList: some View {
        Group {
            if medevacVM.outgoingReports.isEmpty {
                emptyState(
                    icon: "paperplane",
                    title: "No outgoing reports",
                    subtitle: "MIST reports you send will appear here."
                )
            } else {
                List {
                    ForEach(medevacVM.outgoingReports) { report in
                        let statuses = medevacVM.getStatusesForReport(reportId: report.id)
                        MedevacListRow(report: report, statuses: statuses)
                            .onTapGesture {
                                selectedReport = report
                                showingDetail = true
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let report = medevacVM.outgoingReports[index]
                            medevacVM.deleteReport(reportId: report.id)
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

// MARK: - Medevac List Row

struct MedevacListRow: View {
    let report: MedevacReport
    let statuses: [MedevacRecipientStatus]

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

            // Medical icon with priority color
            Image(systemName: "cross.case.fill")
                .font(.title2)
                .foregroundColor(report.priority.color)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Priority badge
                    PriorityBadge(priority: report.priority)

                    Spacer()

                    Text(dateFormatter.string(from: Date(timeIntervalSince1970: Double(report.createdAtMillis) / 1000)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Soldier name
                Text(report.soldierName)
                    .font(.headline)
                    .lineLimit(1)

                if report.direction == .incoming {
                    Text("From: \(report.senderCallsign.isEmpty ? String(report.senderDeviceId.prefix(8)) : report.senderCallsign)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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

                // Mechanism of injury preview
                if !report.mechanismOfInjury.isEmpty {
                    Text(report.mechanismOfInjury)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: MedevacPriority

    var body: some View {
        Text(priority.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(priority.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(priority.color.opacity(0.15))
            .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview("MEDEVAC List") {
    MedevacListScreen()
}
