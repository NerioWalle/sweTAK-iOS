import SwiftUI

// MARK: - Messaging Menu Button

/// Messaging menu button with hierarchical access to Chat, Orders, Reports, and Requests
public struct MessagingMenuButton: View {
    let onOpenChat: () -> Void
    let onCreateOBOOrder: () -> Void
    let onCreateFivePOrder: () -> Void
    let onListOrders: () -> Void
    let onCreatePedars: () -> Void
    let onListPedars: () -> Void
    let onCreateMist: () -> Void
    let onListMist: () -> Void
    let onCreateMethane: () -> Void
    let onListMethane: () -> Void

    @State private var showMenu = false
    @State private var menuLevel: MessagingMenuLevel = .root

    public init(
        onOpenChat: @escaping () -> Void,
        onCreateOBOOrder: @escaping () -> Void,
        onCreateFivePOrder: @escaping () -> Void,
        onListOrders: @escaping () -> Void,
        onCreatePedars: @escaping () -> Void,
        onListPedars: @escaping () -> Void,
        onCreateMist: @escaping () -> Void,
        onListMist: @escaping () -> Void,
        onCreateMethane: @escaping () -> Void,
        onListMethane: @escaping () -> Void
    ) {
        self.onOpenChat = onOpenChat
        self.onCreateOBOOrder = onCreateOBOOrder
        self.onCreateFivePOrder = onCreateFivePOrder
        self.onListOrders = onListOrders
        self.onCreatePedars = onCreatePedars
        self.onListPedars = onListPedars
        self.onCreateMist = onCreateMist
        self.onListMist = onListMist
        self.onCreateMethane = onCreateMethane
        self.onListMethane = onListMethane
    }

    public var body: some View {
        Menu {
            menuContent
        } label: {
            Image(systemName: "envelope.fill")
                .font(.title2)
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        switch menuLevel {
        case .root:
            rootMenuContent
        case .ordersSubmenu:
            ordersSubmenuContent
        case .reportsSubmenu:
            reportsSubmenuContent
        case .pedarsSubmenu:
            pedarsSubmenuContent
        case .medevacSubmenu:
            medevacSubmenuContent
        case .requestsSubmenu:
            requestsSubmenuContent
        case .methaneSubmenu:
            methaneSubmenuContent
        }
    }

    // MARK: - Root Menu

    @ViewBuilder
    private var rootMenuContent: some View {
        Button {
            onOpenChat()
        } label: {
            Label("Chat", systemImage: "message.fill")
        }

        Menu {
            ordersSubmenuContent
        } label: {
            Label("Orders", systemImage: "doc.text.fill")
        }

        Menu {
            reportsSubmenuContent
        } label: {
            Label("Reports", systemImage: "doc.plaintext.fill")
        }

        Menu {
            requestsSubmenuContent
        } label: {
            Label("Requests", systemImage: "exclamationmark.triangle.fill")
        }
    }

    // MARK: - Orders Submenu

    @ViewBuilder
    private var ordersSubmenuContent: some View {
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
    }

    // MARK: - Reports Submenu

    @ViewBuilder
    private var reportsSubmenuContent: some View {
        Menu {
            pedarsSubmenuContent
        } label: {
            Label("PEDARS", systemImage: "doc.plaintext.fill")
        }

        Menu {
            medevacSubmenuContent
        } label: {
            Label("MIST", systemImage: "cross.case.fill")
        }
    }

    // MARK: - PEDARS Submenu

    @ViewBuilder
    private var pedarsSubmenuContent: some View {
        Button {
            onCreatePedars()
        } label: {
            Label("Create PEDARS", systemImage: "plus")
        }

        Button {
            onListPedars()
        } label: {
            Label("List PEDARS", systemImage: "list.bullet")
        }
    }

    // MARK: - MEDEVAC Submenu

    @ViewBuilder
    private var medevacSubmenuContent: some View {
        Button {
            onCreateMist()
        } label: {
            Label("Create MIST", systemImage: "plus")
        }

        Button {
            onListMist()
        } label: {
            Label("List MIST", systemImage: "list.bullet")
        }
    }

    // MARK: - Requests Submenu

    @ViewBuilder
    private var requestsSubmenuContent: some View {
        Menu {
            methaneSubmenuContent
        } label: {
            Label("METHANE", systemImage: "exclamationmark.triangle.fill")
        }
    }

    // MARK: - METHANE Submenu

    @ViewBuilder
    private var methaneSubmenuContent: some View {
        Button {
            onCreateMethane()
        } label: {
            Label("Create METHANE", systemImage: "plus")
        }

        Button {
            onListMethane()
        } label: {
            Label("List METHANE", systemImage: "list.bullet")
        }
    }
}

// MARK: - Messaging Menu Sheet (Alternative Full-Screen Version)

/// Full-screen messaging menu with hierarchical navigation
public struct MessagingMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var menuLevel: MessagingMenuLevel = .root

