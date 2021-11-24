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

import FirebaseStorage

public enum StorageError: Error {
  case unknown
  case objectNotFound
  case bucketNotFound
  case projectNotFound
  case quotaExceeded
  case unauthenticated
  case unauthorized
  case retryLimitExceeded
  case nonMatchingChecksum
  case downloadSizeExceeded
  case cancelled
  case invalidArgument
  case internalError

  static func swiftConvert(objcError: Int) -> StorageError {
    switch objcError {
    case StorageErrorCode.unknown.rawValue: return StorageError.unknown
    case StorageErrorCode.objectNotFound.rawValue: return StorageError.objectNotFound
    case StorageErrorCode.bucketNotFound.rawValue: return StorageError.bucketNotFound
    case StorageErrorCode.projectNotFound.rawValue: return StorageError.projectNotFound
    case StorageErrorCode.quotaExceeded.rawValue: return StorageError.quotaExceeded
    case StorageErrorCode.unauthenticated.rawValue: return StorageError.unauthenticated
    case StorageErrorCode.unauthorized.rawValue: return StorageError.unauthorized
    case StorageErrorCode.retryLimitExceeded.rawValue: return StorageError.retryLimitExceeded
    case StorageErrorCode.nonMatchingChecksum.rawValue: return StorageError.nonMatchingChecksum
    case StorageErrorCode.downloadSizeExceeded.rawValue: return StorageError.downloadSizeExceeded
    case StorageErrorCode.cancelled.rawValue: return StorageError.cancelled
    case StorageErrorCode.invalidArgument.rawValue: return StorageError.invalidArgument
    default: return StorageError.internalError
    }
  }
}
