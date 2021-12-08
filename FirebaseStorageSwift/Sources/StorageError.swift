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
@_exported import FirebaseStorageObjC

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
    case StorageErrorCode.unknown.rawValue: return StorageError.unknown
    case StorageErrorCode.objectNotFound.rawValue:
      guard let object = userInfo["object"] as? String else {
        return StorageError
          .internalError(
            "Failed to decode object not found error: \(objcError.localizedDescription)"
          )
      }
      return StorageError.objectNotFound(object)
    case StorageErrorCode.bucketNotFound.rawValue:
      guard let bucket = userInfo["bucket"] as? String else {
        return StorageError
          .internalError(
            "Failed to decode bucket not found error: \(objcError.localizedDescription)"
          )
      }
      return StorageError.bucketNotFound(bucket)
    case StorageErrorCode.projectNotFound.rawValue:
      guard let project = userInfo["project"] as? String else {
        return StorageError
          .internalError(
            "Failed to decode project not found error: \(objcError.localizedDescription)"
          )
      }
      return StorageError.projectNotFound(project)
    case StorageErrorCode.quotaExceeded.rawValue:
      guard let bucket = userInfo["bucket"] as? String else {
        return StorageError
          .internalError("Failed to decode quota exceeded error: \(objcError.localizedDescription)")
      }
      return StorageError.quotaExceeded(bucket)
    case StorageErrorCode.unauthenticated.rawValue: return StorageError.unauthenticated
    case StorageErrorCode.unauthorized.rawValue:
      guard let bucket = userInfo["bucket"] as? String,
        let object = userInfo["object"] as? String else {
        return StorageError
          .internalError(
            "Failed to decode unauthorized error: \(objcError.localizedDescription)"
          )
      }
      return StorageError.unauthorized(bucket, object)
    case StorageErrorCode.retryLimitExceeded.rawValue: return StorageError.retryLimitExceeded
    case StorageErrorCode.nonMatchingChecksum.rawValue: return StorageError.nonMatchingChecksum
    case StorageErrorCode.downloadSizeExceeded.rawValue:
      guard let total = userInfo["totalSize"] as? Int64,
        let maxSize = userInfo["maxAllowedSize"] as? Int64 else {
        return StorageError
          .internalError(
            "Failed to decode downloadSizeExceeded error: \(objcError.localizedDescription)"
          )
      }
      return StorageError.downloadSizeExceeded(total, maxSize)
    case StorageErrorCode.cancelled.rawValue: return StorageError.cancelled
    case StorageErrorCode.invalidArgument.rawValue: return StorageError
      .invalidArgument(objcError.localizedDescription)
    default: return StorageError.internalError("Internal error converting ObjC Error to Swift")
    }
  }
}
