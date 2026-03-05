// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Validates stream keys for incoming publisher connections.
///
/// Implement this protocol to control which publishers are allowed
/// to stream to the server.
public protocol StreamKeyValidator: Sendable {
    /// Returns true if the given stream key is allowed to publish
    /// to the given app.
    ///
    /// - Parameters:
    ///   - streamKey: The stream key from the publish command.
    ///   - app: The application name from the connect command.
    /// - Returns: `true` if the key is valid and publishing should proceed.
    func isValid(streamKey: String, app: String) async -> Bool
}

/// A stream key validator that accepts any key.
///
/// This is the default validator — no authentication is performed.
public struct AllowAllStreamKeyValidator: StreamKeyValidator, Sendable {

    /// Creates a new allow-all validator.
    public init() {}

    /// Always returns true.
    public func isValid(streamKey: String, app: String) async -> Bool {
        true
    }
}

/// A stream key validator backed by a fixed allow-list.
///
/// Stream keys are compared case-sensitively against the allow-list.
public struct AllowListStreamKeyValidator: StreamKeyValidator, Sendable {

    /// The set of allowed stream keys (case-sensitive).
    public let allowedKeys: Set<String>

    /// Creates a new allow-list validator.
    ///
    /// - Parameter allowedKeys: The set of stream keys to accept.
    public init(allowedKeys: Set<String>) {
        self.allowedKeys = allowedKeys
    }

    /// Returns true if the stream key is in the allow-list.
    public func isValid(streamKey: String, app: String) async -> Bool {
        allowedKeys.contains(streamKey)
    }
}

/// A stream key validator that uses a custom async closure.
///
/// Use this for dynamic validation logic such as database lookups
/// or external API calls.
public struct ClosureStreamKeyValidator: StreamKeyValidator, Sendable {

    private let validateClosure: @Sendable (String, String) async -> Bool

    /// Creates a new closure-based validator.
    ///
    /// - Parameter validate: An async closure that receives
    ///   `(streamKey, app)` and returns whether publishing is allowed.
    public init(
        validate: @escaping @Sendable (String, String) async -> Bool
    ) {
        self.validateClosure = validate
    }

    /// Calls the underlying closure.
    public func isValid(streamKey: String, app: String) async -> Bool {
        await validateClosure(streamKey, app)
    }
}
