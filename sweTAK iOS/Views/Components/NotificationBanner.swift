import SwiftUI
import Combine

// MARK: - Notification Banner Manager

/// Manages in-app notification banners
public final class NotificationBannerManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = NotificationBannerManager()

    // MARK: - Published State

    @Published public private(set) var currentNotification: BannerNotification?
    @Published public private(set) var notificationQueue: [BannerNotification] = []

    // MARK: - Private

    private var dismissTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Show a chat notification banner
    public func showChatNotification(_ notification: IncomingChatNotification, onTap: @escaping () -> Void) {
        let banner = BannerNotification(
            id: notification.id,
            type: .chat,
            title: notification.displayName,
            message: notification.textPreview,
            icon: "message.fill",
            color: .blue,
            onTap: onTap
        )
        show(banner)
    }

    /// Show a generic notification banner
    public func show(_ notification: BannerNotification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.currentNotification != nil {
                // Queue the notification
                self.notificationQueue.append(notification)
            } else {
                // Show immediately
                self.presentNotification(notification)
            }
        }
    }

    /// Show a simple message banner
    public func showMessage(
        _ message: String,
        title: String? = nil,
        type: BannerNotificationType = .info,
        duration: TimeInterval = 3.0
    ) {
        let banner = BannerNotification(
            type: type,
            title: title,
            message: message,
            icon: type.icon,
            color: type.color,
            duration: duration
        )
        show(banner)
    }

    /// Dismiss current notification
    public func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil

        withAnimation(.easeOut(duration: 0.3)) {
            currentNotification = nil
        }

        // Show next queued notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.showNextQueued()
        }
    }

    /// Clear all notifications
    public func clearAll() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        currentNotification = nil
        notificationQueue.removeAll()
    }

    // MARK: - Private

    private func presentNotification(_ notification: BannerNotification) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentNotification = notification
        }

        // Auto-dismiss after duration
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: notification.duration, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    private func showNextQueued() {
        guard !notificationQueue.isEmpty else { return }
        let next = notificationQueue.removeFirst()
        presentNotification(next)
    }
}

// MARK: - Banner Notification Type

/// Types of notification banners
public enum BannerNotificationType: String {
    case chat
    case info
    case success
    case warning
    case error

    public var icon: String {
        switch self {
        case .chat: return "message.fill"
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    public var color: Color {
        switch self {
        case .chat: return .blue
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Banner Notification

/// Model for a notification banner
public struct BannerNotification: Identifiable, Equatable {
    public let id: String
    public let type: BannerNotificationType
    public let title: String?
    public let message: String
    public let icon: String
    public let color: Color
    public let duration: TimeInterval
    public let onTap: (() -> Void)?

    public init(
        id: String = UUID().uuidString,
        type: BannerNotificationType,
        title: String? = nil,
        message: String,
        icon: String? = nil,
        color: Color? = nil,
        duration: TimeInterval = 4.0,
        onTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.icon = icon ?? type.icon
        self.color = color ?? type.color
        self.duration = duration
        self.onTap = onTap
    }

    public static func == (lhs: BannerNotification, rhs: BannerNotification) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Notification Banner View

/// In-app notification banner that slides in from top
public struct NotificationBannerView: View {
    @ObservedObject private var manager = NotificationBannerManager.shared
    @State private var offset: CGFloat = -100
    @State private var dragOffset: CGFloat = 0

    public init() {}

    public var body: some View {
        VStack {
            if let notification = manager.currentNotification {
                bannerContent(notification)
                    .offset(y: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height < 0 {
                                    dragOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                if value.translation.height < -50 {
                                    manager.dismiss()
                                }
                                dragOffset = 0
                            }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.currentNotification?.id)
    }

    @ViewBuilder
    private func bannerContent(_ notification: BannerNotification) -> some View {
        Button {
            notification.onTap?()
            manager.dismiss()
        } label: {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: notification.icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(notification.color)
                    .clipShape(Circle())

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    if let title = notification.title {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }

                    Text(notification.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Dismiss indicator
                Image(systemName: "chevron.up")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
            )
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat Notification Banner

/// Specialized banner for chat notifications
public struct ChatNotificationBanner: View {
    let notification: IncomingChatNotification
    let onTap: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible = true

    public init(
        notification: IncomingChatNotification,
        onTap: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.notification = notification
        self.onTap = onTap
        self.onDismiss = onDismiss
    }

    public var body: some View {
        if isVisible {
            Button(action: {
                onTap()
                withAnimation {
                    isVisible = false
                }
            }) {
                HStack(spacing: 12) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 40, height: 40)

                        Text(String(notification.callsign.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    // Message content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notification.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text(notification.textPreview)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    // Close button
                    Button {
                        withAnimation {
                            isVisible = false
                        }
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Circle().fill(Color(.systemGray5)))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
                )
                .padding(.horizontal)
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Toast Notification

/// Simple toast-style notification at bottom of screen
public struct ToastNotification: View {
    let message: String
    let icon: String?
    let color: Color
    @Binding var isPresented: Bool

    public init(
        message: String,
        icon: String? = nil,
        color: Color = .primary,
        isPresented: Binding<Bool>
    ) {
        self.message = message
        self.icon = icon
        self.color = color
        self._isPresented = isPresented
    }

    public var body: some View {
        if isPresented {
            VStack {
                Spacer()

                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .foregroundColor(color)
                    }

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                )
                .padding(.bottom, 32)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - View Modifier for Notification Banner

/// View modifier to add notification banner overlay
public struct NotificationBannerModifier: ViewModifier {
    public func body(content: Content) -> some View {
        ZStack {
            content
            NotificationBannerView()
        }
    }
}

extension View {
    /// Adds notification banner overlay to the view
    public func withNotificationBanner() -> some View {
        modifier(NotificationBannerModifier())
    }
}

// MARK: - Preview

#Preview("Notification Banner") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        VStack {
            Button("Show Chat Notification") {
                let notification = IncomingChatNotification(
                    threadId: "thread-1",
                    fromDeviceId: "device-1",
                    textPreview: "Hey, are you at the checkpoint yet?",
                    callsign: "Alpha-1",
                    nickname: "Johnny"
                )
                NotificationBannerManager.shared.showChatNotification(notification) {
                    print("Tapped notification")
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Show Info") {
                NotificationBannerManager.shared.showMessage(
                    "Position updated successfully",
                    type: .success
                )
            }
            .buttonStyle(.bordered)

            Button("Show Warning") {
                NotificationBannerManager.shared.showMessage(
                    "Connection unstable",
                    title: "Network Warning",
                    type: .warning
                )
            }
            .buttonStyle(.bordered)
        }
    }
    .withNotificationBanner()
}
