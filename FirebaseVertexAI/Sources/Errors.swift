// Copyright 2023 Google LLC
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

struct ErrorStatus {
  let code: Int?
  let message: String?
  let status: RPCStatus?
  let details: [ErrorDetails]
}

struct ErrorDetails {
  static let errorInfoType = "type.googleapis.com/google.rpc.ErrorInfo"

  let type: String
  let reason: String?
  let domain: String?
  let metadata: [String: String]?

  func isErrorInfo() -> Bool {
    return type == ErrorDetails.errorInfoType
  }

  func isServiceDisabledError() -> Bool {
    return isErrorInfo() && reason == "SERVICE_DISABLED" && domain == "googleapis.com"
  }

  func isVertexAIInFirebaseServiceDisabledErrorDetails() -> Bool {
    guard isServiceDisabledError() else {
      return false
    }
    guard let metadata, metadata["service"] == "firebasevertexai.googleapis.com" else {
      return false
    }
    return true
  }
}

extension ErrorDetails: Decodable, Equatable {
  enum CodingKeys: String, CodingKey {
    case type = "@type"
    case reason
    case domain
    case metadata
  }
}

extension ErrorStatus: Decodable {
  enum CodingKeys: CodingKey {
    case code
    case message
    case status
    case details
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    code = try container.decodeIfPresent(Int.self, forKey: .code)
    message = try container.decodeIfPresent(String.self, forKey: .message)
    do {
      status = try container.decodeIfPresent(RPCStatus.self, forKey: .status)
    } catch {
      status = .unknown
    }
    if container.contains(.details) {
      details = try container.decode([ErrorDetails].self, forKey: .details)
    } else {
      details = []
    }
  }
}

enum RPCStatus: String, Decodable {
  // Not an error; returned on success.
  case ok = "OK"

  // The operation was cancelled, typically by the caller.
  case cancelled = "CANCELLED"

  // Unknown error.
  case unknown = "UNKNOWN"

  // The client specified an invalid argument.
  case invalidArgument = "INVALID_ARGUMENT"

  // The deadline expired before the operation could complete.
  case deadlineExceeded = "DEADLINE_EXCEEDED"

  // Some requested entity (e.g., file or directory) was not found.
  case notFound = "NOT_FOUND"

  // The entity that a client attempted to create (e.g., file or directory) already exists.
  case alreadyExists = "ALREADY_EXISTS"

  // The caller does not have permission to execute the specified operation.
  case permissionDenied = "PERMISSION_DENIED"

  // The request does not have valid authentication credentials for the operation.
  case unauthenticated = "UNAUTHENTICATED"

  // Some resource has been exhausted, perhaps a per-user quota, or perhaps the entire file system
  // is out of space.
  case resourceExhausted = "RESOURCE_EXHAUSTED"

  // The operation was rejected because the system is not in a state required for the operation's
  // execution.
  case failedPrecondition = "FAILED_PRECONDITION"

  // The operation was aborted, typically due to a concurrency issue such as a sequencer check
  // failure or transaction abort.
  case aborted = "ABORTED"

  // The operation was attempted past the valid range.
  case outOfRange = "OUT_OF_RANGE"

  // The operation is not implemented or is not supported/enabled in this service.
  case unimplemented = "UNIMPLEMENTED"

  // Internal errors.
  case internalError = "INTERNAL"

  // The service is currently unavailable.
  case unavailable = "UNAVAILABLE"

  // Unrecoverable data loss or corruption.
  case dataLoss = "DATA_LOSS"
}

enum InvalidCandidateError: Error {
  case emptyContent(underlyingError: Error)
  case malformedContent(underlyingError: Error)
}
