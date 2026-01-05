import SwiftUI

/// Screen for creating and sending a 5P order
/// 5P = Orientation, Mission, Execution, Logistics/Administration, Command/Signalling
/// Mirrors Android CreateFivePOrderScreen functionality
public struct CreateFivePOrderScreen: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var contactsVM = ContactsViewModel.shared
    @ObservedObject private var ordersVM = OrdersViewModel.shared
    @ObservedObject private var settingsVM = SettingsViewModel.shared

    // Optional order to duplicate from
    private let duplicateFrom: Order?

    // 5P fields
    @State private var orientation = ""
    @State private var mission = ""
    @State private var execution = ""
    @State private var logistics = ""
    @State private var commandSignaling = ""

    // Recipients
    @State private var selectedRecipientIds = Set<String>()
    @State private var showRecipientPicker = false

    // Focus management
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case orientation
        case mission
        case execution
        case logistics
        case commandSignaling
    }

    public init(duplicateFrom: Order? = nil) {
        self.duplicateFrom = duplicateFrom
    }

    public var body: some View {
        NavigationStack {
            Group {
                if showRecipientPicker {
                    OrderRecipientPicker(
                        availableRecipients: availableRecipients,
                        selectedRecipientIds: $selectedRecipientIds,
                        onDone: { showRecipientPicker = false }
                    )
                } else {
                    orderForm
                }
            }
            .navigationTitle("Create 5P Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        sendOrder()
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(!canSend)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                // Pre-fill fields if duplicating from an existing order
                if let source = duplicateFrom {
                    orientation = source.orientation
                    mission = source.mission
                    execution = source.execution
                    logistics = source.logistics
                    commandSignaling = source.commandSignaling
                    // Recipients are intentionally NOT copied - user must select new ones
                }
            }
        }
    }

    // MARK: - Order Form

    private var orderForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Recipients selector
                recipientsSection

                Divider()

                // 1. Orientation field
                FivePFormField(
                    number: "1",
                    title: "Orientation / Background",
                    placeholder: "Current situation and context...",
                    text: $orientation
                )
                .focused($focusedField, equals: .orientation)

                // 2. Mission field
                FivePFormField(
                    number: "2",
                    title: "Mission",
                    placeholder: "Mission objectives...",
                    text: $mission
                )
                .focused($focusedField, equals: .mission)

                // 3. Execution field
                FivePFormField(
                    number: "3",
                    title: "Execution",
                    placeholder: "Execution plan...",
                    text: $execution
                )
                .focused($focusedField, equals: .execution)

                // 4. Logistics / Administration field
                FivePFormField(
                    number: "4",
                    title: "Logistics / Administration",
                    placeholder: "Logistics and admin...",
                    text: $logistics
                )
                .focused($focusedField, equals: .logistics)

                // 5. Command and Signalling field
                FivePFormField(
                    number: "5",
                    title: "Command and Signalling",
                    placeholder: "Command structure, signals...",
                    text: $commandSignaling
                )
                .focused($focusedField, equals: .commandSignaling)

                Spacer(minLength: 100)
            }
            .padding()
        }
    }

    // MARK: - Recipients Section

    private var recipientsSection: some View {
        Button {
            showRecipientPicker = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recipients")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(recipientsText)
                        .font(.body)
                        .foregroundColor(selectedRecipientIds.isEmpty ? .secondary : .primary)
                }

                Spacer()

                Image(systemName: selectedRecipientIds.isEmpty ? "chevron.right" : "checkmark.circle.fill")
                    .foregroundColor(selectedRecipientIds.isEmpty ? .secondary : .blue)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var recipientsText: String {
        if selectedRecipientIds.isEmpty {
            return "Select recipients..."
        } else {
            return "\(selectedRecipientIds.count) selected"
        }
    }

    // MARK: - Computed Properties

    private var availableRecipients: [ContactProfile] {
        contactsVM.contacts.filter { $0.deviceId != settingsVM.deviceId }
    }

    private var canSend: Bool {
        !selectedRecipientIds.isEmpty && !orientation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func sendOrder() {
        let newOrder = Order(
            type: .fiveP,
            senderDeviceId: settingsVM.deviceId,
            senderCallsign: settingsVM.callsign,
            orientation: orientation.trimmingCharacters(in: .whitespacesAndNewlines),
            decision: "",  // Not used in 5P
            order: "",     // Not used in 5P
            mission: mission.trimmingCharacters(in: .whitespacesAndNewlines),
            execution: execution.trimmingCharacters(in: .whitespacesAndNewlines),
            logistics: logistics.trimmingCharacters(in: .whitespacesAndNewlines),
            commandSignaling: commandSignaling.trimmingCharacters(in: .whitespacesAndNewlines),
            recipientDeviceIds: Array(selectedRecipientIds),
            direction: .outgoing
        )

        ordersVM.sendOrder(newOrder)
        dismiss()
    }
}

// MARK: - 5P Form Field Component

private struct FivePFormField: View {
    let number: String
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Number badge
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.blue)
                    .clipShape(Circle())

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            TextEditor(text: $text)
                .frame(minHeight: 70)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview("Create 5P Order") {
    CreateFivePOrderScreen()
}
