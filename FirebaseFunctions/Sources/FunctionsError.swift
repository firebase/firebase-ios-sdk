// Copyright 2022 Google LLC
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

/// The error domain for codes in the ``FunctionsErrorCode`` enum.
public let FunctionsErrorDomain: String = "com.firebase.functions"

/// The key for finding error details in the `NSError` userInfo.
public let FunctionsErrorDetailsKey: String = "details"

/**
 * The set of error status codes that can be returned from a Callable HTTPS trigger. These are the
 * canonical error codes for Google APIs, as documented here:
 * https://github.com/googleapis/googleapis/blob/master/google/rpc/code.proto#L26
 */
@objc(FIRFunctionsErrorCode) public enum FunctionsErrorCode: Int {
  /** The operation completed successfully. */
  case OK = 0

  /** The operation was cancelled (typically by the caller). */
  case cancelled = 1

  /** Unknown error or an error from a different error domain. */
  case unknown = 2

  /**
   * Client specified an invalid argument. Note that this differs from `FailedPrecondition`.
   * `InvalidArgument` indicates arguments that are problematic regardless of the state of the
   * system (e.g., an invalid field name).
   */
  case invalidArgument = 3

  /**
   * Deadline expired before operation could complete. For operations that change the state of the
   * system, this error may be returned even if the operation has completed successfully. For
   * example, a successful response from a server could have been delayed long enough for the
   * deadline to expire.
   */
  case deadlineExceeded = 4

  /** Some requested document was not found. */
  case notFound = 5

  /** Some document that we attempted to create already exists. */
  case alreadyExists = 6

  /** The caller does not have permission to execute the specified operation. */
  case permissionDenied = 7

  /**
   * Some resource has been exhausted, perhaps a per-user quota, or perhaps the entire file system
   * is out of space.
   */
  case resourceExhausted = 8

  /**
   * Operation was rejected because the system is not in a state required for the operation's
   * execution.
   */
  case failedPrecondition = 9

  /**
   * The operation was aborted, typically due to a concurrency issue like transaction aborts, etc.
   */
  case aborted = 10

  /** Operation was attempted past the valid range. */
  case outOfRange = 11

  /** Operation is not implemented or not supported/enabled. */
  case unimplemented = 12

  /**
   * Internal errors. Means some invariant expected by underlying system has been broken. If you
   * see one of these errors, something is very broken.
   */
  case `internal` = 13

  /**
   * The service is currently unavailable. This is a most likely a transient condition and may be
   * corrected by retrying with a backoff.
   */
  case unavailable = 14

  /** Unrecoverable data loss or corruption. */
  case dataLoss = 15

  /** The request does not have valid authentication credentials for the operation. */
  case unauthenticated = 16
}

private extension FunctionsErrorCode {
  /// Takes an HTTP status code and returns the corresponding `FIRFunctionsErrorCode` error code.
  ///
  /// + This is the standard HTTP status code -> error mapping defined in:
  /// https://github.com/googleapis/googleapis/blob/master/google/rpc/code.proto
  ///
  /// - Parameter httpStatusCode: An HTTP status code.
  /// - Returns: A `FunctionsErrorCode`. Falls back to `internal` for unknown status codes.
  init(httpStatusCode: Int) {
    self = switch httpStatusCode {
    case 200: .OK
    case 400: .invalidArgument
    case 401: .unauthenticated
    case 403: .permissionDenied
    case 404: .notFound
    case 409: .alreadyExists
    case 429: .resourceExhausted
    case 499: .cancelled
    case 500: .internal
    case 501: .unimplemented
    case 503: .unavailable
    case 504: .deadlineExceeded
    default: .internal
    }
  }

