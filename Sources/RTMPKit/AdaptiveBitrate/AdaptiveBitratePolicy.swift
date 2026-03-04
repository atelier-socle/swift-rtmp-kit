// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Policy controlling adaptive bitrate behavior for an RTMP publish session.
///
/// Select a built-in preset with caller-specified bitrate bounds,
/// provide a fully custom configuration, or disable adaptive bitrate entirely.
public enum AdaptiveBitratePolicy: Sendable, Equatable {

    /// No adaptive bitrate — caller controls bitrate manually.
    case disabled

    /// Built-in conservative preset with caller-specified bitrate bounds.
    case conservative(min: Int, max: Int)

    /// Built-in responsive preset with caller-specified bitrate bounds.
    case responsive(min: Int, max: Int)

    /// Built-in aggressive preset with caller-specified bitrate bounds.
    case aggressive(min: Int, max: Int)

    /// Full custom control via an explicit configuration.
    case custom(AdaptiveBitrateConfiguration)
}

extension AdaptiveBitratePolicy {

    /// Returns the resolved configuration, or `nil` when policy is ``disabled``.
    public var configuration: AdaptiveBitrateConfiguration? {
        switch self {
        case .disabled:
            return nil
        case let .conservative(min, max):
            return .conservative(min: min, max: max)
        case let .responsive(min, max):
            return .responsive(min: min, max: max)
        case let .aggressive(min, max):
            return .aggressive(min: min, max: max)
        case let .custom(config):
            return config
        }
    }
}
