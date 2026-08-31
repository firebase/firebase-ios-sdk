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

#if canImport(Darwin)
  package import Foundation
#else
  import Foundation
#endif

/// Represents a Google Cloud API error response body as defined by AIP-0193.
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
package struct GoogleCloudAPIError: Codable, Sendable, Equatable, Hashable {
  /// The HTTP status code value.
  package let code: Int

  /// A developer-facing, human-readable English error message.
  package let message: String

  /// The canonical status code indicating the nature of the error.
  package let status: RPCErrorStatus?

  /// Additional details about the error.
  package let details: [Detail]?

  /// The retry delay duration, if provided by `RetryInfo` details or HTTP headers.
  @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
  package var retryDelay: Duration? {
    if let explicitRetryDelay {
      return explicitRetryDelay
    }
    if let details {
      for detail in details {
        if case .retryInfo(let retryInfo) = detail {
          return retryInfo.duration
        }
      }
    }
    return nil
  }

  private let explicitRetryDelay: Duration?

  private enum EnvelopeCodingKeys: String, CodingKey {
    case error
  }

  private enum StatusCodingKeys: String, CodingKey {
    case code
    case message
    case status
    case details
  }

  /// Creates a new `GoogleCloudAPIError`.
  ///
  /// - Parameters:
  ///   - code: The HTTP status code value.
  ///   - message: A developer-facing, human-readable English error message.
  ///   - status: The canonical status code indicating the nature of the error.
  ///   - details: Additional details about the error.
  ///   - retryDelay: Optional retry delay duration.
  package init(
    code: Int,
    message: String,
    status: RPCErrorStatus? = nil,
    details: [Detail]? = nil,
    retryDelay: Duration? = nil
  ) {
    self.code = code
    self.message = message
    self.status = status
    self.details = details
    self.explicitRetryDelay = retryDelay
  }

  package init(from decoder: Decoder) throws {
    if let envelopeContainer = try? decoder.container(keyedBy: EnvelopeCodingKeys.self),
      envelopeContainer.contains(.error)
    {
      let statusContainer = try envelopeContainer.nestedContainer(
        keyedBy: StatusCodingKeys.self, forKey: .error)
      self.code = try statusContainer.decode(Int.self, forKey: .code)
      self.message = try statusContainer.decode(String.self, forKey: .message)
      self.status = try statusContainer.decodeIfPresent(RPCErrorStatus.self, forKey: .status)
      self.details = try statusContainer.decodeIfPresent([Detail].self, forKey: .details)
      self.explicitRetryDelay = nil
    } else {
      let container = try decoder.container(keyedBy: StatusCodingKeys.self)
      self.code = try container.decode(Int.self, forKey: .code)
      self.message = try container.decode(String.self, forKey: .message)
      self.status = try container.decodeIfPresent(RPCErrorStatus.self, forKey: .status)
      self.details = try container.decodeIfPresent([Detail].self, forKey: .details)
      self.explicitRetryDelay = nil
    }
  }

  package func encode(to encoder: Encoder) throws {
    var envelopeContainer = encoder.container(keyedBy: EnvelopeCodingKeys.self)
    var statusContainer = envelopeContainer.nestedContainer(
      keyedBy: StatusCodingKeys.self, forKey: .error)
    try statusContainer.encode(code, forKey: .code)
    try statusContainer.encode(message, forKey: .message)
    try statusContainer.encodeIfPresent(status, forKey: .status)
    try statusContainer.encodeIfPresent(details, forKey: .details)
  }

  /// Returns a copy of this error with the specified retry delay duration.
  ///
  /// - Parameter retryDelay: The retry delay duration.
  /// - Returns: A new `GoogleCloudAPIError` instance with updated retry delay.
  package func withRetryDelay(_ retryDelay: Duration?) -> GoogleCloudAPIError {
    GoogleCloudAPIError(
      code: code,
      message: message,
      status: status,
      details: details,
      retryDelay: retryDelay ?? self.explicitRetryDelay
    )
  }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension GoogleCloudAPIError {
  /// Canonical gRPC/RPC error status codes.
  package enum RPCErrorStatus: Codable, Sendable, Equatable, Hashable {
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
  package enum Detail: Codable, Sendable, Equatable, Hashable {
    /// Primary machine-readable error information.
    case errorInfo(ErrorInfo)

    /// Localized human-readable error message.
    case localizedMessage(LocalizedMessage)

    /// Troubleshooting documentation links.
    case help(Help)

    /// Retry delay advice for rate-limited requests.
    case retryInfo(RetryInfo)

    /// Unrecognized detail payload.
    case unrecognized(JSONObject)

    private enum CodingKeys: String, CodingKey {
      case typeURL = "@type"
    }

    package init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let typeURL = try container.decodeIfPresent(String.self, forKey: .typeURL)

      switch typeURL {
      case "type.googleapis.com/google.rpc.ErrorInfo":
        self = .errorInfo(try ErrorInfo(from: decoder))
      case "type.googleapis.com/google.rpc.LocalizedMessage":
        self = .localizedMessage(try LocalizedMessage(from: decoder))
      case "type.googleapis.com/google.rpc.Help":
        self = .help(try Help(from: decoder))
      case "type.googleapis.com/google.rpc.RetryInfo":
        self = .retryInfo(try RetryInfo(from: decoder))
      default:
        self = .unrecognized(try JSONObject(from: decoder))
      }
    }

    package func encode(to encoder: Encoder) throws {
      switch self {
      case .errorInfo(let value):
        try value.encode(to: encoder)
      case .localizedMessage(let value):
        try value.encode(to: encoder)
      case .help(let value):
        try value.encode(to: encoder)
      case .retryInfo(let value):
        try value.encode(to: encoder)
      case .unrecognized(let value):
        try value.encode(to: encoder)
      }
    }
  }

  /// Machine-readable context about the error.
  package struct ErrorInfo: Codable, Sendable, Equatable, Hashable {
    /// The reason of the error.
    package let reason: String

    /// The logical grouping to which the reason belongs.
    package let domain: String

    /// Additional structured metadata.
    package let metadata: [String: String]?

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
    package init(reason: String, domain: String, metadata: [String: String]? = nil) {
      self.reason = reason
      self.domain = domain
      self.metadata = metadata
    }

    package init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.reason = try container.decode(String.self, forKey: .reason)
      self.domain = try container.decode(String.self, forKey: .domain)
      self.metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
    }

    package func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode("type.googleapis.com/google.rpc.ErrorInfo", forKey: .typeURL)
      try container.encode(reason, forKey: .reason)
      try container.encode(domain, forKey: .domain)
      try container.encodeIfPresent(metadata, forKey: .metadata)
    }
  }

  /// Localized error message for client consumption.
  package struct LocalizedMessage: Codable, Sendable, Equatable, Hashable {
    /// Locale of the message (e.g. "en-US").
    package let locale: String

    /// The localized message text.
    package let message: String

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
    package init(locale: String, message: String) {
      self.locale = locale
      self.message = message
    }

    package init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.locale = try container.decode(String.self, forKey: .locale)
      self.message = try container.decode(String.self, forKey: .message)
    }

    package func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode("type.googleapis.com/google.rpc.LocalizedMessage", forKey: .typeURL)
      try container.encode(locale, forKey: .locale)
      try container.encode(message, forKey: .message)
    }
  }

  /// Supplemental troubleshooting documentation.
  package struct Help: Codable, Sendable, Equatable, Hashable {
    /// A single documentation link.
    package struct Link: Codable, Sendable, Equatable, Hashable {
      /// Description of the link.
      package let description: String

      /// Absolute URL of the documentation.
      package let url: String

      enum CodingKeys: String, CodingKey {
        case description
        case url
      }

      /// Creates a new `Link`.
      ///
      /// - Parameters:
      ///   - description: Description of the link.
      ///   - url: Absolute URL of the documentation.
      package init(description: String, url: String) {
        self.description = description
        self.url = url
      }
    }

    /// Links to troubleshooting pages.
    package let links: [Link]

    enum CodingKeys: String, CodingKey {
      case typeURL = "@type"
      case links
    }

    /// Creates a new `Help`.
    ///
    /// - Parameters:
    ///   - links: Links to troubleshooting pages.
    package init(links: [Link]) {
      self.links = links
    }

    package init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.links = try container.decode([Link].self, forKey: .links)
    }

    package func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode("type.googleapis.com/google.rpc.Help", forKey: .typeURL)
      try container.encode(links, forKey: .links)
    }
  }

  /// Information about when a client should retry a failed request.
  package struct RetryInfo: Codable, Sendable, Equatable, Hashable {
    /// The delay duration string (e.g. `"45.5s"`).
    package let retryDelay: String

    /// The delay converted to `Duration`, if parseable.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    package var duration: Duration? {
      var delayString = retryDelay.trimmingCharacters(in: .whitespaces)
      if delayString.hasSuffix("s") {
        delayString.removeLast()
      }
      guard let seconds = Double(delayString), seconds >= 0 else { return nil }
      return .seconds(seconds)
    }

    enum CodingKeys: String, CodingKey {
      case typeURL = "@type"
      case retryDelay
    }

    /// Creates a new `RetryInfo`.
    ///
    /// - Parameter retryDelay: The delay duration string (e.g. `"45.5s"`).
    package init(retryDelay: String) {
      self.retryDelay = retryDelay
    }

    package init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.retryDelay = try container.decode(String.self, forKey: .retryDelay)
    }

    package func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode("type.googleapis.com/google.rpc.RetryInfo", forKey: .typeURL)
      try container.encode(retryDelay, forKey: .retryDelay)
    }
  }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension GoogleCloudAPIError.RPCErrorStatus: RawRepresentable {
  package var rawValue: String {
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

  package init(rawValue: String) {
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

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension GoogleCloudAPIError: LocalizedError {
  package var errorDescription: String? {
    if let details {
      for detail in details {
        if case .localizedMessage(let localizedMessage) = detail {
          return localizedMessage.message
        }
      }
    }
    return message
  }

  package var failureReason: String? {
    if let details {
      for detail in details {
        if case .errorInfo(let errorInfo) = detail {
          return errorInfo.reason
        }
      }
    }
    return status?.rawValue
  }

  package var helpAnchor: String? {
    if let details {
      for detail in details {
        if case .help(let help) = detail, let firstLink = help.links.first {
          return firstLink.url
        }
      }
    }
    return nil
  }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension GoogleCloudAPIError: CustomNSError {
  package static var errorDomain: String { "GoogleCloudAPIError" }

  package var errorCode: Int { code }

  package var errorUserInfo: [String: Any] {
    var userInfo = [String: Any]()

    userInfo["code"] = code

    if let status {
      userInfo["status"] = status.rawValue
    }

    if let retryDelay {
      userInfo["retryAfterSeconds"] = Double(retryDelay.components.seconds)
    }

    if let details {
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
        case .retryInfo(let retryInfo):
          userInfo["retryDelay"] = retryInfo.retryDelay
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
