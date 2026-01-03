import SwiftUI

/// Multi-select recipient picker for orders
/// Mirrors Android OrderRecipientPicker functionality
public struct OrderRecipientPicker: View {
    let availableRecipients: [ContactProfile]
    @Binding var selectedRecipientIds: Set<String>
    let onDone: () -> Void

    public init(
        availableRecipients: [ContactProfile],
        selectedRecipientIds: Binding<Set<String>>,
        onDone: @escaping () -> Void
    ) {
        self.availableRecipients = availableRecipients
        self._selectedRecipientIds = selectedRecipientIds
        self.onDone = onDone
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Recipients")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Button("Done") {
                    onDone()
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            // Content
            if availableRecipients.isEmpty {
                emptyStateView
            } else {
                recipientsList
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No devices available.")
                .font(.headline)

            Text("Devices from the contact book will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - Recipients List

    private var recipientsList: some View {
        List {
            ForEach(availableRecipients, id: \.deviceId) { recipient in
                RecipientRow(
                    recipient: recipient,
                    isSelected: selectedRecipientIds.contains(recipient.deviceId),
                    onToggle: {
                        toggleRecipient(recipient.deviceId)
                    }
                )
            }
        }
        .listStyle(.plain)
    }

    private func toggleRecipient(_ deviceId: String) {
        if selectedRecipientIds.contains(deviceId) {
            selectedRecipientIds.remove(deviceId)
        } else {
            selectedRecipientIds.insert(deviceId)
        }
    }
}

// MARK: - Recipient Row

private struct RecipientRow: View {
    let recipient: ContactProfile
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title3)

                // Recipient info
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipient.callsign ?? String(recipient.deviceId.prefix(8)))
                        .font(.body)
                        .foregroundColor(.primary)

                    if let nickname = recipient.nickname, !nickname.isEmpty {
                        Text(nickname)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview("With Recipients") {
    OrderRecipientPicker(
        availableRecipients: [
            ContactProfile(
                deviceId: "device-1",
                nickname: "Team Leader",
                callsign: "Alpha-1"
            ),
            ContactProfile(
                deviceId: "device-2",
                callsign: "Bravo-2"
            ),
            ContactProfile(
                deviceId: "device-3",
                nickname: "Scout"
            )
        ],
        selectedRecipientIds: .constant(Set(["device-1"])),
        onDone: {}
    )
}

#Preview("Empty") {
    OrderRecipientPicker(
        availableRecipients: [],
        selectedRecipientIds: .constant(Set()),
        onDone: {}
    )
}
