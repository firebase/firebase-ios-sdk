// Copyright 2021 Google LLC
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

/// The error domain for codes in the `StorageErrorCode` enum.
public let StorageErrorDomain: String = "FIRStorageErrorDomain"

/**
 * Adds wrappers for common Firebase Storage errors (including creating errors from GCS errors).
 * For more information on unwrapping GCS errors, see the GCS errors docs:
 * https://cloud.google.com/storage/docs/json_api/v1/status-codes
 * This is never publicly exposed to end developers (as they will simply see an NSError).
 */
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRStorageErrorCode) public enum StorageErrorCode: Int, Swift.Error {
  case unknown = -13000
  case objectNotFound = -13010
  case bucketNotFound = -13011
  case projectNotFound = -13012
  case quotaExceeded = -13013
  case unauthenticated = -13020
  case unauthorized = -13021
  case retryLimitExceeded = -13030
  case nonMatchingChecksum = -13031
  case downloadSizeExceeded = -13032
  case cancelled = -13040
  case invalidArgument = -13050
  case bucketMismatch = -13051
  case internalError = -13052
  case pathError = -13053

  /**
   * Creates a Firebase Storage error from a specific GCS error and StorageReference.
   * @param serverError Server error to wrap and return as a Firebase Storage error.
   * @param ref StorageReference which provides context about the request being made.
   * @return Returns a Firebase Storage error.
   */
  static func error(withServerError serverError: NSError, ref: StorageReference) -> NSError {
    var errorDictionary = serverError.userInfo
    errorDictionary["ResponseErrorDomain"] = serverError.domain
    errorDictionary["ResponseErrorCode"] = serverError.code
    errorDictionary["bucket"] = ref.path.bucket
    errorDictionary[NSUnderlyingErrorKey] = serverError

    if let object = ref.path.object {
      errorDictionary["object"] = object
    }
    if let data = (errorDictionary["data"] as? Data) {
      errorDictionary["ResponseBody"] = String(data: data, encoding: .utf8)
    }
    let storageError = switch serverError.code {
    case 400: StorageError.unknown(
        message: "Unknown 400 error from backend",
        serverError: errorDictionary
      )
    case 401: StorageError.unauthenticated(serverError: errorDictionary)
    case 402: StorageError.quotaExceeded(
        bucket: ref.path.bucket,
        serverError: errorDictionary
      )
    case 403: StorageError.unauthorized(
        bucket: ref.path.bucket,
        object: ref.path.object ?? "<object-entity-internal-error>",
        serverError: errorDictionary
      )
    case 404: StorageError.objectNotFound(
        object: ref.path.object ?? "<object-entity-internal-error>", serverError: errorDictionary
      )
    default: StorageError.unknown(
        message: "Unexpected \(serverError.code) code from backend", serverError: errorDictionary
      )
    }
    return storageError as NSError
  }

  /** Creates a Firebase Storage error from an invalid request.
   *
   * @param request The Data representation of the invalid user request.
   * @return Returns the corresponding Firebase Storage error.
   */
  static func error(withInvalidRequest request: Data?) -> NSError {
    var requestString: String
    if let request {
      requestString = String(data: request, encoding: .utf8) ?? "<unstringable data>"
    } else {
      requestString = "<nil request returned from server>"
    }
    let invalidDataString = "Invalid data returned from the server: \(requestString)"
    return StorageError.unknown(message: invalidDataString, serverError: [:]) as NSError
  }
}