    let onOpenChat: () -> Void
    let onCreateOBOOrder: () -> Void
    let onCreateFivePOrder: () -> Void
    let onListOrders: () -> Void
    let onCreatePedars: () -> Void
    let onListPedars: () -> Void
    let onCreateMist: () -> Void
    let onListMist: () -> Void
    let onCreateMethane: () -> Void
    let onListMethane: () -> Void

    public init(
        onOpenChat: @escaping () -> Void,
        onCreateOBOOrder: @escaping () -> Void,
        onCreateFivePOrder: @escaping () -> Void,
        onListOrders: @escaping () -> Void,
        onCreatePedars: @escaping () -> Void,
        onListPedars: @escaping () -> Void,
        onCreateMist: @escaping () -> Void,
        onListMist: @escaping () -> Void,
        onCreateMethane: @escaping () -> Void,
        onListMethane: @escaping () -> Void
    ) {
        self.onOpenChat = onOpenChat
        self.onCreateOBOOrder = onCreateOBOOrder
        self.onCreateFivePOrder = onCreateFivePOrder
        self.onListOrders = onListOrders
        self.onCreatePedars = onCreatePedars
        self.onListPedars = onListPedars
        self.onCreateMist = onCreateMist
        self.onListMist = onListMist
        self.onCreateMethane = onCreateMethane
        self.onListMethane = onListMethane
    }

