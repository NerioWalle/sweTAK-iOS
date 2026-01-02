import SwiftUI

/// Contact Book screen showing all discovered peers
/// Mirrors Android ContactBookOverlay functionality
public struct ContactBookScreen: View {
    @ObservedObject private var contactsVM = ContactsViewModel.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedContact: ContactProfile?
    @State private var showingContactDetail = false
    @State private var isRefreshing = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                if contactsVM.contacts.isEmpty {
                    emptyStateView
                } else {
                    contactListView
                }
            }
            .navigationTitle("Contact Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Bottom buttons for Clear and Refresh
                HStack(spacing: 16) {
                    Button(action: clearContacts) {
                        Label("Clear List", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button(action: refreshContacts) {
                        if isRefreshing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRefreshing)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
            .sheet(isPresented: $showingContactDetail) {
                if let contact = selectedContact {
                    ContactDetailSheet(contact: contact)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Contacts")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap Refresh to discover nearby peers")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: refreshContacts) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRefreshing)
        }
        .padding()
    }

    // MARK: - Contact List

    private var contactListView: some View {
        List {
            // My profile section
            if let myProfile = contactsVM.myProfile {
                Section("My Profile") {
                    ContactRow(
                        contact: myProfile,
                        isMe: true,
                        isBlocked: false,
                        onTap: {
                            selectedContact = myProfile
                            showingContactDetail = true
                        },
                        onBlockToggle: nil
                    )
                }
            }

            // Other contacts section
            Section("Contacts (\(contactsVM.contacts.count))") {
                ForEach(sortedContacts) { contact in
                    let isMe = contact.deviceId == TransportCoordinator.shared.deviceId
                    if !isMe {
                        ContactRow(
                            contact: contact,
                            isMe: false,
                            isBlocked: contactsVM.isBlocked(contact.deviceId),
                            onTap: {
                                selectedContact = contact
                                showingContactDetail = true
                            },
                            onBlockToggle: {
                                if contactsVM.isBlocked(contact.deviceId) {
                                    contactsVM.unblockDevice(contact.deviceId)
                                } else {
                                    contactsVM.blockDevice(contact.deviceId)
                                }
                            }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await performRefresh()
        }
    }

    // MARK: - Sorted Contacts

    private var sortedContacts: [ContactProfile] {
        contactsVM.contacts.sorted { a, b in
            let aName = (a.callsign ?? a.nickname ?? "Unknown").lowercased()
            let bName = (b.callsign ?? b.nickname ?? "Unknown").lowercased()
            return aName < bName
        }
    }

    // MARK: - Actions

    private func refreshContacts() {
        isRefreshing = true
        contactsVM.refreshPeerDiscovery()

        // Simulate refresh delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isRefreshing = false
        }
    }

    private func performRefresh() async {
        isRefreshing = true
        contactsVM.refreshPeerDiscovery()
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        isRefreshing = false
    }

    private func clearContacts() {
        contactsVM.clearAllContacts()
    }
}

// MARK: - Contact Row

private struct ContactRow: View {
    let contact: ContactProfile
    let isMe: Bool
    let isBlocked: Bool
    let onTap: () -> Void
    let onBlockToggle: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 44, height: 44)

                Text(avatarInitial)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            // Contact info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(headerText)
                        .font(.headline)

                    if contact.isOnline {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(bodyText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let lastSeen = contact.lastSeenAt {
                    Text("Last seen: \(formatLastSeen(lastSeen))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Trailing control
            if isMe {
                Text("Me")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if let toggle = onBlockToggle {
                Toggle("", isOn: Binding(
                    get: { !isBlocked },
                    set: { _ in toggle() }
                ))
                .labelsHidden()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private var avatarColor: Color {
        if isMe {
            return .blue
        } else if isBlocked {
            return .gray
        } else if contact.isOnline {
            return .green
        } else {
            return .orange
        }
    }

    private var avatarInitial: String {
        let name = contact.callsign ?? contact.nickname ?? "?"
        return String(name.prefix(1)).uppercased()
    }

    private var headerText: String {
        let callsign = contact.callsign ?? "Unknown"
        if let nickname = contact.nickname, !nickname.isEmpty {
            return "\(callsign) - \(nickname)"
        }
        return callsign
    }

    private var bodyText: String {
        contact.fullName ?? "-"
    }

    private func formatLastSeen(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Contact Detail Sheet

private struct ContactDetailSheet: View {
    let contact: ContactProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Header section
                Section {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(.blue)
                                .frame(width: 60, height: 60)

                            Text(String(contact.displayName.prefix(1)).uppercased())
                                .font(.title)
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(contact.displayName)
                                .font(.title2)
                                .fontWeight(.semibold)

                            if let nickname = contact.nickname {
                                Text(nickname)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(contact.isOnline ? .green : .gray)
                                    .frame(width: 8, height: 8)
                                Text(contact.isOnline ? "Online" : "Offline")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Personal info
                Section("Personal Information") {
                    DetailRow(label: "Device ID", value: contact.deviceId)

                    if let ip = contact.fromIp, !ip.isEmpty {
                        DetailRow(label: "IP Address", value: ip)
                    }

                    if let fullName = contact.fullName {
                        DetailRow(label: "Name", value: fullName)
                    }

                    if contact.role != .none {
                        DetailRow(label: "Role", value: contact.role.displayName)
                    }
                }

                // Unit info
                Section("Unit Information") {
                    if let company = contact.company {
                        DetailRow(label: "Company", value: company)
                    }
                    if let platoon = contact.platoon {
                        DetailRow(label: "Platoon", value: platoon)
                    }
                    if let squad = contact.squad {
                        DetailRow(label: "Squad", value: squad)
                    }

                    if contact.company == nil && contact.platoon == nil && contact.squad == nil {
                        Text("No unit information")
                            .foregroundColor(.secondary)
                    }
                }

                // Contact info
                Section("Contact Information") {
                    if let mobile = contact.mobile {
                        DetailRow(label: "Mobile", value: mobile)
                    }
                    if let email = contact.email {
                        DetailRow(label: "Email", value: email)
                    }

                    if contact.mobile == nil && contact.email == nil {
                        Text("No contact information")
                            .foregroundColor(.secondary)
                    }
                }

                // Timestamps
                if let lastSeen = contact.lastSeenAt {
                    Section("Activity") {
                        DetailRow(label: "Last Seen", value: formatDate(lastSeen))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Contact Details")
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Preview

#Preview {
    ContactBookScreen()
}
