// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Closed caption data for live streaming, sent as `onCaptionInfo`.
public struct CaptionData: Sendable, Equatable {

    /// Caption standard.
    public enum CaptionStandard: String, Sendable, Equatable, CaseIterable {
        /// CEA-608 (Line 21 captions — legacy analog standard).
        case cea608 = "CEA-608"
        /// CEA-708 (Digital television captions — modern standard).
        case cea708 = "CEA-708"
        /// Plain text subtitle (WebVTT-style, for simple use cases).
        case text = "TEXT"
    }

    /// The caption standard used.
    public let standard: CaptionStandard

    /// The caption text content.
    public let text: String

    /// Language code (BCP 47). e.g. "en", "fr", "ja".
    public let language: String

    /// Stream timestamp in milliseconds when this caption should be displayed.
    public let timestamp: Double

    /// Creates caption data.
    ///
    /// - Parameters:
    ///   - standard: Caption standard (default: `.cea708`).
    ///   - text: The caption text content.
    ///   - language: Language code (default: `"en"`).
    ///   - timestamp: Stream timestamp in milliseconds.
    public init(
        standard: CaptionStandard = .cea708,
        text: String,
        language: String = "en",
        timestamp: Double
    ) {
        self.standard = standard
        self.text = text
        self.language = language
        self.timestamp = timestamp
    }

    /// Encodes this caption as an AMF0 Object for wire transmission.
    ///
    /// - Returns: An AMF0 object containing standard, text, language, and timestamp.
    public func toAMF0Object() -> AMF0Value {
        .object([
            ("standard", .string(standard.rawValue)),
            ("text", .string(text)),
            ("language", .string(language)),
            ("timestamp", .number(timestamp))
        ])
    }
}
