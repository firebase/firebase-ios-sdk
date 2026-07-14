// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

public import Foundation

/// Represents a Google Cloud API error response body as defined by AIP-0193.
public struct APIError: Codable, Sendable, Equatable, Hashable {
    /// The container for the error details.
    public let error: Status

    enum CodingKeys: String, CodingKey {
        case error
    }

    /// Creates a new `GeminiAPIError`.
    ///
    /// - Parameters:
    ///   - error: The container for the error details.
    public init(error: Status) {
        self.error = error
    }
}


extension APIError {
  /// Represents the status payload within a Google Cloud API error.
  public struct Status: Codable, Sendable, Equatable, Hashable {
    /// The HTTP status code value.
    public let code: Int

    /// A developer-facing, human-readable English error message.
    public let message: String

    /// The canonical status code indicating the nature of the error.
    public let status: RPCErrorStatus?

    /// Additional details about the error.
    public let details: [Detail]?

    enum CodingKeys: String, CodingKey {
      case code
      case message
      case status
      case details
    }

    /// Creates a new `Status`.
    ///
    /// - Parameters:
    ///   - code: The HTTP status code value.
    ///   - message: A developer-facing, human-readable English error message.
    ///   - status: The canonical status code indicating the nature of the error.
    ///   - details: Additional details about the error.
    public init(
      code: Int,
      message: String,
      status: RPCErrorStatus? = nil,
      details: [Detail]? = nil
    ) {
      self.code = code
      self.message = message
      self.status = status
      self.details = details
    }
  }

  /// Canonical gRPC/RPC error status codes.
  public enum RPCErrorStatus: Codable, Sendable, Equatable, Hashable {
    /// Client cancelled the request.
    case cancelled

    /// Unknown error.
    case unknown

    /// Client specified an invalid argument.
    case invalidArgument

    /// Deadline expired before operation could complete.
    case deadlineExceeded

    /// Some requested entity was not found.
    case notFound

    /// Some entity that we attempted to create already exists.
    case alreadyExists

    /// The caller does not have permission to execute the specified action.
    case permissionDenied

    /// Some resource has been exhausted.
    case resourceExhausted

    /// Operation was rejected because the system is not in a state required for its execution.
    case failedPrecondition

    /// The operation was aborted.
    case aborted

    /// Operation was attempted past the valid range.
    case outOfRange

    /// Operation is not implemented or not supported/enabled in this service.
    case unimplemented

    /// Internal errors.
    case internalError

    /// The service is currently unavailable.
    case unavailable

    /// Unrecoverable data loss or corruption.
    case dataLoss

    /// The request does not have valid authentication credentials for the operation.
    case unauthenticated

    /// Unrecognized placeholder for future compatibility.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }

  /// Details attached to a Google Cloud API error.
  public enum Detail: Codable, Sendable, Equatable, Hashable {
    /// Primary machine-readable error information.
    case errorInfo(ErrorInfo)

    /// Localized human-readable error message.
    case localizedMessage(LocalizedMessage)

    /// Troubleshooting documentation links.
    case help(Help)

    /// Unrecognized detail payload.
    case unrecognized(JSONObject)

    private enum CodingKeys: String, CodingKey {
      case typeURL = "@type"
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let typeURL = try container.decodeIfPresent(String.self, forKey: .typeURL)

      switch typeURL {
      case "type.googleapis.com/google.rpc.ErrorInfo":
        self = .errorInfo(try ErrorInfo(from: decoder))
      case "type.googleapis.com/google.rpc.LocalizedMessage":
        self = .localizedMessage(try LocalizedMessage(from: decoder))
      case "type.googleapis.com/google.rpc.Help":
        self = .help(try Help(from: decoder))
      default:
        self = .unrecognized(try JSONObject(from: decoder))
      }
    }

    public func encode(to encoder: Encoder) throws {
      switch self {
      case .errorInfo(let value):
        try value.encode(to: encoder)
      case .localizedMessage(let value):
        try value.encode(to: encoder)
      case .help(let value):
        try value.encode(to: encoder)
      case .unrecognized(let value):
        try value.encode(to: encoder)
      }
    }
  }

  /// Machine-readable context about the error.
  public struct ErrorInfo: Codable, Sendable, Equatable, Hashable {
    /// The reason of the error.
    public let reason: String

    /// The logical grouping to which the reason belongs.
    public let domain: String

    /// Additional structured metadata.
    public let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
      case typeURL = "@type"
      case reason
      case domain
      case metadata
    }

    /// Creates a new `ErrorInfo`.
    ///
    /// - Parameters:
    ///   - reason: The reason of the error.
    ///   - domain: The logical grouping to which the reason belongs.
    ///   - metadata: Additional structured metadata.
    public init(reason: String, domain: String, metadata: [String: String]? = nil) {
      self.reason = reason
      self.domain = domain
      self.metadata = metadata
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.reason = try container.decode(String.self, forKey: .reason)
      self.domain = try container.decode(String.self, forKey: .domain)
      self.metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode("type.googleapis.com/google.rpc.ErrorInfo", forKey: .typeURL)
      try container.encode(reason, forKey: .reason)
      try container.encode(domain, forKey: .domain)
      try container.encodeIfPresent(metadata, forKey: .metadata)
    }
  }

  /// Localized error message for client consumption.
  public struct LocalizedMessage: Codable, Sendable, Equatable, Hashable {
    /// Locale of the message (e.g. "en-US").
    public let locale: String

    /// The localized message text.
    public let message: String

    enum CodingKeys: String, CodingKey {
      case typeURL = "@type"
      case locale
      case message
    }

