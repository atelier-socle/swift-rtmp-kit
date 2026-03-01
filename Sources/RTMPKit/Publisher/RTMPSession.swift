// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// RTMP session state machine with validated transitions.
///
/// Ensures the publish lifecycle follows the correct order and prevents
/// invalid state transitions (e.g., publishing before connected).
public struct RTMPSession: Sendable {

    /// Current session state.
    public private(set) var state: RTMPPublisherState

    /// Creates a new session in idle state.
    public init() {
        self.state = .idle
    }

    /// Attempt a state transition.
    ///
    /// - Parameter newState: The target state.
    /// - Returns: `true` if the transition was valid and applied,
    ///   `false` if rejected.
    @discardableResult
    public mutating func transition(to newState: RTMPPublisherState) -> Bool {
        guard canTransition(to: newState) else {
            return false
        }
        state = newState
        return true
    }

    /// Check if a transition to the given state is valid from current state.
    ///
    /// - Parameter newState: The target state.
    /// - Returns: `true` if the transition is allowed.
    public func canTransition(to newState: RTMPPublisherState) -> Bool {
        // Any state → disconnected is always valid (force disconnect).
        if newState == .disconnected { return true }

        let allowed = allowedCategories(from: state)
        return allowed.contains(newState.category)
    }

    /// Reset to idle state.
    ///
    /// Valid from ``RTMPPublisherState/failed(_:)``
    /// and ``RTMPPublisherState/disconnected``.
    /// Also usable from any state for a hard reset.
    public mutating func reset() {
        state = .idle
    }

    // MARK: - Private

    private func allowedCategories(
        from source: RTMPPublisherState
    ) -> Set<RTMPPublisherState.Category> {
        switch source {
        case .idle: [.connecting]
        case .connecting: [.handshaking, .failed]
        case .handshaking: [.connected, .failed]
        case .connected: [.publishing]
        case .publishing: [.failed, .reconnecting]
        case .reconnecting: [.connecting, .failed]
        case .failed: [.idle]
        case .disconnected: [.idle]
        }
    }
}

// MARK: - State Category

extension RTMPPublisherState {
    /// State category for transition validation (ignores associated values).
    internal enum Category: Hashable {
        case idle, connecting, handshaking, connected
        case publishing, reconnecting, disconnected, failed
    }

    /// The category of this state (strips associated values).
    internal var category: Category {
        switch self {
        case .idle: .idle
        case .connecting: .connecting
        case .handshaking: .handshaking
        case .connected: .connected
        case .publishing: .publishing
        case .reconnecting: .reconnecting
        case .disconnected: .disconnected
        case .failed: .failed
        }
    }
}
