// Copyright 2025 Google LLC
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

import Foundation
#if os(Linux)
import FoundationNetworking
#endif

/// Wrapper around an RPC error from the backend.
public struct BackendError: Error, Sendable {
  let httpResponseCode: Int
  let message: String
  let status: String?
  let details: [[String: JSONValue]]

  init(httpResponseCode: Int, error: RPCError) {
    self.httpResponseCode = httpResponseCode
    self.message = error.error.message ?? "Unknown error"
    self.status = error.error.status
    self.details = error.error.details ?? []
  }

  func isVertexAIInFirebaseServiceDisabledError() -> Bool {
    for detail in details {
      guard
        case let .string(reason) = detail["reason"],
        case let .string(domain) = detail["domain"],
        case let .string(type) = detail["@type"],
        case let .object(metadata) = detail["metadata"]
      else {
        continue
      }

      guard
        type == "type.googleapis.com/google.rpc.ErrorInfo",
        reason == "SERVICE_DISABLED",
        domain == "googleapis.com"
      else {
        continue
      }

      guard
        case let .string(service) = metadata["service"],
        service == "firebasevertexai.googleapis.com"
      else {
        continue
      }

      return true
    }

    return false
  }
}

extension BackendError: CustomNSError {
  public static var errorDomain: String {
    "\(Constants.baseErrorDomain).\(Self.self)"
  }

  public var errorCode: Int {
    httpResponseCode
  }

  public var errorUserInfo: [String : Any] {
    [NSLocalizedDescriptionKey: "\(message) (\(Self.errorDomain) - HTTP \(httpResponseCode) \(status ?? "")"]
  }
}


/// RPC error from any of the backends.
public struct RPCError: Sendable, Decodable {
  public struct Error: Sendable, Decodable {
    public let code: Int32?
    public let status: String?
    public let details: [[String: JSONValue]]?
    public let message: String?
  }

  let error: Error
}

public struct UnrecognizedBackendError: Error, Sendable, CustomNSError {
  let underlyingError: Error
  let httpStatusCode: Int

  init(underlyingError: Error, httpStatusCode: Int) {
    self.underlyingError = underlyingError
    self.httpStatusCode = httpStatusCode
  }

  public var errorUserInfo: [String: Any] {
    [
      NSLocalizedDescriptionKey: "(HTTP \(httpStatusCode)) Unrecognized backend error. Cause: \(underlyingError.localizedDescription)",
    ]
  }
}

public struct MissingRequiredFieldError: Error, Sendable, CustomNSError {
  let backend: Backend
  let type: String
  let field: String

  init(backend: Backend, type: String, field: String) {
    self.backend = backend
    self.type = type
    self.field = field
  }

  public var errorUserInfo: [String: Any] {
    [
      NSLocalizedDescriptionKey: "Missing required field '\(field)' for type '\(type)' with the '\(backend)' backend",
    ]
  }
}

extension KeyedEncodingContainer {
  mutating func encodeOrThrow<T>(
    _ value: T?,
    forKey key: Key,
    error: @autoclosure () -> Error
  ) throws where T: Encodable {
    guard let value else {
      throw error()
    }
    try encode(value, forKey: key)
  }
}
