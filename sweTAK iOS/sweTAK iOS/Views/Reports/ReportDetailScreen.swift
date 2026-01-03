import SwiftUI

/// Detail view for a PEDARS status report.
/// Mirrors Android ReportDetailScreen functionality.
public struct ReportDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var reportsVM = ReportsViewModel.shared
    @ObservedObject private var contactsVM = ContactsViewModel.shared

    let report: Report

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    public init(report: Report) {
        self.report = report
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header card
                    headerCard

                    // Readiness details (if Yellow or Red)
                    if report.readiness != .green && !report.readinessDetails.isEmpty {
                        readinessDetailsSection
                    }

                    // Personnel status section
                    personnelSection

                    // Supply needs section
                    supplyNeedsSection

                    // Recipients section (for outgoing)
                    if report.direction == .outgoing && !report.recipientDeviceIds.isEmpty {
                        recipientsSection
                    }

                    // Delete button
                    deleteSection
                }
                .padding()
            }
            .navigationTitle("PEDARS Report")
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

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Readiness badge large
                ReadinessBadgeLarge(readiness: report.readiness)

                Spacer()

                Text(report.direction == .incoming ? "Received" : "Sent")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(dateFormatter.string(from: Date(timeIntervalSince1970: Double(report.createdAtMillis) / 1000)))
                .font(.subheadline)
                .foregroundColor(.secondary)

            if report.direction == .incoming {
                Text("From: \(report.senderCallsign.isEmpty ? String(report.senderDeviceId.prefix(8)) : report.senderCallsign)")
                    .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Readiness Details Section

    private var readinessDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(report.readiness == .yellow ? "LIMITATIONS & PROGNOSIS" : "PROBLEMS & PROGNOSIS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(report.readiness == .yellow
                                 ? Color(red: 0.475, green: 0.337, blue: 0)
                                 : report.readiness.color)

            Text(report.readinessDetails)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(report.readiness.color.opacity(0.15))
                .cornerRadius(8)
        }
    }

    // MARK: - Personnel Section

    private var personnelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PERSONNEL STATUS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.blue)

            HStack(spacing: 12) {
                PersonnelStatCard(label: "Capable", count: report.capableCount, color: .green)
                PersonnelStatCard(label: "Wounded", count: report.woundedCount, color: .orange)
                PersonnelStatCard(label: "Dead", count: report.deadCount, color: .gray)
            }
        }
    }

    // MARK: - Supply Needs Section

    private var supplyNeedsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SUPPLY NEEDS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.blue)

            if report.replenishment.isEmpty && report.fuel.isEmpty &&
               report.ammunition.isEmpty && report.equipment.isEmpty {
                Text("No supply needs reported.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            } else {
                if !report.replenishment.isEmpty {
                    SupplyFieldCard(label: "Replenishment", content: report.replenishment)
                }
                if !report.fuel.isEmpty {
                    SupplyFieldCard(label: "Fuel", content: report.fuel)
                }
                if !report.ammunition.isEmpty {
                    SupplyFieldCard(label: "Ammunition", content: report.ammunition)
                }
                if !report.equipment.isEmpty {
                    SupplyFieldCard(label: "Equipment", content: report.equipment)
                }
            }
        }
    }

    // MARK: - Recipients Section

    private var recipientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Text("Recipients")
                .font(.headline)

            ForEach(report.recipientDeviceIds, id: \.self) { recipientId in
                let status = reportsVM.getStatusesForReport(reportId: report.id)
                    .first { $0.recipientDeviceId == recipientId }
                let contact = contactsVM.contacts.first { $0.deviceId == recipientId }
                let displayName = contact?.callsign ?? contact?.nickname ?? String(recipientId.prefix(8))

                RecipientStatusRow(
                    recipientName: displayName,
                    status: status,
                    dateFormatter: dateFormatter
                )
            }
        }
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Button(role: .destructive) {
            reportsVM.deleteReport(reportId: report.id)
            dismiss()
        } label: {
            Label("Delete Report", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding(.top, 16)
    }
}

// MARK: - Readiness Badge Large

private struct ReadinessBadgeLarge: View {
    let readiness: ReadinessLevel

    private var textColor: Color {
        switch readiness {
        case .yellow:
            return Color(red: 0.475, green: 0.337, blue: 0)
        default:
            return readiness.color
        }
    }

    var body: some View {
        Text(readiness.displayName)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(readiness.color.opacity(0.2))
            .cornerRadius(6)
    }
}

// MARK: - Personnel Stat Card

private struct PersonnelStatCard: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Supply Field Card

private struct SupplyFieldCard: View {
    let label: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)

            Text(content)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Recipient Status Row

private struct RecipientStatusRow: View {
    let recipientName: String
    let status: ReportRecipientStatus?
    let dateFormatter: DateFormatter

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(recipientName)
                    .font(.subheadline)

                if let status = status {
                    if let readAt = status.readAtMillis {
                        Text("Read: \(dateFormatter.string(from: Date(timeIntervalSince1970: Double(readAt) / 1000)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let deliveredAt = status.deliveredAtMillis {
                        Text("Delivered: \(dateFormatter.string(from: Date(timeIntervalSince1970: Double(deliveredAt) / 1000)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Status icon
            if let status = status {
                if status.readAtMillis != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                } else if status.deliveredAtMillis != nil {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                }
            } else {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview("PEDARS Detail") {
    ReportDetailScreen(report: Report(
        senderDeviceId: "device-123",
        senderCallsign: "Alpha-1",
        woundedCount: 2,
        deadCount: 0,
        capableCount: 15,
        replenishment: "Need water and rations for 48 hours",
        fuel: "Diesel: 200L needed for vehicles",
        ammunition: "5.56mm: 1000 rounds\n7.62mm: 500 rounds",
        equipment: "Radio batteries, night vision goggles repair",
        readiness: .yellow,
        readinessDetails: "Limited mobility due to vehicle damage. Expected repair: 6 hours.",
        recipientDeviceIds: ["device-456"],
        direction: .incoming,
        isRead: true
    ))
}
