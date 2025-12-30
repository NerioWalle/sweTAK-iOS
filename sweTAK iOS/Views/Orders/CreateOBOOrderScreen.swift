import SwiftUI

/// Screen for creating and sending an OBO (Orientering, Beslut, Order) order
/// Mirrors Android CreateOBOOrderScreen functionality
public struct CreateOBOOrderScreen: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var contactsVM = ContactsViewModel.shared
    @ObservedObject private var ordersVM = OrdersViewModel.shared
    @ObservedObject private var settingsVM = SettingsViewModel.shared

    // OBO fields
    @State private var orientation = ""
    @State private var decision = ""
    @State private var order = ""

    // Recipients
    @State private var selectedRecipientIds = Set<String>()
    @State private var showRecipientPicker = false

    // Focus management
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case orientation
        case decision
        case order
    }

    public init() {}

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
            .navigationTitle("Create OBO Order")
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
        }
    }

    // MARK: - Order Form

    private var orderForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Recipients selector
                recipientsSection

                Divider()

                // Orientation field
                FormField(
                    title: "O - Orientation / Background",
                    placeholder: "Current situation and context...",
                    text: $orientation
                )
                .focused($focusedField, equals: .orientation)

                // Decision field
                FormField(
                    title: "B - Decision",
                    placeholder: "Decision made...",
                    text: $decision
                )
                .focused($focusedField, equals: .decision)

                // Order field
                FormField(
                    title: "O - Order",
                    placeholder: "Orders to execute...",
                    text: $order
                )
                .focused($focusedField, equals: .order)

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
            type: .obo,
            senderDeviceId: settingsVM.deviceId,
            senderCallsign: settingsVM.callsign,
            orientation: orientation.trimmingCharacters(in: .whitespacesAndNewlines),
            decision: decision.trimmingCharacters(in: .whitespacesAndNewlines),
            order: order.trimmingCharacters(in: .whitespacesAndNewlines),
            recipientDeviceIds: Array(selectedRecipientIds),
            direction: .outgoing
        )

        ordersVM.sendOrder(newOrder)
        dismiss()
    }
}

// MARK: - Form Field Component

private struct FormField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.blue)

            TextEditor(text: $text)
                .frame(minHeight: 80)
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

#Preview("Create OBO Order") {
    CreateOBOOrderScreen()
}