/// Firebase Storage errors
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public enum StorageError: Error, CustomNSError {
  case unknown(message: String, serverError: [String: Any])
  case objectNotFound(object: String, serverError: [String: Any])
  case bucketNotFound(bucket: String)
  case projectNotFound(project: String)
  case quotaExceeded(bucket: String, serverError: [String: Any])
  case unauthenticated(serverError: [String: Any])
  case unauthorized(bucket: String, object: String, serverError: [String: Any])
  case retryLimitExceeded
  case nonMatchingChecksum
  case downloadSizeExceeded(total: Int64, maxSize: Int64)
  case cancelled
  case invalidArgument(message: String)
  case internalError(message: String)
  case bucketMismatch(message: String)
  case pathError(message: String)

  // MARK: - CustomNSError

  /// Default domain of the error.
  public static var errorDomain: String { return StorageErrorDomain }

  /// The error code within the given domain.
  public var errorCode: Int {
    switch self {
    case .unknown:
      return StorageErrorCode.unknown.rawValue
    case .objectNotFound:
      return StorageErrorCode.objectNotFound.rawValue
    case .bucketNotFound:
      return StorageErrorCode.bucketNotFound.rawValue
    case .projectNotFound:
      return StorageErrorCode.projectNotFound.rawValue
    case .quotaExceeded:
      return StorageErrorCode.quotaExceeded.rawValue
    case .unauthenticated:
      return StorageErrorCode.unauthenticated.rawValue
    case .unauthorized:
      return StorageErrorCode.unauthorized.rawValue
    case .retryLimitExceeded:
      return StorageErrorCode.retryLimitExceeded.rawValue
    case .nonMatchingChecksum:
      return StorageErrorCode.nonMatchingChecksum.rawValue
    case .downloadSizeExceeded:
      return StorageErrorCode.downloadSizeExceeded.rawValue
    case .cancelled:
      return StorageErrorCode.cancelled.rawValue
    case .invalidArgument:
      return StorageErrorCode.invalidArgument.rawValue
    case .internalError:
      return StorageErrorCode.internalError.rawValue
    case .bucketMismatch:
      return StorageErrorCode.bucketMismatch.rawValue
    case .pathError:
      return StorageErrorCode.pathError.rawValue
    }
  }

  /// The default user-info dictionary.
  public var errorUserInfo: [String: Any] {
    switch self {
    case let .unknown(message, serverError):
      var dictionary = serverError
      dictionary[NSLocalizedDescriptionKey] = message
      return dictionary
    case let .objectNotFound(object, serverError):
      var dictionary = serverError
      dictionary[NSLocalizedDescriptionKey] = "Object \(object) does not exist."
      return dictionary
    case let .bucketNotFound(bucket):
      return [NSLocalizedDescriptionKey: "Bucket \(bucket) does not exist."]
    case let .projectNotFound(project):
      return [NSLocalizedDescriptionKey: "Project \(project) does not exist."]
    case let .quotaExceeded(bucket, serverError):
      var dictionary = serverError
      dictionary[NSLocalizedDescriptionKey] =
        "Quota for bucket \(bucket) exceeded, please view quota on firebase.google.com."
      return dictionary
    case let .unauthenticated(serverError):
      var dictionary = serverError
      dictionary[NSLocalizedDescriptionKey] = "User is not authenticated, please " +
        "authenticate using Firebase Authentication and try again."
      return dictionary
    case let .unauthorized(bucket, object, serverError):
      var dictionary = serverError
      dictionary[NSLocalizedDescriptionKey] =
        "User does not have permission to access gs://\(bucket)/\(object)."
      return dictionary
    case .retryLimitExceeded:
      return [NSLocalizedDescriptionKey: "Max retry time for operation exceeded, please try again."]
    case .nonMatchingChecksum:
      // TODO: replace with actual checksum strings when we choose to implement.
      return [NSLocalizedDescriptionKey: "Uploaded/downloaded object TODO has checksum: TODO " +
        "which does not match server checksum: TODO. Please retry the upload/download."]
    case let .downloadSizeExceeded(total, maxSize):
      var dictionary: [String: Any] = ["totalSize": total, "maxAllowedSize": maxSize]
      dictionary[NSLocalizedDescriptionKey] = "Attempted to download object with size of " +
        "\(total) bytes, " +
        "which exceeds the maximum size of \(maxSize) bytes. " +
        "Consider raising the maximum download maxSize, or using StorageReference.write"
      return dictionary
    case .cancelled:
      return [NSLocalizedDescriptionKey: "User cancelled the upload/download."]
    case let .invalidArgument(message):
      return [NSLocalizedDescriptionKey: message]
    case let .internalError(message):
      return [NSLocalizedDescriptionKey: message]
    case let .bucketMismatch(message):
      return [NSLocalizedDescriptionKey: message]
    case let .pathError(message):
      return [NSLocalizedDescriptionKey: message]
    }
  }
}
