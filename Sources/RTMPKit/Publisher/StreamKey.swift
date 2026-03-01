// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Parsed RTMP stream URL components.
///
/// Parses URLs like:
/// - `rtmp://live.twitch.tv/app/streamkey123`
/// - `rtmps://a.rtmp.youtube.com/live2/xxxx-xxxx-xxxx`
/// - `rtmp://host:1935/app/instance/key`
public struct StreamKey: Sendable, Equatable {

    /// The server hostname.
    public let host: String

    /// The server port (1935 for RTMP, 443 for RTMPS by default).
    public let port: Int

    /// Whether to use TLS (rtmps:// scheme).
    public let useTLS: Bool

    /// The application name (first path segment).
    public let app: String

    /// The stream key (remaining path segments after app).
    public let key: String

    /// The full tcUrl for the connect command.
    ///
    /// Reconstructed as `scheme://host:port/app`.
    public var tcUrl: String {
        let scheme = useTLS ? "rtmps" : "rtmp"
        return "\(scheme)://\(host):\(port)/\(app)"
    }

    /// Parse from a URL string and a separate stream key.
    ///
    /// The URL is everything except the stream key
    /// (e.g., `"rtmp://live.twitch.tv/app"`).
    /// The stream key is provided separately for security.
    ///
    /// - Parameters:
    ///   - url: The RTMP server URL (scheme + host + app).
    ///   - streamKey: The stream key.
    /// - Throws: ``RTMPError/invalidURL(_:)`` on parsing failure.
    public init(url: String, streamKey: String) throws {
        guard !streamKey.isEmpty else {
            throw RTMPError.invalidURL("Stream key is empty")
        }

        let parsed = try Self.parseBaseURL(url)
        self.host = parsed.host
        self.port = parsed.port
        self.useTLS = parsed.useTLS
        self.app = parsed.pathSegments[0]
        self.key = streamKey
    }

    /// Parse from a single combined URL.
    ///
    /// Less common — most APIs provide URL and key separately.
    /// The key is extracted from the path segments after the app name.
    ///
    /// - Parameter combinedURL: Full URL including key
    ///   (e.g., `"rtmp://host/app/key"`).
    /// - Throws: ``RTMPError/invalidURL(_:)`` on parsing failure.
    public init(combinedURL: String) throws {
        let parsed = try Self.parseURL(combinedURL)

        guard parsed.pathSegments.count >= 2 else {
            throw RTMPError.invalidURL("Missing stream key in combined URL")
        }

        self.host = parsed.host
        self.port = parsed.port
        self.useTLS = parsed.useTLS
        self.app = parsed.pathSegments[0]
        self.key = parsed.pathSegments.dropFirst().joined(separator: "/")
    }

    // MARK: - Private Parsing

    /// Intermediate parse result to avoid large tuples.
    private struct ParsedURL {
        let host: String
        let port: Int
        let useTLS: Bool
        let pathSegments: [String]
    }

    private static func parseBaseURL(_ url: String) throws -> ParsedURL {
        let parsed = try parseURL(url)

        guard !parsed.pathSegments.isEmpty else {
            throw RTMPError.invalidURL("Missing application name")
        }

        return parsed
    }

    private static func parseURL(_ url: String) throws -> ParsedURL {
        let useTLS: Bool
        let afterScheme: String

        if url.hasPrefix("rtmps://") {
            useTLS = true
            afterScheme = String(url.dropFirst("rtmps://".count))
        } else if url.hasPrefix("rtmp://") {
            useTLS = false
            afterScheme = String(url.dropFirst("rtmp://".count))
        } else {
            throw RTMPError.invalidURL("Missing rtmp:// or rtmps:// scheme")
        }

        guard !afterScheme.isEmpty else {
            throw RTMPError.invalidURL("Missing host")
        }

        // Split host+port from path at first '/'
        let hostPortAndPath = afterScheme.split(
            separator: "/",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        let hostPort = String(hostPortAndPath[0])

        guard !hostPort.isEmpty else {
            throw RTMPError.invalidURL("Missing host")
        }

        // Parse path segments
        let pathString: String
        if hostPortAndPath.count > 1 {
            pathString = String(hostPortAndPath[1])
        } else {
            pathString = ""
        }

        // Remove query parameters and fragment
        let cleanPath =
            pathString.split(separator: "?").first
            .map(String.init) ?? pathString
        let pathSegments =
            cleanPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        // Parse host and optional port
        let (host, port) = try parseHostPort(hostPort, defaultPort: useTLS ? 443 : 1935)

        guard !host.isEmpty else {
            throw RTMPError.invalidURL("Missing host")
        }

        return ParsedURL(
            host: host, port: port,
            useTLS: useTLS, pathSegments: pathSegments
        )
    }

    private static func parseHostPort(
        _ hostPort: String,
        defaultPort: Int
    ) throws -> (String, Int) {
        // Handle IPv6: [::1]:port
        if hostPort.hasPrefix("[") {
            guard let closeBracket = hostPort.firstIndex(of: "]") else {
                throw RTMPError.invalidURL("Invalid IPv6 address")
            }
            let host = String(hostPort[hostPort.index(after: hostPort.startIndex)..<closeBracket])
            let afterBracket = hostPort[hostPort.index(after: closeBracket)...]
            if afterBracket.hasPrefix(":") {
                let portStr = String(afterBracket.dropFirst())
                guard let port = Int(portStr), port > 0, port <= 65535 else {
                    throw RTMPError.invalidURL("Invalid port: \(portStr)")
                }
                return (host, port)
            }
            return (host, defaultPort)
        }

        // Standard host:port
        let parts = hostPort.split(separator: ":", maxSplits: 1)
        let host = String(parts[0])
        if parts.count > 1 {
            let portStr = String(parts[1])
            guard let port = Int(portStr), port > 0, port <= 65535 else {
                throw RTMPError.invalidURL("Invalid port: \(portStr)")
            }
            return (host, port)
        }
        return (host, defaultPort)
    }
}
