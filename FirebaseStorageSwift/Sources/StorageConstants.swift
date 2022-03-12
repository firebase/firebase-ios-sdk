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

import FirebaseStorageObjC

@objc(FIRStorageTaskStatus) public enum StorageTaskStatus: Int {
  case unknown
  case resume
  case progress
  case pause
  case success
  case failure

  public typealias RawValue = Int

  public var rawValue: RawValue {
    switch self {
    case .unknown:
      return FIRIMPLStorageTaskStatus.unknown.rawValue
    case .resume:
      return FIRIMPLStorageTaskStatus.resume.rawValue
    case .progress:
      return FIRIMPLStorageTaskStatus.progress.rawValue
    case .pause:
      return FIRIMPLStorageTaskStatus.pause.rawValue
    case .success:
      return FIRIMPLStorageTaskStatus.success.rawValue
    case .failure:
      return FIRIMPLStorageTaskStatus.failure.rawValue
    }
  }
}

@objc(FIRStorageErrorCode) public enum StorageErrorCode: Int {
  case unknown
  case objectNotFound
  case bucketNotFound
  case projectNotFound
  case quotaExceeded
  case unauthenticated
  case unauthorized = -13021
  case retryLimitExceeded
  case nonMatchingChecksum
  case downloadSizeExceeded = -13032
  case cancelled
  case invalidArgument

  public typealias RawValue = Int

  public var rawValue: RawValue {
    switch self {
    case .unknown:
      return FIRIMPLStorageErrorCode.unknown.rawValue
    case .objectNotFound:
      return FIRIMPLStorageErrorCode.objectNotFound.rawValue
    case .bucketNotFound:
      return FIRIMPLStorageErrorCode.bucketNotFound.rawValue
    case .projectNotFound:
      return FIRIMPLStorageErrorCode.projectNotFound.rawValue
    case .quotaExceeded:
      return FIRIMPLStorageErrorCode.quotaExceeded.rawValue
    case .unauthenticated:
      return FIRIMPLStorageErrorCode.unauthenticated.rawValue
    case .unauthorized:
      return FIRIMPLStorageErrorCode.unauthorized.rawValue
    case .retryLimitExceeded:
      return FIRIMPLStorageErrorCode.retryLimitExceeded.rawValue
    case .nonMatchingChecksum:
      return FIRIMPLStorageErrorCode.nonMatchingChecksum.rawValue
    case .downloadSizeExceeded:
      return FIRIMPLStorageErrorCode.downloadSizeExceeded.rawValue
    case .cancelled:
      return FIRIMPLStorageErrorCode.cancelled.rawValue
    case .invalidArgument:
      return FIRIMPLStorageErrorCode.invalidArgument.rawValue
    }
  }

  public init?(rawValue: RawValue) {
    switch rawValue {
    case FIRIMPLStorageErrorCode.unknown.rawValue:
      self = .unknown
    default:
      self = .unauthorized
    }
  }
}
