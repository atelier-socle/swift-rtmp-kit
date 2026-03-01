// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Reconnection strategy with exponential backoff and configurable jitter.
///
/// Calculates delay for each reconnection attempt:
/// `delay = min(initialDelay * multiplier^attempt + randomJitter, maxDelay)`
///
/// The jitter factor adds randomness to prevent thundering herd when
/// many clients reconnect simultaneously.
///
/// ## Presets
/// - ``default``: 5 attempts, 1s initial, 30s max, 2x multiplier, 10% jitter
/// - ``aggressive``: 10 attempts, 0.5s initial, 15s max, 1.5x multiplier
/// - ``conservative``: 3 attempts, 2s initial, 60s max, 3x multiplier
/// - ``none``: No reconnection
public struct ReconnectPolicy: Sendable, Equatable {

    /// Maximum number of reconnection attempts before giving up.
    public var maxAttempts: Int

    /// Initial delay before the first reconnection attempt (seconds).
    public var initialDelay: Double

    /// Maximum delay between attempts (seconds). Caps exponential growth.
    public var maxDelay: Double

    /// Multiplier applied to delay on each attempt. Typical: 2.0.
    public var multiplier: Double

    /// Jitter factor (0.0 to 1.0). 0.1 = ±10% randomness on each delay.
    public var jitter: Double

    /// Creates a reconnection policy.
    ///
    /// - Parameters:
    ///   - maxAttempts: Maximum attempts before giving up.
    ///   - initialDelay: Delay before first attempt (seconds).
    ///   - maxDelay: Maximum delay cap (seconds).
    ///   - multiplier: Exponential backoff multiplier.
    ///   - jitter: Jitter factor (0.0 to 1.0).
    public init(
        maxAttempts: Int = 5,
        initialDelay: Double = 1.0,
        maxDelay: Double = 30.0,
        multiplier: Double = 2.0,
        jitter: Double = 0.1
    ) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
        self.jitter = jitter
    }

    /// Whether reconnection is enabled at all.
    public var isEnabled: Bool {
        maxAttempts > 0
    }

    /// Calculate the delay for a given attempt number (0-indexed).
    ///
    /// Returns `nil` if the attempt number is out of range
    /// (negative or >= ``maxAttempts``), meaning reconnection is exhausted.
    ///
    /// - Parameter attempt: The 0-indexed attempt number.
    /// - Returns: The delay in seconds, or `nil` if attempts are exhausted.
    public func delay(forAttempt attempt: Int) -> Double? {
        guard attempt >= 0, attempt < maxAttempts else { return nil }

        let baseDelay = initialDelay * Self.power(multiplier, attempt)
        let jittered = applyJitter(to: baseDelay)
        return min(jittered, maxDelay)
    }

    /// Calculate the deterministic base delay without jitter (for testing).
    ///
    /// - Parameter attempt: The 0-indexed attempt number.
    /// - Returns: The base delay before jitter, or `nil` if exhausted.
    public func baseDelay(forAttempt attempt: Int) -> Double? {
        guard attempt >= 0, attempt < maxAttempts else { return nil }

        let base = initialDelay * Self.power(multiplier, attempt)
        return min(base, maxDelay)
    }

    // MARK: - Presets

    /// Default policy: 5 attempts, 1s initial, 30s max, 2x multiplier,
    /// 10% jitter.
    public static let `default` = ReconnectPolicy(
        maxAttempts: 5,
        initialDelay: 1.0,
        maxDelay: 30.0,
        multiplier: 2.0,
        jitter: 0.1
    )

    /// Aggressive: 10 attempts, 0.5s initial, 15s max, 1.5x multiplier,
    /// 5% jitter.
    public static let aggressive = ReconnectPolicy(
        maxAttempts: 10,
        initialDelay: 0.5,
        maxDelay: 15.0,
        multiplier: 1.5,
        jitter: 0.05
    )

    /// Conservative: 3 attempts, 2s initial, 60s max, 3x multiplier,
    /// 20% jitter.
    public static let conservative = ReconnectPolicy(
        maxAttempts: 3,
        initialDelay: 2.0,
        maxDelay: 60.0,
        multiplier: 3.0,
        jitter: 0.2
    )

    /// No reconnection. ``maxAttempts`` is 0.
    public static let none = ReconnectPolicy(
        maxAttempts: 0,
        initialDelay: 0,
        maxDelay: 0,
        multiplier: 0,
        jitter: 0
    )

    // MARK: - Private

    private func applyJitter(to base: Double) -> Double {
        guard jitter > 0 else { return base }
        let range = base * jitter
        let offset = Double.random(in: -range...range)
        return base + offset
    }

    /// Integer power of a Double (avoids Foundation/Darwin `pow` import).
    private static func power(_ base: Double, _ exponent: Int) -> Double {
        guard exponent > 0 else { return 1.0 }
        var result = 1.0
        for _ in 0..<exponent {
            result *= base
        }
        return result
    }
}
