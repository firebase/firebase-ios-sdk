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
import FirebaseStorageInternal

/// The error domain for codes in the `StorageErrorCode` enum.
public let StorageErrorDomain: String = "FIRStorageErrorDomain"

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

  static func error(withServerError serverError: NSError, ref: FIRIMPLStorageReference) -> NSError {
    var errorCode: StorageErrorCode
    switch serverError.code {
    case 400: errorCode = .unknown
    case 401: errorCode = .unauthenticated
    case 402: errorCode = .quotaExceeded
    case 403: errorCode = .unauthorized
    case 404: errorCode = .objectNotFound
    default: errorCode = .unknown
    }

    var errorDictionary = serverError.userInfo
    errorDictionary["ResponseErrorDomain"] = serverError.domain
    errorDictionary["ResponseErrorCode"] = serverError.code
    errorDictionary["bucket"] = ref.path.bucket

    if let object = ref.path.object {
      errorDictionary["object"] = object
    }
    if let data = (errorDictionary["data"] as? Data) {
      errorDictionary["ResponseBody"] = String(data: data, encoding: .utf8)
    }
    return error(withCode: errorCode, infoDictionary: errorDictionary)
  }

  static func error(withInvalidRequest request: Data?) -> NSError {
    var requestString: String
    if let request = request {
      requestString = String(data: request, encoding: .utf8) ?? "<unstringable data>"
    } else {
      requestString = "<nil request returned from server>"
    }
    let invalidDataString = "Invalid data returned from the server:\(requestString)"
    var localizedFailureKey: String
    if #available(OSX 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *) {
      localizedFailureKey = NSLocalizedFailureErrorKey
    } else {
      localizedFailureKey = "NSLocalizedFailure"
    }
    return error(withCode: .unknown, infoDictionary: [localizedFailureKey: invalidDataString])
  }

  static func error(withCode code: StorageErrorCode,
                    infoDictionary: [String: Any]? = nil) -> NSError {
    var dictionary = infoDictionary ?? [:]
    var errorMessage: String
    switch code {
    case .objectNotFound:
      let object = dictionary["object"] ?? "<object-entity-internal-error>"
      errorMessage = "Object \(object) does not exist."
    case .bucketNotFound:
      let bucket = dictionary["bucket"] ?? "<bucket-entity-internal-error>"
      errorMessage = "Bucket \(bucket) does not exist."
    case .projectNotFound:
      let project = dictionary["project"] ?? "<project-entity-internal-error>"
      errorMessage = "Project \(project) does not exist."
    case .quotaExceeded:
      let bucket = dictionary["bucket"] ?? "<bucket-entity-internal-error>"
      errorMessage =
        "Quota for bucket \(bucket) exceeded, please view quota on firebase.google.com."
    case .downloadSizeExceeded:
      let total = "\(dictionary["totalSize"] ?? "unknown")"
      let size = "\(dictionary["maxAllowedSize"] ?? "unknown")"
      errorMessage = "Attempted to download object with size of \(total) bytes, " +
        "which exceeds the maximum size of \(size) bytes. " +
        "Consider raising the maximum download size, or using StorageReference.write"
    case .unauthenticated:
      errorMessage = "User is not authenticated, please authenticate using Firebase " +
        "Authentication and try again."
    case .unauthorized:
      let bucket = dictionary["bucket"] ?? "<bucket-entity-internal-error>"
      let object = dictionary["object"] ?? "<object-entity-internal-error>"
      errorMessage = "User does not have permission to access gs://\(bucket)/\(object)."
    case .retryLimitExceeded:
      errorMessage = "Max retry time for operation exceeded, please try again."
    case .nonMatchingChecksum:
      // TODO: replace with actual checksum strings when we choose to implement.
      errorMessage = "Uploaded/downloaded object TODO has checksum: TODO " +
        "which does not match server checksum: TODO. Please retry the upload/download."
    case .cancelled:
      errorMessage = "User cancelled the upload/download."
    case .unknown, .invalidArgument: // invalidArgument fell through in the old Objective-C code.
      errorMessage = "An unknown error occurred, please check the server response."
    }
    dictionary[NSLocalizedDescriptionKey] = errorMessage
    return NSError(domain: StorageErrorDomain, code: code.rawValue, userInfo: dictionary)
  }
}

public enum StorageError: Error {
  case unknown
  case objectNotFound(String)
  case bucketNotFound(String)
  case projectNotFound(String)
  case quotaExceeded(String)
  case unauthenticated
  case unauthorized(String, String)
  case retryLimitExceeded
  case nonMatchingChecksum
  case downloadSizeExceeded(Int64, Int64)
  case cancelled
  case invalidArgument(String)
  case internalError(String)

  static func swiftConvert(objcError: NSError) -> StorageError {
    let userInfo = objcError.userInfo

    switch objcError.code {
    case FIRIMPLStorageErrorCode.unknown.rawValue: return StorageError.unknown
    case FIRIMPLStorageErrorCode.objectNotFound.rawValue:
      guard let object = userInfo["object"] as? String else {
        return StorageError
          .internalError(
            "Failed to decode object not found error: \(objcError.localizedDescription)"
          )
      }
      return StorageError.objectNotFound(object)
    case FIRIMPLStorageErrorCode.bucketNotFound.rawValue:
      guard let bucket = userInfo["bucket"] as? String else {
        return StorageError
          .internalError(
            "Failed to decode bucket not found error: \(objcError.localizedDescription)"
          )
      }
      return StorageError.bucketNotFound(bucket)
    case FIRIMPLStorageErrorCode.projectNotFound.rawValue:
      guard let project = userInfo["project"] as? String else {
        return StorageError
          .internalError(
            "Failed to decode project not found error: \(objcError.localizedDescription)"
          )
      }
      return StorageError.projectNotFound(project)
    case FIRIMPLStorageErrorCode.quotaExceeded.rawValue:
      guard let bucket = userInfo["bucket"] as? String else {
        return StorageError
          .internalError("Failed to decode quota exceeded error: \(objcError.localizedDescription)")
      }
      return StorageError.quotaExceeded(bucket)
    case FIRIMPLStorageErrorCode.unauthenticated.rawValue: return StorageError.unauthenticated
    case FIRIMPLStorageErrorCode.unauthorized.rawValue:
      guard let bucket = userInfo["bucket"] as? String,
            let object = userInfo["object"] as? String else {
        return StorageError
          .internalError(
            "Failed to decode unauthorized error: \(objcError.localizedDescription)"
          )
      }
      return StorageError.unauthorized(bucket, object)
    case FIRIMPLStorageErrorCode.retryLimitExceeded.rawValue: return StorageError.retryLimitExceeded
    case FIRIMPLStorageErrorCode.nonMatchingChecksum.rawValue: return StorageError
      .nonMatchingChecksum
    case FIRIMPLStorageErrorCode.downloadSizeExceeded.rawValue:
      guard let total = userInfo["totalSize"] as? Int64,
            let maxSize = userInfo["maxAllowedSize"] as? Int64 else {
        return StorageError
          .internalError(
            "Failed to decode downloadSizeExceeded error: \(objcError.localizedDescription)"
          )
      }
      return StorageError.downloadSizeExceeded(total, maxSize)
    case FIRIMPLStorageErrorCode.cancelled.rawValue: return StorageError.cancelled
    case FIRIMPLStorageErrorCode.invalidArgument.rawValue: return StorageError
      .invalidArgument(objcError.localizedDescription)
    default: return StorageError.internalError("Internal error converting ObjC Error to Swift")
    }
  }
}
