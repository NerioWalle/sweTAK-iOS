import SwiftUI

/// Detail view for a MEDEVAC/MIST handover report.
/// Mirrors Android MedevacDetailScreen functionality.
public struct MedevacDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var medevacVM = MedevacViewModel.shared

    let report: MedevacReport
    @State private var showingDuplicate = false

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }

    public init(report: MedevacReport) {
        self.report = report
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    // Header section
                    Section {
                        HStack {
                            PriorityBadge(priority: report.priority)
                            Spacer()
                            Text(dateFormatter.string(from: Date(timeIntervalSince1970: Double(report.createdAtMillis) / 1000)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Patient")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(report.soldierName)
                                .fontWeight(.semibold)
                        }

                        if report.direction == .incoming {
                            HStack {
                                Text("From")
                                Spacer()
                                Text(report.senderCallsign.isEmpty ? String(report.senderDeviceId.prefix(8)) : report.senderCallsign)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            let statuses = medevacVM.getStatusesForReport(reportId: report.id)
                            HStack {
                                Text("Recipients")
                                Spacer()
                                Text("\(report.recipientDeviceIds.count)")
                                    .foregroundColor(.secondary)
                            }

                            let deliveredCount = statuses.filter { $0.isDelivered }.count
                            let readCount = statuses.filter { $0.isRead }.count

                            HStack {
                                Text("Status")
                                Spacer()
                                Text("Delivered: \(deliveredCount), Read: \(readCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Patient Information
                    Section {
                        DetailRow(label: "Priority", value: report.priority.displayName)
                        DetailRow(label: "Age", value: report.ageInfo)
                        DetailRow(label: "Time of Incident", value: report.incidentTime)
                    } header: {
                        Text("PATIENT INFORMATION")
                            .foregroundColor(.blue)
                    }

                    // Injury Information
                    Section {
                        if !report.mechanismOfInjury.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Mechanism of Injury")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(report.mechanismOfInjury)
                            }
                        }

                        if !report.injuryDescription.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Injury Description")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(report.injuryDescription)
                            }
                        }

                        if !report.signsSymptoms.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Signs & Symptoms")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(report.signsSymptoms)
                            }
                        }
                    } header: {
                        Text("INJURY INFORMATION")
                            .foregroundColor(.blue)
                    }

                    // Vital Parameters
                    if !report.pulse.isEmpty || !report.bodyTemperature.isEmpty {
                        Section {
                            if !report.pulse.isEmpty {
                                HStack {
                                    Label("Pulse", systemImage: "heart.fill")
                                        .foregroundColor(.red)
                                    Spacer()
                                    Text("\(report.pulse) BPM")
                                        .font(.system(.body, design: .monospaced))
                                }
                            }

                            if !report.bodyTemperature.isEmpty {
                                HStack {
                                    Label("Temperature", systemImage: "thermometer")
                                        .foregroundColor(.orange)
                                    Spacer()
                                    Text("\(report.bodyTemperature) °C")
                                        .font(.system(.body, design: .monospaced))
                                }
                            }
                        } header: {
                            Text("VITAL PARAMETERS")
                                .foregroundColor(.blue)
                        }
                    }

                    // Treatment
                    Section {
                        if !report.treatmentActions.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Actions Taken")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(report.treatmentActions)
                            }
                        }

                        if !report.medicinesGiven.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Medicines Given")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(report.medicinesGiven)
                            }
                        }
                    } header: {
                        Text("TREATMENT")
                            .foregroundColor(.blue)
                    }

                    // Caretaker
                    Section {
                        DetailRow(label: "Caretaker", value: report.caretakerName)
                    } header: {
                        Text("CARETAKER")
                            .foregroundColor(.blue)
                    }

                    // Recipient Status (for outgoing reports)
                    if report.direction == .outgoing {
                        let statuses = medevacVM.getStatusesForReport(reportId: report.id)
                        if !statuses.isEmpty {
                            Section {
                                ForEach(statuses) { status in
                                    HStack {
                                        Text(status.recipientCallsign ?? String(status.recipientDeviceId.prefix(8)))

                                        Spacer()

                                        HStack(spacing: 8) {
                                            if status.isRead {
                                                Label("Read", systemImage: "eye.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                            } else if status.isDelivered {
                                                Label("Delivered", systemImage: "checkmark.circle.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            } else {
                                                Label("Sent", systemImage: "paperplane.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            } header: {
                                Text("RECIPIENT STATUS")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                // Action buttons outside the List
                VStack(spacing: 12) {
                    Button {
                        showingDuplicate = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Duplicate Report")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    Button {
                        medevacVM.deleteReport(reportId: report.id)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Report")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .navigationTitle("MIST Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDuplicate) {
                CreateMedevacScreen(duplicateFrom: report)
            }
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}

// MARK: - Preview

#Preview("MEDEVAC Detail") {
    MedevacDetailScreen(report: MedevacReport(
        senderDeviceId: "device-123",
        senderCallsign: "Medic-1",
        soldierName: "SGT Johnson",
        priority: .p1,
        ageInfo: "~30",
        incidentTime: "291430",
        mechanismOfInjury: "GSW left leg, shrapnel upper body",
        injuryDescription: "Entry wound left thigh, suspected arterial damage. Multiple shrapnel wounds torso.",
        signsSymptoms: "Severe bleeding, pale, weak pulse",
        pulse: "120",
        bodyTemperature: "36.2",
        treatmentActions: "Tourniquet applied left leg, pressure dressings on shrapnel wounds",
        medicinesGiven: "Morphine 10mg IV, TXA 1g IV",
        caretakerName: "CPL Smith",
        recipientDeviceIds: ["device-456"],
        direction: .outgoing
    ))
}
