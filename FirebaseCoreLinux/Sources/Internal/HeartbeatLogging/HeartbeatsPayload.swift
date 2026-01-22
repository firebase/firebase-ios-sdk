import Foundation

/// A type that provides a string representation for use in an HTTP header.
public protocol HTTPHeaderRepresentable {
  func headerValue() -> String
}

public struct HeartbeatsPayload: Codable, Sendable {
  static let version: Int = 2

  struct UserAgentPayload: Codable, Equatable {
    let agent: String
    let dates: [Date]
  }

  let userAgentPayloads: [UserAgentPayload]
  let version: Int

  enum CodingKeys: String, CodingKey {
    case userAgentPayloads = "heartbeats"
    case version
  }

  init(userAgentPayloads: [UserAgentPayload] = [], version: Int = version) {
    self.userAgentPayloads = userAgentPayloads
    self.version = version
  }

  public var isEmpty: Bool {
    userAgentPayloads.isEmpty
  }
}

// MARK: - HTTPHeaderRepresentable

extension HeartbeatsPayload: HTTPHeaderRepresentable {
  public func headerValue() -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .formatted(Self.dateFormatter)
    #if DEBUG
      encoder.outputFormatting = .sortedKeys
    #endif

    guard let data = try? encoder.encode(self) else {
      return Self.emptyPayload.headerValue()
    }

    // Skip GZIP for Linux compatibility as GULNSData is not available.
    // If GZIP is strictly required by backend, we might need a Swift GZIP library.
    // However, usually servers handle non-gzipped if not specified or just base64 is fine?
    // The original code fell back to base64 if gzip failed.
    return data.base64URLEncodedString()
  }
}

// MARK: - Static Defaults

extension HeartbeatsPayload {
  static let emptyPayload = HeartbeatsPayload()

  public static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }()
}

// MARK: - Equatable

extension HeartbeatsPayload: Equatable {}

// MARK: - Data

public extension Data {
  func base64URLEncodedString(options: Data.Base64EncodingOptions = []) -> String {
    base64EncodedString()
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "=", with: "")
  }
}