  init(errorName: String) {
    self = switch errorName {
    case "OK": .OK
    case "CANCELLED": .cancelled
    case "UNKNOWN": .unknown
    case "INVALID_ARGUMENT": .invalidArgument
    case "DEADLINE_EXCEEDED": .deadlineExceeded
    case "NOT_FOUND": .notFound
    case "ALREADY_EXISTS": .alreadyExists
    case "PERMISSION_DENIED": .permissionDenied
    case "RESOURCE_EXHAUSTED": .resourceExhausted
    case "FAILED_PRECONDITION": .failedPrecondition
    case "ABORTED": .aborted
    case "OUT_OF_RANGE": .outOfRange
    case "UNIMPLEMENTED": .unimplemented
    case "INTERNAL": .internal
    case "UNAVAILABLE": .unavailable
    case "DATA_LOSS": .dataLoss
    case "UNAUTHENTICATED": .unauthenticated
    default: .internal
    }
  }
}

/// The object used to report errors that occur during a function’s execution.
struct FunctionsError: CustomNSError {
  static let errorDomain = FunctionsErrorDomain

  let code: FunctionsErrorCode
  let errorUserInfo: [String: Any]
  var errorCode: FunctionsErrorCode.RawValue { code.rawValue }

  init(_ code: FunctionsErrorCode, userInfo: [String: Any]? = nil) {
    self.code = code
    errorUserInfo = userInfo ?? [NSLocalizedDescriptionKey: Self.errorDescription(from: code)]
  }

  /// Initializes a `FunctionsError` from the HTTP status code and response body.
  ///
  /// - Parameters:
  ///   - httpStatusCode: The HTTP status code reported during a function’s execution. Only a subset
  /// of codes are supported.
  ///   - body: The optional response data which may contain information about the error. The
  /// following schema is expected:
  ///     ```
  ///     {
  ///         "error": {
  ///             "status": "PERMISSION_DENIED",
  ///             "message": "You are not allowed to perform this operation",
  ///             "details": 123 // Any value supported by `FunctionsSerializer`
  ///     }
  ///     ```
  ///   - serializer: The `FunctionsSerializer` used to decode `details` in the error body.
  init?(httpStatusCode: Int, body: Data?, serializer: FunctionsSerializer) {
    // Start with reasonable defaults from the status code.
    var code = FunctionsErrorCode(httpStatusCode: httpStatusCode)
    var description = Self.errorDescription(from: code)
    var details: Any?

    // Then look through the body for explicit details.
    if let body,
       let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
       let errorDetails = json["error"] as? [String: Any] {
      if let status = errorDetails["status"] as? String {
        code = FunctionsErrorCode(errorName: status)

        // If the code in the body is invalid, treat the whole response as malformed.
        guard code != .internal else {
          self.init(code)
          return
        }
      }

      if let message = errorDetails["message"] as? String {
        description = message
      } else {
        description = Self.errorDescription(from: code)
      }

      details = errorDetails["details"] as Any?
      // Update `details` only if decoding succeeds;
      // otherwise, keep the original object.
      if let innerDetails = details,
         let decodedDetails = try? serializer.decode(innerDetails) {
        details = decodedDetails
      }
    }

    if code == .OK {
      // Technically, there's an edge case where a developer could explicitly return an error code
      // of
      // OK, and we will treat it as success, but that seems reasonable.
      return nil
    }

    var userInfo = [String: Any]()
    userInfo[NSLocalizedDescriptionKey] = description
    if let details {
      userInfo[FunctionsErrorDetailsKey] = details
    }
    self.init(code, userInfo: userInfo)
  }

  private static func errorDescription(from code: FunctionsErrorCode) -> String {
    switch code {
    case .OK: "OK"
    case .cancelled: "CANCELLED"
    case .unknown: "UNKNOWN"
    case .invalidArgument: "INVALID ARGUMENT"
    case .deadlineExceeded: "DEADLINE EXCEEDED"
    case .notFound: "NOT FOUND"
    case .alreadyExists: "ALREADY EXISTS"
    case .permissionDenied: "PERMISSION DENIED"
    case .resourceExhausted: "RESOURCE EXHAUSTED"
    case .failedPrecondition: "FAILED PRECONDITION"
    case .aborted: "ABORTED"
    case .outOfRange: "OUT OF RANGE"
    case .unimplemented: "UNIMPLEMENTED"
    case .internal: "INTERNAL"
    case .unavailable: "UNAVAILABLE"
    case .dataLoss: "DATA LOSS"
    case .unauthenticated: "UNAUTHENTICATED"
    }
  }
}
