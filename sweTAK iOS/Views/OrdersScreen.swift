import SwiftUI

/// Orders list screen showing incoming and outgoing military orders
/// Mirrors Android OrdersListScreen functionality
public struct OrdersListScreen: View {
    @ObservedObject private var ordersVM = OrdersViewModel.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0
    @State private var selectedOrder: Order?
    @State private var showingOrderDetail = false
    @State private var showingCreateOBO = false
    @State private var showingCreateFiveP = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("", selection: $selectedTab) {
                    HStack {
                        Text("Incoming (\(ordersVM.incomingOrders.count))")
                        if unreadIncomingCount > 0 {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .tag(0)

                    Text("Outgoing (\(ordersVM.outgoingOrders.count))")
                        .tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // Orders list
                if displayOrders.isEmpty {
                    emptyStateView
                } else {
                    ordersList
                }
            }
            .navigationTitle("Orders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingCreateOBO = true
                        } label: {
                            Label("OBO Order", systemImage: "doc.text")
                        }
                        Button {
                            showingCreateFiveP = true
                        } label: {
                            Label("5P Order", systemImage: "list.number")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingOrderDetail) {
                if let order = selectedOrder {
                    OrderDetailScreen(order: order)
                }
            }
            .sheet(isPresented: $showingCreateOBO) {
                CreateOBOOrderScreen()
            }
            .sheet(isPresented: $showingCreateFiveP) {
                CreateFivePOrderScreen()
            }
        }
    }

    // MARK: - Computed Properties

    private var displayOrders: [Order] {
        let orders = selectedTab == 0 ? ordersVM.incomingOrders : ordersVM.outgoingOrders
        return orders.sorted { $0.createdAtMillis > $1.createdAtMillis }
    }

