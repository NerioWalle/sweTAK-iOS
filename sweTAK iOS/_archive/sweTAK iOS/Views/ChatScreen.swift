import SwiftUI

/// Chat screen for direct messaging with a peer
/// Mirrors Android ChatScreen functionality
public struct ChatScreen: View {
    let threadId: String
    let peerCallsign: String
    let peerNickname: String?

    @ObservedObject private var chatVM = ChatViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool

    public init(threadId: String, peerCallsign: String, peerNickname: String? = nil) {
        self.threadId = threadId
        self.peerCallsign = peerCallsign
        self.peerNickname = peerNickname
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages list
                messagesList

                Divider()

                // Input bar
                chatInputBar
            }
            .navigationTitle("Chat with \(peerTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onAppear {
                chatVM.setThread(threadId: threadId, peerCallsign: peerCallsign, peerNickname: peerNickname)
            }
            .onDisappear {
                chatVM.closeThread()
            }
        }
    }

    // MARK: - Peer Title

    private var peerTitle: String {
        if let nickname = peerNickname, !nickname.isEmpty {
            return "\(peerCallsign) (\(nickname))"
        }
        return peerCallsign
    }

    // MARK: - Messages List

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(chatVM.uiState.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: chatVM.uiState.messages.count) { _ in
                // Auto-scroll to bottom when new message arrives
                if let lastMessage = chatVM.uiState.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Chat Input Bar

    private var chatInputBar: some View {
        HStack(spacing: 12) {
            TextField("Message", text: Binding(
                get: { chatVM.uiState.inputText },
                set: { chatVM.onInputTextChanged($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .focused($isInputFocused)
            .submitLabel(.send)
            .onSubmit {
                if chatVM.uiState.isSendEnabled {
                    chatVM.onSendClicked()
                }
            }

            Button(action: {
                chatVM.onSendClicked()
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
            }
            .disabled(!chatVM.uiState.isSendEnabled)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.direction == .outgoing {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.direction == .outgoing ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleColor)
                    .foregroundColor(textColor)
                    .cornerRadius(16)

                HStack(spacing: 4) {
                    Text(formatTime(message.timestampMillis))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if message.direction == .outgoing {
                        Image(systemName: message.acknowledged ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.caption2)
                            .foregroundColor(message.acknowledged ? .green : .secondary)
                    }
                }
            }

            if message.direction == .incoming {
                Spacer(minLength: 60)
            }
        }
    }

    private var bubbleColor: Color {
        message.direction == .outgoing ? .blue : Color(.systemGray5)
    }

    private var textColor: Color {
        message.direction == .outgoing ? .white : .primary
    }

    private func formatTime(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(millis) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Chat Recipient Picker

/// Screen to select a chat recipient from contacts
public struct ChatRecipientPicker: View {
    @ObservedObject private var contactsVM = ContactsViewModel.shared
    @Environment(\.dismiss) private var dismiss

    let onRecipientSelected: (ContactProfile) -> Void

    public init(onRecipientSelected: @escaping (ContactProfile) -> Void) {
        self.onRecipientSelected = onRecipientSelected
    }

    public var body: some View {
        NavigationStack {
            List {
                if contactsVM.contacts.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "person.3.fill")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)

                            Text("No contacts available")
                                .font(.headline)

                            Text("Discover peers in the Contact Book first")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    Section("Select a contact to chat with") {
                        ForEach(sortedContacts) { contact in
                            let isMe = contact.deviceId == TransportCoordinator.shared.deviceId
                            if !isMe && !contactsVM.isBlocked(contact.deviceId) {
                                RecipientRow(contact: contact)
                                    .onTapGesture {
                                        onRecipientSelected(contact)
                                        dismiss()
                                    }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var sortedContacts: [ContactProfile] {
        contactsVM.contacts.sorted { a, b in
            let aName = (a.callsign ?? a.nickname ?? "Unknown").lowercased()
            let bName = (b.callsign ?? b.nickname ?? "Unknown").lowercased()
            return aName < bName
        }
    }
}

// MARK: - Recipient Row

private struct RecipientRow: View {
    let contact: ContactProfile

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(contact.isOnline ? .green : .orange)
                    .frame(width: 40, height: 40)

                Text(String(contact.displayName.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.headline)

                if let nickname = contact.nickname {
                    Text(nickname)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if contact.isOnline {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Chat Threads List

/// Helper struct for sheet presentation
private struct ChatThreadSelection: Identifiable {
    let id: String
    let threadId: String
    let callsign: String
    let nickname: String?

    init(threadId: String, callsign: String, nickname: String? = nil) {
        self.id = threadId
        self.threadId = threadId
        self.callsign = callsign
        self.nickname = nickname
    }
}

/// Screen showing all chat threads
public struct ChatThreadsScreen: View {
    @ObservedObject private var chatVM = ChatViewModel.shared
    @ObservedObject private var contactsVM = ContactsViewModel.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingRecipientPicker = false
    @State private var selectedThread: ChatThreadSelection?

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                if chatVM.allThreadIds.isEmpty {
                    // Show available contacts when no threads exist
                    if availableContacts.isEmpty {
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)

                                Text("No conversations yet")
                                    .font(.headline)

                                Text("No contacts available. Discover peers in the Contact Book first.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    } else {
                        Section("Start a conversation") {
                            ForEach(availableContacts) { contact in
                                RecipientRow(contact: contact)
                                    .onTapGesture {
                                        selectedThread = ChatThreadSelection(
                                            threadId: contact.deviceId,
                                            callsign: contact.callsign ?? "Unknown",
                                            nickname: contact.nickname
                                        )
                                    }
                            }
                        }
                    }
                } else {
                    Section("Conversations") {
                        ForEach(chatVM.allThreadIds, id: \.self) { threadId in
                            ThreadRow(
                                threadId: threadId,
                                messages: chatVM.getMessages(forThread: threadId),
                                unreadCount: chatVM.unreadCounts[threadId] ?? 0,
                                contact: contactsVM.contacts.first { $0.deviceId == threadId }
                            )
                            .onTapGesture {
                                let contact = contactsVM.contacts.first { $0.deviceId == threadId }
                                selectedThread = ChatThreadSelection(
                                    threadId: threadId,
                                    callsign: contact?.callsign ?? "Unknown",
                                    nickname: contact?.nickname
                                )
                            }
                        }
                        .onDelete(perform: deleteThreads)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingRecipientPicker = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingRecipientPicker) {
                ChatRecipientPicker { contact in
                    selectedThread = ChatThreadSelection(
                        threadId: contact.deviceId,
                        callsign: contact.callsign ?? "Unknown",
                        nickname: contact.nickname
                    )
                }
            }
            .sheet(item: $selectedThread) { thread in
                ChatScreen(
                    threadId: thread.threadId,
                    peerCallsign: thread.callsign,
                    peerNickname: thread.nickname
                )
            }
            .badge(chatVM.totalUnreadCount)
        }
    }

    private func deleteThreads(at offsets: IndexSet) {
        for index in offsets {
            let threadId = chatVM.allThreadIds[index]
            chatVM.deleteThread(threadId)
        }
    }

    private var availableContacts: [ContactProfile] {
        let myDeviceId = TransportCoordinator.shared.deviceId
        return contactsVM.contacts
            .filter { $0.deviceId != myDeviceId && !contactsVM.isBlocked($0.deviceId) }
            .sorted { ($0.callsign ?? "").lowercased() < ($1.callsign ?? "").lowercased() }
    }
}

// MARK: - Thread Row

private struct ThreadRow: View {
    let threadId: String
    let messages: [ChatMessage]
    let unreadCount: Int
    let contact: ContactProfile?

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(contact?.isOnline == true ? .green : .blue)
                    .frame(width: 50, height: 50)

                Text(String((contact?.displayName ?? "?").prefix(1)).uppercased())
                    .font(.title2)
                    .foregroundColor(.white)
            }

            // Thread info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(contact?.displayName ?? threadId.prefix(8).description)
                        .font(.headline)

                    Spacer()

                    if let lastMessage = messages.last {
                        Text(formatDate(lastMessage.timestampMillis))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    if let lastMessage = messages.last {
                        Text(lastMessage.text)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func formatDate(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(millis) / 1000.0)
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Previews

#Preview("Chat Screen") {
    ChatScreen(
        threadId: "device-123",
        peerCallsign: "Alpha-1",
        peerNickname: "John"
    )
}

#Preview("Chat Threads") {
    ChatThreadsScreen()
}

#Preview("Recipient Picker") {
    ChatRecipientPicker { _ in }
}
