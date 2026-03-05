// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Describes the class traits of an AMF3 Object.
///
/// Traits define the structure of an AMF3 object: its class name,
/// whether it supports dynamic properties, and the names of its
/// sealed (fixed) properties.
public struct AMF3Traits: Sendable, Equatable {
    /// Class name. Empty string for anonymous/dynamic objects.
    public let className: String
    /// Whether this object is dynamic (can have extra properties beyond sealed ones).
    public let isDynamic: Bool
    /// Whether this object is externalizable (handles its own serialization).
    public let isExternalizable: Bool
    /// Names of sealed properties, in declaration order.
    public let properties: [String]

    /// Creates traits with the given attributes.
    ///
    /// - Parameters:
    ///   - className: Class name (default: empty string for anonymous).
    ///   - isDynamic: Whether the object is dynamic (default: true).
    ///   - isExternalizable: Whether the object is externalizable (default: false).
    ///   - properties: Sealed property names in order (default: empty).
    public init(
        className: String = "",
        isDynamic: Bool = true,
        isExternalizable: Bool = false,
        properties: [String] = []
    ) {
        self.className = className
        self.isDynamic = isDynamic
        self.isExternalizable = isExternalizable
        self.properties = properties
    }
}

// MARK: - Presets

extension AMF3Traits {
    /// Anonymous dynamic object with no sealed properties (most common case).
    public static let anonymous = AMF3Traits()

    /// Creates traits for a named sealed object with no dynamic properties.
    ///
    /// - Parameters:
    ///   - className: The fully-qualified class name.
    ///   - properties: Sealed property names in declaration order.
    /// - Returns: Sealed traits with the given class and properties.
    public static func sealed(className: String, properties: [String]) -> AMF3Traits {
        AMF3Traits(
            className: className,
            isDynamic: false,
            isExternalizable: false,
            properties: properties
        )
    }
}

/// An AMF3 Object value — a typed, optionally-sealed object with traits.
///
/// Objects carry both sealed properties (defined by traits) and optional
/// dynamic properties. The traits describe the object's class and structure.
public struct AMF3Object: Sendable, Equatable {
    /// The traits describing this object's class.
    public let traits: AMF3Traits
    /// Sealed properties (listed in traits.properties, in order).
    public let sealedProperties: [String: AMF3Value]
    /// Dynamic properties (only present when traits.isDynamic is true).
    public let dynamicProperties: [String: AMF3Value]

    /// Creates an AMF3 object.
    ///
    /// - Parameters:
    ///   - traits: The traits describing this object's class.
    ///   - sealedProperties: Values for sealed properties (default: empty).
    ///   - dynamicProperties: Dynamic properties (default: empty).
    public init(
        traits: AMF3Traits,
        sealedProperties: [String: AMF3Value] = [:],
        dynamicProperties: [String: AMF3Value] = [:]
    ) {
        self.traits = traits
        self.sealedProperties = sealedProperties
        self.dynamicProperties = dynamicProperties
    }
}