    public var body: some View {
        NavigationStack {
            List {
                switch menuLevel {
                case .root:
                    rootSection
                case .ordersSubmenu:
                    ordersSection
                case .reportsSubmenu:
                    reportsSection
                case .pedarsSubmenu:
                    pedarsSection
                case .medevacSubmenu:
                    medevacSection
                case .requestsSubmenu:
                    requestsSection
                case .methaneSubmenu:
                    methaneSection
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if menuLevel != .root {
                        Button {
                            navigateBack()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Navigation

    private var navigationTitle: String {
        switch menuLevel {
        case .root: return "Messaging"
        case .ordersSubmenu: return "Orders"
        case .reportsSubmenu: return "Reports"
        case .pedarsSubmenu: return "PEDARS"
        case .medevacSubmenu: return "MIST"
        case .requestsSubmenu: return "Requests"
        case .methaneSubmenu: return "METHANE"
        }
    }

    private func navigateBack() {
        switch menuLevel {
        case .ordersSubmenu, .reportsSubmenu, .requestsSubmenu:
            menuLevel = .root
        case .pedarsSubmenu, .medevacSubmenu:
            menuLevel = .reportsSubmenu
        case .methaneSubmenu:
            menuLevel = .requestsSubmenu
        case .root:
            break
        }
    }

    // MARK: - Root Section

    @ViewBuilder
    private var rootSection: some View {
        Section {
            MenuRow(icon: "message.fill", title: "Chat", color: .blue) {
                dismiss()
                onOpenChat()
            }

            MenuRow(icon: "doc.text.fill", title: "Orders", color: .orange, hasSubmenu: true) {
                menuLevel = .ordersSubmenu
            }

            MenuRow(icon: "doc.plaintext.fill", title: "Reports", color: .green, hasSubmenu: true) {
                menuLevel = .reportsSubmenu
            }

            MenuRow(icon: "exclamationmark.triangle.fill", title: "Requests", color: .red, hasSubmenu: true) {
                menuLevel = .requestsSubmenu
            }
        }
    }

    // MARK: - Orders Section

    @ViewBuilder
    private var ordersSection: some View {
        Section("Create Order") {
            MenuRow(icon: "plus.circle.fill", title: "OBO Order", color: .orange) {
                dismiss()
                onCreateOBOOrder()
            }

            MenuRow(icon: "plus.circle.fill", title: "5P Order", color: .orange) {
                dismiss()
                onCreateFivePOrder()
            }
        }

        Section {
            MenuRow(icon: "list.bullet", title: "View Orders", color: .secondary) {
                dismiss()
                onListOrders()
            }
        }
    }

    // MARK: - Reports Section

    @ViewBuilder
    private var reportsSection: some View {
        Section {
            MenuRow(icon: "doc.plaintext.fill", title: "PEDARS", color: .green, hasSubmenu: true) {
                menuLevel = .pedarsSubmenu
            }

            MenuRow(icon: "cross.case.fill", title: "MIST (MEDEVAC)", color: .red, hasSubmenu: true) {
                menuLevel = .medevacSubmenu
            }
        }
    }

    // MARK: - PEDARS Section

    @ViewBuilder
    private var pedarsSection: some View {
        Section("PEDARS Reports") {
            MenuRow(icon: "plus.circle.fill", title: "Create PEDARS", color: .green) {
                dismiss()
                onCreatePedars()
            }

            MenuRow(icon: "list.bullet", title: "View PEDARS", color: .secondary) {
                dismiss()
                onListPedars()
            }
        }
    }

    // MARK: - MEDEVAC Section

    @ViewBuilder
    private var medevacSection: some View {
        Section("MIST Reports") {
            MenuRow(icon: "plus.circle.fill", title: "Create MIST", color: .red) {
                dismiss()
                onCreateMist()
            }

            MenuRow(icon: "list.bullet", title: "View MIST", color: .secondary) {
                dismiss()
                onListMist()
            }
        }
    }

    // MARK: - Requests Section

    @ViewBuilder
    private var requestsSection: some View {
        Section {
            MenuRow(icon: "exclamationmark.triangle.fill", title: "METHANE", color: .red, hasSubmenu: true) {
                menuLevel = .methaneSubmenu
            }
        }
    }

    // MARK: - METHANE Section

    @ViewBuilder
    private var methaneSection: some View {
        Section("METHANE Requests") {
            MenuRow(icon: "plus.circle.fill", title: "Create METHANE", color: .red) {
                dismiss()
                onCreateMethane()
            }

            MenuRow(icon: "list.bullet", title: "View METHANE", color: .secondary) {
                dismiss()
                onListMethane()
            }
        }
    }
}

// MARK: - Menu Row

private struct MenuRow: View {
    let icon: String
    let title: String
    let color: Color
    var hasSubmenu: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(title)
                    .foregroundColor(.primary)

                Spacer()

                if hasSubmenu {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
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
        onListPedars: {},
        onCreateMist: {},
        onListMist: {},
        onCreateMethane: {},
        onListMethane: {}
    )
}

#Preview("Messaging Menu Sheet") {
    MessagingMenuSheet(
        onOpenChat: {},
        onCreateOBOOrder: {},
        onCreateFivePOrder: {},
        onListOrders: {},
        onCreatePedars: {},
        onListPedars: {},
        onCreateMist: {},
        onListMist: {},
        onCreateMethane: {},
        onListMethane: {}
    )
}
