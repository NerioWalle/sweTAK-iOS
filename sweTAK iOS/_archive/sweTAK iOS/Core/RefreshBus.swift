import Foundation
import Combine
import os.log

// MARK: - Refresh Event Types

/// Types of refresh events that can be emitted
public enum RefreshEvent: Equatable {
    /// Profile has been updated
    case profileChanged

    /// Settings have been updated
    case settingsChanged

    /// Contacts list needs refresh
    case contactsChanged

    /// Pins need refresh
    case pinsChanged

    /// Chat data needs refresh
    case chatChanged

    /// Network connection state changed
    case connectionChanged

    /// Transport mode changed (MQTT/UDP)
    case transportModeChanged

    /// Full sync requested
    case syncRequested

    /// Map needs refresh
    case mapRefresh

    /// Custom event with payload
    case custom(String)
}

// MARK: - Refresh Bus

/// App-wide event bus for refresh notifications
/// Mirrors Android RefreshBus functionality using Combine
public final class RefreshBus: ObservableObject {

    // MARK: - Singleton

    public static let shared = RefreshBus()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "RefreshBus")

    // MARK: - Publishers

    /// Main event publisher
    private let eventSubject = PassthroughSubject<RefreshEvent, Never>()

    /// Public publisher for observing events
    public var events: AnyPublisher<RefreshEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    // MARK: - Specific Event Publishers

    /// Profile change events
    public var profileChanges: AnyPublisher<Void, Never> {
        eventSubject
            .filter { $0 == .profileChanged }
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    /// Settings change events
    public var settingsChanges: AnyPublisher<Void, Never> {
        eventSubject
            .filter { $0 == .settingsChanged }
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    /// Connection state changes
    public var connectionChanges: AnyPublisher<Void, Never> {
        eventSubject
            .filter { $0 == .connectionChanged }
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    /// Sync request events
    public var syncRequests: AnyPublisher<Void, Never> {
        eventSubject
            .filter { $0 == .syncRequested }
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Emit Methods

    /// Emit a refresh event
    public func emit(_ event: RefreshEvent) {
        logger.debug("Emitting event: \(String(describing: event))")
        eventSubject.send(event)
    }

    /// Profile changed
    public func emitProfileChanged() {
        emit(.profileChanged)
    }

    /// Settings changed
    public func emitSettingsChanged() {
        emit(.settingsChanged)
    }

    /// Contacts changed
    public func emitContactsChanged() {
        emit(.contactsChanged)
    }

    /// Pins changed
    public func emitPinsChanged() {
        emit(.pinsChanged)
    }

    /// Chat changed
    public func emitChatChanged() {
        emit(.chatChanged)
    }

    /// Connection state changed
    public func emitConnectionChanged() {
        emit(.connectionChanged)
    }

    /// Transport mode changed
    public func emitTransportModeChanged() {
        emit(.transportModeChanged)
    }

    /// Request full sync
    public func emitSyncRequested() {
        emit(.syncRequested)
    }

    /// Map refresh needed
    public func emitMapRefresh() {
        emit(.mapRefresh)
    }

    /// Custom event
    public func emitCustom(_ name: String) {
        emit(.custom(name))
    }
}

// MARK: - Subscription Helpers

extension RefreshBus {

    /// Subscribe to specific event type
    public func subscribe(
        to event: RefreshEvent,
        handler: @escaping () -> Void
    ) -> AnyCancellable {
        eventSubject
            .filter { $0 == event }
            .receive(on: DispatchQueue.main)
            .sink { _ in handler() }
    }

    /// Subscribe to multiple event types
    public func subscribe(
        to events: [RefreshEvent],
        handler: @escaping (RefreshEvent) -> Void
    ) -> AnyCancellable {
        eventSubject
            .filter { events.contains($0) }
            .receive(on: DispatchQueue.main)
            .sink { handler($0) }
    }

    /// Subscribe to all events
    public func subscribeAll(
        handler: @escaping (RefreshEvent) -> Void
    ) -> AnyCancellable {
        eventSubject
            .receive(on: DispatchQueue.main)
            .sink { handler($0) }
    }
}

// MARK: - View Integration

import SwiftUI

extension RefreshBus {

    /// Create a view modifier that responds to refresh events
    public func onRefresh(
        _ event: RefreshEvent,
        perform action: @escaping () -> Void
    ) -> some ViewModifier {
        RefreshEventModifier(bus: self, event: event, action: action)
    }
}

/// View modifier for refresh events
private struct RefreshEventModifier: ViewModifier {
    let bus: RefreshBus
    let event: RefreshEvent
    let action: () -> Void

    @State private var cancellable: AnyCancellable?

    func body(content: Content) -> some View {
        content
            .onAppear {
                cancellable = bus.subscribe(to: event, handler: action)
            }
            .onDisappear {
                cancellable?.cancel()
            }
    }
}

// MARK: - View Extension

extension View {

    /// Subscribe to refresh bus events
    public func onRefreshEvent(
        _ event: RefreshEvent,
        perform action: @escaping () -> Void
    ) -> some View {
        self.modifier(RefreshEventModifier(
            bus: RefreshBus.shared,
            event: event,
            action: action
        ))
    }
}