    /// Creates a new `LocalizedMessage`.
    ///
    /// - Parameters:
    ///   - locale: Locale of the message (e.g. "en-US").
    ///   - message: The localized message text.
    public init(locale: String, message: String) {
      self.locale = locale
      self.message = message
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.locale = try container.decode(String.self, forKey: .locale)
      self.message = try container.decode(String.self, forKey: .message)
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode("type.googleapis.com/google.rpc.LocalizedMessage", forKey: .typeURL)
      try container.encode(locale, forKey: .locale)
      try container.encode(message, forKey: .message)
    }
  }

  /// Supplemental troubleshooting documentation.
  public struct Help: Codable, Sendable, Equatable, Hashable {
    /// A single documentation link.
    public struct Link: Codable, Sendable, Equatable, Hashable {
      /// Description of the link.
      public let description: String

      /// Absolute URL of the documentation.
      public let url: String

      enum CodingKeys: String, CodingKey {
        case description
        case url
      }

      /// Creates a new `Link`.
      ///
      /// - Parameters:
      ///   - description: Description of the link.
      ///   - url: Absolute URL of the documentation.
      public init(description: String, url: String) {
        self.description = description
        self.url = url
      }
    }

    /// Links to troubleshooting pages.
    public let links: [Link]

    enum CodingKeys: String, CodingKey {
      case typeURL = "@type"
      case links
    }

    /// Creates a new `Help`.
    ///
    /// - Parameters:
    ///   - links: Links to troubleshooting pages.
    public init(links: [Link]) {
      self.links = links
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.links = try container.decode([Link].self, forKey: .links)
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode("type.googleapis.com/google.rpc.Help", forKey: .typeURL)
      try container.encode(links, forKey: .links)
    }
  }
}

extension APIError.RPCErrorStatus: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .cancelled: "CANCELLED"
    case .unknown: "UNKNOWN"
    case .invalidArgument: "INVALID_ARGUMENT"
    case .deadlineExceeded: "DEADLINE_EXCEEDED"
    case .notFound: "NOT_FOUND"
    case .alreadyExists: "ALREADY_EXISTS"
    case .permissionDenied: "PERMISSION_DENIED"
    case .resourceExhausted: "RESOURCE_EXHAUSTED"
    case .failedPrecondition: "FAILED_PRECONDITION"
    case .aborted: "ABORTED"
    case .outOfRange: "OUT_OF_RANGE"
    case .unimplemented: "UNIMPLEMENTED"
    case .internalError: "INTERNAL"
    case .unavailable: "UNAVAILABLE"
    case .dataLoss: "DATA_LOSS"
    case .unauthenticated: "UNAUTHENTICATED"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "CANCELLED": self = .cancelled
    case "UNKNOWN": self = .unknown
    case "INVALID_ARGUMENT": self = .invalidArgument
    case "DEADLINE_EXCEEDED": self = .deadlineExceeded
    case "NOT_FOUND": self = .notFound
    case "ALREADY_EXISTS": self = .alreadyExists
    case "PERMISSION_DENIED": self = .permissionDenied
    case "RESOURCE_EXHAUSTED": self = .resourceExhausted
    case "FAILED_PRECONDITION": self = .failedPrecondition
    case "ABORTED": self = .aborted
    case "OUT_OF_RANGE": self = .outOfRange
    case "UNIMPLEMENTED": self = .unimplemented
    case "INTERNAL": self = .internalError
    case "UNAVAILABLE": self = .unavailable
    case "DATA_LOSS": self = .dataLoss
    case "UNAUTHENTICATED": self = .unauthenticated
    default: self = .unrecognized(rawValue)
    }
  }
}

extension APIError: LocalizedError {
  public var errorDescription: String? {
    if let details = error.details {
      for detail in details {
        if case .localizedMessage(let localizedMessage) = detail {
          return localizedMessage.message
        }
      }
    }
    return error.message
  }

  public var failureReason: String? {
    if let details = error.details {
      for detail in details {
        if case .errorInfo(let errorInfo) = detail {
          return errorInfo.reason
        }
      }
    }
    return error.status?.rawValue
  }

  public var helpAnchor: String? {
    if let details = error.details {
      for detail in details {
        if case .help(let help) = detail, let firstLink = help.links.first {
          return firstLink.url
        }
      }
    }
    return nil
  }
}

extension APIError: CustomNSError {
  public static var errorDomain: String { "APIError" }

  public var errorCode: Int { error.code }

  public var errorUserInfo: [String: Any] {
    var userInfo = [String: Any]()

    userInfo["code"] = error.code

    if let status = error.status {
      userInfo["status"] = status.rawValue
    }

    if let details = error.details {
      for detail in details {
        switch detail {
        case .errorInfo(let errorInfo):
          userInfo["domain"] = errorInfo.domain
          userInfo["reason"] = errorInfo.reason
          if let metadata = errorInfo.metadata {
            userInfo["metadata"] = metadata
          }
        case .help(let help):
          let links = help.links.map { ["description": $0.description, "url": $0.url] }
          userInfo["helpLinks"] = links
        case .localizedMessage(let localizedMessage):
          userInfo["locale"] = localizedMessage.locale
        case .unrecognized(let obj):
          if var prevAdditional = userInfo["additionalDetails"] as? [JSONObject] {
            prevAdditional.append(obj)
            userInfo["additionalDetails"] = prevAdditional
          } else {
            userInfo["additionalDetails"] = [obj]
          }
        }
      }
    }

    return userInfo
  }
}
