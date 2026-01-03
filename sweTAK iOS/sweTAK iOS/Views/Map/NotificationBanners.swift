import SwiftUI

// Note: IncomingChatNotification is defined in ChatMessage.swift

// MARK: - Base Notification Banner

/// Base notification banner component with common styling
public struct NotificationBanner: View {
    let icon: String
    let title: String
    let subtitle: String
    let backgroundColor: Color
    let contentColor: Color
    let titleBold: Bool
    let onClick: () -> Void
    let onDismiss: () -> Void

    public init(
        icon: String,
        title: String,
        subtitle: String,
        backgroundColor: Color,
        contentColor: Color = .white,
        titleBold: Bool = false,
        onClick: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.backgroundColor = backgroundColor
        self.contentColor = contentColor
        self.titleBold = titleBold
        self.onClick = onClick
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(contentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(titleBold ? .bold : .medium)
                    .foregroundColor(contentColor)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(contentColor.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(contentColor.opacity(0.8))
                    .padding(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .onTapGesture(perform: onClick)
    }
}

// Note: ChatNotificationBanner is defined in Components/NotificationBanner.swift

// MARK: - Order Notification Banner

/// Order notification banner
public struct OrderNotificationBanner: View {
    let order: Order
    let onClick: () -> Void
    let onDismiss: () -> Void

    public init(
        order: Order,
        onClick: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.order = order
        self.onClick = onClick
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NotificationBanner(
            icon: "doc.text.fill",
            title: "New \(order.type.displayName) Order",
            subtitle: "From: \(senderName)",
            backgroundColor: .blue.opacity(0.95),
            contentColor: .white,
            onClick: onClick,
            onDismiss: onDismiss
        )
    }

    private var senderName: String {
        order.senderCallsign.isEmpty ? String(order.senderDeviceId.prefix(8)) : order.senderCallsign
    }
}

// MARK: - Report Notification Banner

/// PEDARS report notification banner
public struct ReportNotificationBanner: View {
    let report: Report
    let onClick: () -> Void
    let onDismiss: () -> Void

    public init(
        report: Report,
        onClick: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.report = report
        self.onClick = onClick
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NotificationBanner(
            icon: "doc.plaintext.fill",
            title: "New PEDARS Report",
            subtitle: "From: \(senderName)",
            backgroundColor: .blue.opacity(0.95),
            contentColor: .white,
            onClick: onClick,
            onDismiss: onDismiss
        )
    }

    private var senderName: String {
        report.senderCallsign.isEmpty ? String(report.senderDeviceId.prefix(8)) : report.senderCallsign
    }
}

// MARK: - METHANE Notification Banner

/// METHANE emergency notification banner
public struct MethaneNotificationBanner: View {
    let request: MethaneRequest
    let onClick: () -> Void
    let onDismiss: () -> Void

    public init(
        request: MethaneRequest,
        onClick: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.request = request
        self.onClick = onClick
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NotificationBanner(
            icon: "exclamationmark.triangle.fill",
            title: "METHANE Emergency",
            subtitle: "From: \(senderName) - \(request.incidentType)",
            backgroundColor: Color.red.opacity(0.95),
            contentColor: .white,
            titleBold: true,
            onClick: onClick,
            onDismiss: onDismiss
        )
    }

    private var senderName: String {
        request.senderCallsign.isEmpty ? String(request.senderDeviceId.prefix(8)) : request.senderCallsign
    }
}

// MARK: - MEDEVAC Notification Banner

/// MEDEVAC (MIST) notification banner
public struct MedevacNotificationBanner: View {
    let report: MedevacReport
    let onClick: () -> Void
    let onDismiss: () -> Void

    public init(
        report: MedevacReport,
        onClick: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.report = report
        self.onClick = onClick
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NotificationBanner(
            icon: "cross.case.fill",
            title: "MIST - \(report.priority.displayName)",
            subtitle: "From: \(senderName) - \(report.soldierName)",
            backgroundColor: priorityColor,
            contentColor: .white,
            titleBold: true,
            onClick: onClick,
            onDismiss: onDismiss
        )
    }

    private var senderName: String {
        report.senderCallsign.isEmpty ? String(report.senderDeviceId.prefix(8)) : report.senderCallsign
    }

    private var priorityColor: Color {
        switch report.priority {
        case .p1: return .red
        case .p2: return .orange
        case .p3: return .green
        case .deceased: return .gray
        }
    }
}

// MARK: - Notification Banner Container

/// Container view for displaying notification banners at top of screen
public struct NotificationBannerContainer<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack {
            content
                .padding(.horizontal, 16)
                .padding(.top, 8)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: UUID())
    }
}

// MARK: - Previews

#Preview("Chat Notification") {
    ZStack {
        Color.gray.opacity(0.3)

        NotificationBannerContainer {
            ChatNotificationBanner(
                notification: IncomingChatNotification(
                    threadId: "thread-1",
                    fromDeviceId: "device-1",
                    textPreview: "Roger that, moving to position now",
                    callsign: "Alpha-1",
                    nickname: "John"
                ),
                onTap: {},
                onDismiss: {}
            )
        }
    }
}

#Preview("Order Notification") {
    ZStack {
        Color.gray.opacity(0.3)

        NotificationBannerContainer {
            OrderNotificationBanner(
                order: Order(
                    type: .obo,
                    senderDeviceId: "device-123",
                    senderCallsign: "Command-1",
                    orientation: "Test",
                    recipientDeviceIds: [],
                    direction: .incoming
                ),
                onClick: {},
                onDismiss: {}
            )
        }
    }
}

#Preview("METHANE Notification") {
    ZStack {
        Color.gray.opacity(0.3)

        NotificationBannerContainer {
            MethaneNotificationBanner(
                request: MethaneRequest(
                    senderDeviceId: "device-123",
                    senderCallsign: "Bravo-2",
                    callsign: "Bravo-2",
                    unit: "Alpha Company",
                    incidentLocation: "Highway 5, Exit 12",
                    incidentTime: "1430",
                    incidentType: "Traffic Accident",
                    hazards: "Fuel spill",
                    approachRoutes: "From north only",
                    assetsPresent: "Fire",
                    assetsRequired: "EMS",
                    recipientDeviceIds: [],
                    direction: .outgoing
                ),
                onClick: {},
                onDismiss: {}
            )
        }
    }
}

#Preview("MEDEVAC Notification") {
    ZStack {
        Color.gray.opacity(0.3)

        NotificationBannerContainer {
            MedevacNotificationBanner(
                report: MedevacReport(
                    senderDeviceId: "device-123",
                    senderCallsign: "Medic-1",
                    soldierName: "Pvt. Smith",
                    priority: .p1,
                    ageInfo: "Adult",
                    incidentTime: "1430",
                    mechanismOfInjury: "Shrapnel",
                    injuryDescription: "Leg wound",
                    signsSymptoms: "Bleeding",
                    caretakerName: "Sgt. Johnson",
                    recipientDeviceIds: [],
                    direction: .outgoing
                ),
                onClick: {},
                onDismiss: {}
            )
        }
    }
}
