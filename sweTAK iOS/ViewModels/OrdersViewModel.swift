import Foundation
import Combine
import os.log

/// ViewModel for managing military orders
/// Mirrors Android OrdersViewModel functionality
public final class OrdersViewModel: ObservableObject {

    // MARK: - Singleton

    public static let shared = OrdersViewModel()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "OrdersViewModel")

    // MARK: - Published State

    @Published public private(set) var orders: [Order] = []
    @Published public private(set) var recipientStatuses: [OrderRecipientStatus] = []
    @Published public private(set) var selectedOrder: Order?

    // MARK: - Incoming Notification

    private let incomingNotificationSubject = PassthroughSubject<Order, Never>()
    public var incomingNotification: AnyPublisher<Order, Never> {
        incomingNotificationSubject.eraseToAnyPublisher()
    }

    // MARK: - Configuration

    private var myDeviceId: String = ""

    // MARK: - Storage Keys

    private enum Keys {
        static let orders = "swetak_orders"
        static let recipientStatuses = "swetak_order_statuses"
    }

    // MARK: - Initialization

    private init() {
        loadFromStorage()
        setupListeners()
    }

    // MARK: - Listeners

    private func setupListeners() {
        TransportCoordinator.shared.orderListener = self
    }

    // MARK: - Storage

    private func loadFromStorage() {
        // Load orders
        if let data = UserDefaults.standard.data(forKey: Keys.orders),
           let storedOrders = try? JSONDecoder().decode([Order].self, from: data) {
            orders = storedOrders
            logger.info("Loaded \(storedOrders.count) orders from storage")
        }

        // Load recipient statuses
        if let data = UserDefaults.standard.data(forKey: Keys.recipientStatuses),
           let storedStatuses = try? JSONDecoder().decode([OrderRecipientStatus].self, from: data) {
            recipientStatuses = storedStatuses
        }
    }

    private func saveOrders() {
        if let data = try? JSONEncoder().encode(orders) {
            UserDefaults.standard.set(data, forKey: Keys.orders)
        }
    }

    private func saveRecipientStatuses() {
        if let data = try? JSONEncoder().encode(recipientStatuses) {
            UserDefaults.standard.set(data, forKey: Keys.recipientStatuses)
        }
    }

    // MARK: - Configuration

    /// Start listening for orders
    public func startListening(deviceId: String) {
        myDeviceId = deviceId
        logger.info("Started order listener for device \(deviceId)")
    }

    // MARK: - Order Operations

    /// Send a new order
    public func sendOrder(_ order: Order) {
        orders.append(order)
        saveOrders()

        // Add initial recipient statuses
        let newStatuses = order.recipientDeviceIds.map { recipientId in
            OrderRecipientStatus(
                orderId: order.id,
                recipientDeviceId: recipientId,
                recipientCallsign: ContactsViewModel.shared.contacts.first(where: { $0.deviceId == recipientId })?.callsign,
                sentAtMillis: Date.currentMillis
            )
        }
        recipientStatuses.append(contentsOf: newStatuses)
        saveRecipientStatuses()

        // Send over network
        TransportCoordinator.shared.sendOrder(order)

        logger.info("Sent order \(order.id) to \(order.recipientDeviceIds.count) recipients")
    }

    /// Mark an order as read and send READ ACK
    public func markAsRead(_ order: Order) {
        guard let index = orders.firstIndex(where: { $0.id == order.id }) else { return }

        orders[index] = Order(
            id: order.id,
            type: order.type,
            createdAtMillis: order.createdAtMillis,
            senderDeviceId: order.senderDeviceId,
            senderCallsign: order.senderCallsign,
            orientation: order.orientation,
            decision: order.decision,
            order: order.order,
            mission: order.mission,
            execution: order.execution,
            logistics: order.logistics,
            commandSignaling: order.commandSignaling,
            recipientDeviceIds: order.recipientDeviceIds,
            direction: order.direction,
            isRead: true
        )
        saveOrders()

        // Send READ ACK
        if !myDeviceId.isEmpty {
            let ack = OrderAck(
                orderId: order.id,
                fromDeviceId: myDeviceId,
                toDeviceId: order.senderDeviceId,
                ackType: .read
            )
            TransportCoordinator.shared.sendOrderAck(ack)
        }

        logger.debug("Marked order \(order.id) as read")
    }

    /// Select an order for detail view
    public func selectOrder(_ order: Order?) {
        selectedOrder = order
    }

    /// Get recipient statuses for an order
    public func getRecipientStatuses(forOrder orderId: String) -> [OrderRecipientStatus] {
        recipientStatuses.filter { $0.orderId == orderId }
    }

    /// Get order by ID
    public func getOrder(byId orderId: String) -> Order? {
        orders.first { $0.id == orderId }
    }

    // MARK: - Computed Properties

    /// Incoming orders (received, not sent by us)
    public var incomingOrders: [Order] {
        orders.filter { $0.direction == .incoming }
    }

    /// Outgoing orders (sent by us)
    public var outgoingOrders: [Order] {
        orders.filter { $0.direction == .outgoing }
    }

    /// Unread orders count
    public var unreadCount: Int {
        orders.filter { $0.direction == .incoming && !$0.isRead }.count
    }

    /// Orders sorted by date (newest first)
    public var sortedOrders: [Order] {
        orders.sorted { $0.createdAtMillis > $1.createdAtMillis }
    }

    // MARK: - Private Handlers

    private func handleIncomingOrder(_ order: Order) {
        // Check if order already exists
        if let index = orders.firstIndex(where: { $0.id == order.id }) {
            orders[index] = order
        } else {
            orders.append(order)
        }
        saveOrders()

        // Emit notification
        incomingNotificationSubject.send(order)

        // Auto-send DELIVERED ACK
        if !myDeviceId.isEmpty {
            let ack = OrderAck(
                orderId: order.id,
                fromDeviceId: myDeviceId,
                toDeviceId: order.senderDeviceId,
                ackType: .delivered
            )
            TransportCoordinator.shared.sendOrderAck(ack)
        }

        logger.info("Received order \(order.id), sent DELIVERED ACK")
    }

    private func handleAck(_ ack: OrderAck) {
        // Find existing status
        if let index = recipientStatuses.firstIndex(where: {
            $0.orderId == ack.orderId && $0.recipientDeviceId == ack.fromDeviceId
        }) {
            var status = recipientStatuses[index]
            switch ack.ackType {
            case .delivered:
                status = OrderRecipientStatus(
                    orderId: status.orderId,
                    recipientDeviceId: status.recipientDeviceId,
                    recipientCallsign: status.recipientCallsign,
                    sentAtMillis: status.sentAtMillis,
                    deliveredAtMillis: ack.timestampMillis,
                    readAtMillis: status.readAtMillis
                )
            case .read:
                status = OrderRecipientStatus(
                    orderId: status.orderId,
                    recipientDeviceId: status.recipientDeviceId,
                    recipientCallsign: status.recipientCallsign,
                    sentAtMillis: status.sentAtMillis,
                    deliveredAtMillis: status.deliveredAtMillis,
                    readAtMillis: ack.timestampMillis
                )
            }
            recipientStatuses[index] = status
        } else {
            // Create new status
            let newStatus = OrderRecipientStatus(
                orderId: ack.orderId,
                recipientDeviceId: ack.fromDeviceId,
                recipientCallsign: ContactsViewModel.shared.contacts.first(where: { $0.deviceId == ack.fromDeviceId })?.callsign,
                sentAtMillis: Date.currentMillis,
                deliveredAtMillis: ack.ackType == .delivered ? ack.timestampMillis : nil,
                readAtMillis: ack.ackType == .read ? ack.timestampMillis : nil
            )
            recipientStatuses.append(newStatus)
        }
        saveRecipientStatuses()

        logger.debug("Received \(ack.ackType.rawValue) ACK for order \(ack.orderId)")
    }
}

// MARK: - OrderListener

extension OrdersViewModel: OrderListener {
    public func onOrderReceived(order: Order) {
        DispatchQueue.main.async { [weak self] in
            self?.handleIncomingOrder(order)
        }
    }

    public func onOrderAckReceived(ack: OrderAck) {
        DispatchQueue.main.async { [weak self] in
            self?.handleAck(ack)
        }
    }
}
