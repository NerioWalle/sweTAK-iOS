import SwiftUI

/// Screen for creating and sending a PEDARS status report.
/// PEDARS: Personnel Equipment Disposition Ammunition Readiness Status
public struct CreateReportScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var reportsVM = ReportsViewModel.shared
    @ObservedObject private var contactsVM = ContactsViewModel.shared

    // Optional report to duplicate from
    private let duplicateFrom: Report?

    // Personnel Status fields
    @State private var woundedCount = ""
    @State private var deadCount = ""
    @State private var capableCount = ""

    // Needs fields
    @State private var replenishment = ""
    @State private var fuel = ""
    @State private var ammunition = ""
    @State private var equipment = ""

    // Readiness fields
    @State private var readiness: ReadinessLevel = .green
    @State private var readinessDetails = ""

    // Recipients
    @State private var selectedRecipientIds: Set<String> = []
    @State private var showRecipientPicker = false

    // Validation
    private var isValid: Bool {
        !selectedRecipientIds.isEmpty && !capableCount.isEmpty
    }

    public init(duplicateFrom: Report? = nil) {
        self.duplicateFrom = duplicateFrom
    }

    public var body: some View {
        NavigationStack {
            if showRecipientPicker {
                recipientPickerView
            } else {
                formView
            }
        }
    }

    private var formView: some View {
        Form {
            // Recipients section
            Section {
                Button {
                    showRecipientPicker = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recipients")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(selectedRecipientIds.isEmpty
                                 ? "Select recipients..."
                                 : "\(selectedRecipientIds.count) selected")
                        }
                        Spacer()
                        Image(systemName: selectedRecipientIds.isEmpty ? "chevron.right" : "checkmark.circle.fill")
                            .foregroundColor(selectedRecipientIds.isEmpty ? .secondary : .green)
                    }
                }
                .buttonStyle(.plain)
            }

            // Personnel Status section
            Section {
                HStack(spacing: 12) {
                    VStack {
                        TextField("0", text: $woundedCount)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.roundedBorder)
                        Text("Wounded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        TextField("0", text: $deadCount)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.roundedBorder)
                        Text("Dead")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        TextField("0", text: $capableCount)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.roundedBorder)
                        Text("Capable")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("PERSONNEL STATUS")
            }

            // Supply Needs section
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Replenishment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Supply needs description...", text: $replenishment, axis: .vertical)
                        .lineLimit(2...4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Fuel")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Fuel needs (type and quantity)...", text: $fuel, axis: .vertical)
                        .lineLimit(2...4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ammunition")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Ammunition needs (types and quantities)...", text: $ammunition, axis: .vertical)
                        .lineLimit(2...4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Equipment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Repair/replacement needs...", text: $equipment, axis: .vertical)
                        .lineLimit(2...4)
                }
            } header: {
                Text("SUPPLY NEEDS")
            }

            // Readiness section
            Section {
                Picker("Readiness Level", selection: $readiness) {
                    ForEach(ReadinessLevel.allCases, id: \.self) { level in
                        HStack {
                            Circle()
                                .fill(level.color)
                                .frame(width: 12, height: 12)
                            Text(level.displayName)
                        }
                        .tag(level)
                    }
                }

                if readiness != .green {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(readiness == .yellow ? "Limitations & Prognosis" : "Problems & Prognosis")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(
                            readiness == .yellow
                                ? "Describe limitations and expected mitigation time..."
                                : "Describe problems and expected resolution time...",
                            text: $readinessDetails,
                            axis: .vertical
                        )
                        .lineLimit(3...6)
                    }
                }
            } header: {
                Text("READINESS GRADING")
            }
        }
        .navigationTitle("Create PEDARS Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    sendReport()
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(!isValid)
            }
        }
        .onAppear {
            // Pre-fill fields if duplicating from an existing report
            if let source = duplicateFrom {
                woundedCount = source.woundedCount > 0 ? String(source.woundedCount) : ""
                deadCount = source.deadCount > 0 ? String(source.deadCount) : ""
                capableCount = source.capableCount > 0 ? String(source.capableCount) : ""
                replenishment = source.replenishment
                fuel = source.fuel
                ammunition = source.ammunition
                equipment = source.equipment
                readiness = source.readiness
                readinessDetails = source.readinessDetails
                // Recipients are intentionally NOT copied - user must select new ones
            }
        }
    }

    private var recipientPickerView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Recipients")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    showRecipientPicker = false
                }
            }
            .padding()

            Divider()

            if contactsVM.contacts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text("No devices available")
                        .font(.headline)

                    Text("Devices from the contact book will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(contactsVM.contacts) { contact in
                        Button {
                            if selectedRecipientIds.contains(contact.deviceId) {
                                selectedRecipientIds.remove(contact.deviceId)
                            } else {
                                selectedRecipientIds.insert(contact.deviceId)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedRecipientIds.contains(contact.deviceId)
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .foregroundColor(selectedRecipientIds.contains(contact.deviceId) ? .green : .secondary)

                                VStack(alignment: .leading) {
                                    Text(contact.callsign ?? String(contact.deviceId.prefix(8)))
                                        .foregroundColor(.primary)
                                    if let nickname = contact.nickname, !nickname.isEmpty {
                                        Text(nickname)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Recipients")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendReport() {
        let myProfile = contactsVM.myProfile
        let deviceId = TransportCoordinator.shared.deviceId

        let report = Report(
            senderDeviceId: deviceId,
            senderCallsign: myProfile?.callsign ?? "",
            woundedCount: Int(woundedCount) ?? 0,
            deadCount: Int(deadCount) ?? 0,
            capableCount: Int(capableCount) ?? 0,
            replenishment: replenishment,
            fuel: fuel,
            ammunition: ammunition,
            equipment: equipment,
            readiness: readiness,
            readinessDetails: readiness != .green ? readinessDetails : "",
            recipientDeviceIds: Array(selectedRecipientIds),
            direction: .outgoing,
            isRead: true
        )

        reportsVM.sendReport(report)
        dismiss()
    }
}

// MARK: - Preview

#Preview("Create PEDARS Report") {
    CreateReportScreen()
}
