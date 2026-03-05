// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// AMF3 reference tables for strings, objects, and traits.
///
/// Used internally by ``AMF3Encoder`` and ``AMF3Decoder``.
/// Value type — each encoder/decoder instance owns its own copy.
struct AMF3ReferenceTable: Sendable {
    /// All stored strings.
    private(set) var strings: [String] = []
    /// All stored objects.
    private(set) var objects: [AMF3Value] = []
    /// All stored traits.
    private(set) var traits: [AMF3Traits] = []

    /// Returns the reference index if the string is already in the table.
    ///
    /// - Parameter string: The string to look up.
    /// - Returns: The reference index, or `nil` if not found.
    func stringReference(for string: String) -> Int? {
        strings.firstIndex(of: string)
    }

    /// Adds a string to the reference table.
    ///
    /// - Parameter string: The string to add.
    mutating func addString(_ string: String) {
        strings.append(string)
    }

    /// Returns the reference index if the object is already in the table.
    ///
    /// - Parameter value: The object value to look up.
    /// - Returns: The reference index, or `nil` if not found.
    func objectReference(for value: AMF3Value) -> Int? {
        objects.firstIndex(of: value)
    }

    /// Adds an object to the reference table.
    ///
    /// - Parameter value: The object value to add.
    mutating func addObject(_ value: AMF3Value) {
        objects.append(value)
    }

    /// Returns the reference index if the traits are already in the table.
    ///
    /// - Parameter traits: The traits to look up.
    /// - Returns: The reference index, or `nil` if not found.
    func traitsReference(for traits: AMF3Traits) -> Int? {
        self.traits.firstIndex(of: traits)
    }

    /// Adds traits to the reference table.
    ///
    /// - Parameter traits: The traits to add.
    mutating func addTraits(_ newTraits: AMF3Traits) {
        traits.append(newTraits)
    }

    /// Clears all three reference tables.
    mutating func reset() {
        strings.removeAll()
        objects.removeAll()
        traits.removeAll()
    }

    /// Replaces an object at a specific index (used for circular reference support).
    mutating func replaceObject(at index: Int, with value: AMF3Value) {
        guard index < objects.count else { return }
        objects[index] = value
    }
}
