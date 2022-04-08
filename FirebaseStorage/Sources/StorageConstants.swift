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

import FirebaseStorageInternal

@objc(FIRStorageTaskStatus) public enum StorageTaskStatus: Int {
  case unknown
  case resume
  case progress
  case pause
  case success
  case failure
}

@objc(FIRStorageErrorCode) public enum StorageErrorCode: Int {
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
}
