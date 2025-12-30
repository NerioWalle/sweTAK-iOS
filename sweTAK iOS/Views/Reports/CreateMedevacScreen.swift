import SwiftUI

/// Screen for creating and sending a MEDEVAC/MIST handover report.
/// Used when handing over an injured soldier to MEDEVAC personnel.
/// Mirrors Android CreateMedevacScreen functionality.
public struct CreateMedevacScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var contactsVM = ContactsViewModel.shared

    // Patient information
    @State private var soldierName = ""
    @State private var priority: MedevacPriority = .p2
    @State private var ageInfo = ""

    // Time of incident (DDHHMM format)
    @State private var incidentTime = ""

    // Injury information
    @State private var mechanismOfInjury = ""
    @State private var injuryDescription = ""
    @State private var signsSymptoms = ""

    // Vital parameters
    @State private var pulse = ""
    @State private var bodyTemperature = ""

    // Treatment
    @State private var treatmentActions = ""
    @State private var medicinesGiven = ""

    // Caretaker
    @State private var caretakerName = ""

    // Recipients
    @State private var selectedRecipientIds: Set<String> = []
    @State private var showingRecipientPicker = false

    // Validation
    private var isValid: Bool {
        !soldierName.isEmpty && !selectedRecipientIds.isEmpty
    }

    private var availableRecipients: [ContactProfile] {
        contactsVM.contacts.filter { $0.deviceId != TransportCoordinator.shared.deviceId }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            if showingRecipientPicker {
                recipientPickerView
            } else {
                formView
            }
        }
        .onAppear {
            setupDefaults()
        }
    }

    private func setupDefaults() {
        // Set default caretaker from profile
        if let profile = contactsVM.myProfile {
            caretakerName = profile.callsign ?? ""
        }

        // Set current time in DDHHMM format
        let formatter = DateFormatter()
        formatter.dateFormat = "ddHHmm"
        incidentTime = formatter.string(from: Date())
    }

    // MARK: - Form View

    private var formView: some View {
        Form {
            // Recipients section
            Section {
                Button {
                    showingRecipientPicker = true
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Recipients")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(selectedRecipientIds.isEmpty
                                 ? "Select recipients..."
                                 : "\(selectedRecipientIds.count) selected")
                        }
                        Spacer()
                        Image(systemName: selectedRecipientIds.isEmpty ? "chevron.right" : "checkmark")
                            .foregroundColor(selectedRecipientIds.isEmpty ? .secondary : .blue)
                    }
                }
                .foregroundColor(.primary)
            }

            // Patient Information
            Section {
                TextField("Soldier Name *", text: $soldierName)

                HStack {
                    VStack(alignment: .leading) {
                        Text("Priority")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Priority", selection: $priority) {
                            ForEach(MedevacPriority.allCases, id: \.self) { p in
                                Text(p.displayName)
                                    .foregroundColor(p.color)
                                    .tag(p)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    TextField("Age", text: $ageInfo)
                        .frame(maxWidth: 100)
                }

                TextField("Time of Incident (DDHHMM)", text: $incidentTime)
            } header: {
                Text("PATIENT INFORMATION")
                    .foregroundColor(.blue)
            }

            // Injury Information
            Section {
                TextField("Mechanism of Injury", text: $mechanismOfInjury, axis: .vertical)
                    .lineLimit(2...4)

                TextField("Injury Description", text: $injuryDescription, axis: .vertical)
                    .lineLimit(2...4)

                TextField("Signs & Symptoms", text: $signsSymptoms, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("INJURY INFORMATION")
                    .foregroundColor(.blue)
            }

            // Vital Parameters
            Section {
                HStack {
                    TextField("Pulse (BPM)", text: $pulse)
                        .keyboardType(.numberPad)

                    TextField("Body Temp (°C)", text: $bodyTemperature)
                        .keyboardType(.decimalPad)
                }
            } header: {
                Text("VITAL PARAMETERS")
                    .foregroundColor(.blue)
            }

            // Treatment
            Section {
                TextField("Actions Taken", text: $treatmentActions, axis: .vertical)
                    .lineLimit(2...4)

                TextField("Medicines Given", text: $medicinesGiven, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("TREATMENT")
                    .foregroundColor(.blue)
            }

            // Caretaker
            Section {
                TextField("Caretaker Name", text: $caretakerName)
            } header: {
                Text("CARETAKER")
                    .foregroundColor(.blue)
            }
        }
        .navigationTitle("Create MIST Report")
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
    }

    // MARK: - Recipient Picker

    private var recipientPickerView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Recipients")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    showingRecipientPicker = false
                }
            }
            .padding()

            Divider()

            if availableRecipients.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No devices available")
                        .font(.headline)
                    Text("Devices from the contact book will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(availableRecipients) { recipient in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { selectedRecipientIds.contains(recipient.deviceId) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedRecipientIds.insert(recipient.deviceId)
                                    } else {
                                        selectedRecipientIds.remove(recipient.deviceId)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading) {
                                    Text(recipient.callsign ?? String(recipient.deviceId.prefix(8)))
                                        .font(.body)
                                    if let nickname = recipient.nickname, !nickname.isEmpty {
                                        Text(nickname)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func sendReport() {
        let report = MedevacReport(
            senderDeviceId: TransportCoordinator.shared.deviceId,
            senderCallsign: contactsVM.myProfile?.callsign ?? "Unknown",
            soldierName: soldierName,
            priority: priority,
            ageInfo: ageInfo,
            incidentTime: incidentTime,
            mechanismOfInjury: mechanismOfInjury,
            injuryDescription: injuryDescription,
            signsSymptoms: signsSymptoms,
            pulse: pulse,
            bodyTemperature: bodyTemperature,
            treatmentActions: treatmentActions,
            medicinesGiven: medicinesGiven,
            caretakerName: caretakerName,
            recipientDeviceIds: Array(selectedRecipientIds),
            direction: .outgoing
        )

        MedevacViewModel.shared.sendMedevacReport(report)
        dismiss()
    }
}

// MARK: - Preview

#Preview("Create MEDEVAC") {
    CreateMedevacScreen()
}
