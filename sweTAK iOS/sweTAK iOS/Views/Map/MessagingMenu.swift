import SwiftUI

// MARK: - Messaging Menu Button

/// Messaging menu button with hierarchical access to Chat, Orders, Reports, and Requests
/// Uses SwiftUI Menu with nested submenus for proper menu UI experience
public struct MessagingMenuButton: View {
    let onOpenChat: () -> Void
    let onCreateOBOOrder: () -> Void
    let onCreateFivePOrder: () -> Void
    let onListOrders: () -> Void
    let onCreatePedars: () -> Void
    let onCreateMist: () -> Void
    let onListReports: () -> Void
    let onCreateMethane: () -> Void
    let onListRequests: () -> Void

    public init(
        onOpenChat: @escaping () -> Void,
        onCreateOBOOrder: @escaping () -> Void,
        onCreateFivePOrder: @escaping () -> Void,
        onListOrders: @escaping () -> Void,
        onCreatePedars: @escaping () -> Void,
        onCreateMist: @escaping () -> Void,
        onListReports: @escaping () -> Void,
        onCreateMethane: @escaping () -> Void,
        onListRequests: @escaping () -> Void
    ) {
        self.onOpenChat = onOpenChat
        self.onCreateOBOOrder = onCreateOBOOrder
        self.onCreateFivePOrder = onCreateFivePOrder
        self.onListOrders = onListOrders
        self.onCreatePedars = onCreatePedars
        self.onCreateMist = onCreateMist
        self.onListReports = onListReports
        self.onCreateMethane = onCreateMethane
        self.onListRequests = onListRequests
    }

    public var body: some View {
        Menu {
            Button {
                onOpenChat()
            } label: {
                Label("Chat", systemImage: "message.fill")
            }

            Menu {
                Button {
                    onCreateOBOOrder()
                } label: {
                    Label("Create OBO", systemImage: "plus")
                }
                Button {
                    onCreateFivePOrder()
                } label: {
                    Label("Create 5P", systemImage: "plus")
                }
                Divider()
                Button {
                    onListOrders()
                } label: {
                    Label("List Orders", systemImage: "list.bullet")
                }
            } label: {
                Label("Orders", systemImage: "doc.text.fill")
            }

            Menu {
                Button {
                    onCreatePedars()
                } label: {
                    Label("Create PEDARS", systemImage: "plus")
                }
                Button {
                    onCreateMist()
                } label: {
                    Label("Create MIST", systemImage: "plus")
                }
                Divider()
                Button {
                    onListReports()
                } label: {
                    Label("List Reports", systemImage: "list.bullet")
                }
            } label: {
                Label("Reports", systemImage: "doc.richtext.fill")
            }

            Menu {
                Button {
                    onCreateMethane()
                } label: {
                    Label("Create METHANE", systemImage: "plus")
                }
                Divider()
                Button {
                    onListRequests()
                } label: {
                    Label("List Requests", systemImage: "list.bullet")
                }
            } label: {
                Label("Requests", systemImage: "exclamationmark.triangle.fill")
            }
        } label: {
            Image(systemName: "envelope.fill")
                .font(.title2)
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Previews

#Preview("Messaging Menu Button") {
    MessagingMenuButton(
        onOpenChat: {},
        onCreateOBOOrder: {},
        onCreateFivePOrder: {},
        onListOrders: {},
        onCreatePedars: {},
        onCreateMist: {},
        onListReports: {},
        onCreateMethane: {},
        onListRequests: {}
    )
}
