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

@_implementationOnly import FirebaseCoreExtension

/// Enum of log messages.
enum LoggerMessageCode: Int {
  case downloaderInstanceCreated = 1
  case downloaderInstanceRetrieved
  case downloaderInstanceDeleted
  case modelDownloaded
  case modelDownloadError
  case retryDownload
  case backgroundModelDownloaded
  case backgroundDownloadError
  case disableBackupError
  case downloadedModelFileSaved
  case downloadedModelSaveError
  case anotherDownloadInProgressError
  case invalidDownloadSessionError
  case mergeRequests
  case localModelFound
  case allLocalModelsFound
  case listModelsError
  case modelNameParseError
  case noLocalModelInfo
  case noLocalModelFile
  case outdatedModelPathError
  case modelDeleted
  case modelDeletionFailed
  case validHTTPResponse
  case validAuthToken
  case invalidOptions
  case invalidModelInfoFetchURL
  case downloadedModelInfoSaved
  case missingModelHash
  case invalidModelInfoJSON
  case modelInfoDeleted
  case modelInfoDownloaded
  case modelInfoUnmodified
  case authTokenError
  case expiredModelInfo
  case modelHashMismatchError
  case noModelHash
  case modelInfoRetrievalError
  case modelNotFound
  case invalidArgument
  case permissionDenied
  case resourceExhausted
  case notEnoughSpace
  case hostnameError
  case invalidHTTPResponse
  case analyticsEventEncodeError
  case telemetryInitError
  case testError
}

/// On-device logger.
enum DeviceLogger {
  /// Log identifier.
  static let service = "[Firebase/MLModelDownloader]"

  static func logEvent(level: FirebaseLoggerLevel, message: String,
                       messageCode: LoggerMessageCode) {
    let code = String(format: "I-MLM%06d", messageCode.rawValue)
    FirebaseLogger.log(level: level, service: DeviceLogger.service, code: code, message: message)
  }
}