    private var unreadIncomingCount: Int {
        ordersVM.incomingOrders.filter { !$0.isRead }.count
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(selectedTab == 0 ? "No incoming orders" : "No outgoing orders")
                .font(.headline)

            Text(selectedTab == 0
                 ? "Orders sent to you will appear here."
                 : "Orders you send will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Orders List

    private var ordersList: some View {
        List {
            ForEach(displayOrders) { order in
                OrderListItem(
                    order: order,
                    recipientStatuses: ordersVM.getRecipientStatuses(forOrder: order.id)
                )
                .onTapGesture {
                    selectedOrder = order
                    showingOrderDetail = true

                    // Mark as read when opening
                    if order.direction == .incoming && !order.isRead {
                        ordersVM.markAsRead(order)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Order List Item

private struct OrderListItem: View {
    let order: Order
    let recipientStatuses: [OrderRecipientStatus]

    private var typeColor: Color {
        switch order.type {
        case .obo: return .blue
        case .fiveP: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Unread indicator
            if order.direction == .incoming && !order.isRead {
                Circle()
                    .fill(.blue)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 6) {
                // Header row with type badge
                HStack {
                    // Type badge
                    Text(order.type.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(typeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(typeColor.opacity(0.15))
                        .cornerRadius(4)

                    Spacer()

                    Text(formatDate(order.createdAtMillis))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Sender/recipient info
                if order.direction == .incoming {
                    Text("From: \(order.senderCallsign.isEmpty ? String(order.senderDeviceId.prefix(8)) : order.senderCallsign)")
                        .font(.subheadline)
                } else {
                    let total = order.recipientDeviceIds.count
                    let delivered = recipientStatuses.filter { $0.isDelivered }.count
                    let read = recipientStatuses.filter { $0.isRead }.count

                    Text("To: \(total) recipient\(total != 1 ? "s" : "")")
                        .font(.subheadline)

                    if total > 0 {
                        Text("Delivered: \(delivered), Read: \(read)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Preview of orientation text
                Text(order.orientation.prefix(100) + (order.orientation.count > 100 ? "..." : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func formatDate(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(millis) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Order Detail Screen

public struct OrderDetailScreen: View {
    let order: Order

    @ObservedObject private var ordersVM = OrdersViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingDuplicateOBO = false
    @State private var showingDuplicateFiveP = false

    public init(order: Order) {
        self.order = order
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection

                    Divider()

                    // Order content based on type
                    if order.type == .obo {
                        oboContent
                    } else {
                        fivePContent
                    }

                    // Recipient status for outgoing orders
                    if order.direction == .outgoing && !order.recipientDeviceIds.isEmpty {
                        recipientStatusSection
                    }

                    Divider()

                    // Action buttons
                    VStack(spacing: 12) {
                        // Duplicate button
                        Button {
                            if order.type == .obo {
                                showingDuplicateOBO = true
                            } else {
                                showingDuplicateFiveP = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Duplicate Order")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }

                        // Delete button
                        Button(role: .destructive) {
                            ordersVM.deleteOrder(order)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Order")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle(order.type.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDuplicateOBO) {
                CreateOBOOrderScreen(
                    duplicateFrom: order
                )
            }
            .sheet(isPresented: $showingDuplicateFiveP) {
                CreateFivePOrderScreen(
                    duplicateFrom: order
                )
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(order.type.displayName, systemImage: "doc.text.fill")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)

                Spacer()

                if order.direction == .incoming && !order.isRead {
                    Text("UNREAD")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(4)
                }
            }

            if order.direction == .incoming {
                Text("From: \(order.senderCallsign.isEmpty ? order.senderDeviceId : order.senderCallsign)")
                    .font(.subheadline)
            } else {
                Text("To: \(order.recipientDeviceIds.count) recipient(s)")
                    .font(.subheadline)
            }

            Text("Created: \(formatFullDate(order.createdAtMillis))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - OBO Content

    private var oboContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            OrderSection(title: "Orientation (O)", content: order.orientation)
            OrderSection(title: "Decision (B)", content: order.decision)
            OrderSection(title: "Order (O)", content: order.order)
        }
    }

    // MARK: - 5P Content

    private var fivePContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            OrderSection(title: "Purpose", content: order.orientation)
            OrderSection(title: "Plan", content: order.decision)
            OrderSection(title: "Preconditions", content: order.order)

            if !order.mission.isEmpty {
                OrderSection(title: "Mission", content: order.mission)
            }
            if !order.execution.isEmpty {
                OrderSection(title: "Execution", content: order.execution)
            }
            if !order.logistics.isEmpty {
                OrderSection(title: "Logistics", content: order.logistics)
            }
            if !order.commandSignaling.isEmpty {
                OrderSection(title: "Command & Signaling", content: order.commandSignaling)
            }
        }
    }

    // MARK: - Recipient Status Section

    private var recipientStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipient Status")
                .font(.headline)

            let statuses = ordersVM.getRecipientStatuses(forOrder: order.id)

            ForEach(order.recipientDeviceIds, id: \.self) { deviceId in
                let status = statuses.first { $0.recipientDeviceId == deviceId }
                RecipientStatusRow(
                    deviceId: deviceId,
                    callsign: status?.recipientCallsign,
                    status: status
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatFullDate(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(millis) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Order Section

private struct OrderSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundColor(.blue)

            if content.isEmpty {
                Text("-")
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                Text(content)
                    .font(.body)
            }
        }
    }
}

// MARK: - Recipient Status Row

private struct RecipientStatusRow: View {
    let deviceId: String
    let callsign: String?
    let status: OrderRecipientStatus?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(callsign ?? String(deviceId.prefix(8)))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(deviceId)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                // Delivered status
                VStack(spacing: 2) {
                    Image(systemName: status?.isDelivered == true ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundColor(status?.isDelivered == true ? .green : .gray)
                    Text("Delivered")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Read status
                VStack(spacing: 2) {
                    Image(systemName: status?.isRead == true ? "eye.fill" : "eye")
                        .foregroundColor(status?.isRead == true ? .blue : .gray)
                    Text("Read")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview("Orders List") {
    OrdersListScreen()
}

#Preview("Order Detail") {
    OrderDetailScreen(order: Order(
        type: .obo,
        senderDeviceId: "device-123",
        senderCallsign: "Command-1",
        orientation: "Enemy forces spotted at grid reference 12345678. Estimated strength: 1 platoon.",
        decision: "We will engage from elevated position to the north.",
        order: "Squad 1 advance to waypoint Alpha. Squad 2 provide covering fire.",
        recipientDeviceIds: ["device-a", "device-b"],
        direction: .outgoing
    ))
}
