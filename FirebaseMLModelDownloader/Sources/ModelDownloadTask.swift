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
#if SWIFT_PACKAGE
  @_implementationOnly import GoogleUtilities_UserDefaults
#else
  @_implementationOnly import GoogleUtilities
#endif // SWIFT_PACKAGE

/// Task to download model file to device.
class ModelDownloadTask {
  /// Name of the app associated with this instance of ModelDownloadTask.
  private let appName: String

  /// Model info downloaded from server.
  private(set) var remoteModelInfo: RemoteModelInfo

  /// User defaults to which local model info should ultimately be written.
  private let defaults: GULUserDefaults

  /// Keeps track of download associated with this model download task.
  private(set) var downloadStatus: ModelDownloadStatus = .ready

  /// Downloader instance.
  private let downloader: FileDownloader

  /// Telemetry logger.
  private let telemetryLogger: TelemetryLogger?

  /// Download progress handler.
  typealias ProgressHandler = (Float) -> Void
  private var progressHandler: ProgressHandler?

  /// Download completion handler.
  typealias Completion = (Result<CustomModel, DownloadError>) -> Void
  private var completion: Completion

  init(remoteModelInfo: RemoteModelInfo,
       appName: String,
       defaults: GULUserDefaults,
       downloader: FileDownloader,
       progressHandler: ProgressHandler? = nil,
       completion: @escaping Completion,
       telemetryLogger: TelemetryLogger? = nil) {
    self.remoteModelInfo = remoteModelInfo
    self.appName = appName
    self.defaults = defaults
    self.downloader = downloader
    self.progressHandler = progressHandler
    self.completion = completion
    self.telemetryLogger = telemetryLogger
  }
}

extension ModelDownloadTask {
  /// Check if requests can be merged.
  func canMergeRequests() -> Bool {
    return downloadStatus != .complete
  }

  /// Merge duplicate requests. This method is not thread-safe.
  func merge(newProgressHandler: ProgressHandler? = nil, newCompletion: @escaping Completion) {
    let originalProgressHandler = progressHandler
    progressHandler = { progress in
      originalProgressHandler?(progress)
      newProgressHandler?(progress)
    }
    let originalCompletion = completion
    completion = { result in
      originalCompletion(result)
      newCompletion(result)
    }
  }

  /// Check if download task can be resumed.
  func canResume() -> Bool {
    return downloadStatus == .ready
  }

  /// Download model file.
  func resume() {
    // Prevent multiple concurrent downloads.
    guard downloadStatus != .downloading else {
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloadTask.ErrorDescription.anotherDownloadInProgress,
                            messageCode: .anotherDownloadInProgressError)
      telemetryLogger?.logModelDownloadEvent(eventName: .modelDownload,
                                             status: .failed,
                                             model: CustomModel(name: remoteModelInfo.name,
                                                                size: remoteModelInfo.size,
                                                                path: "",
                                                                hash: remoteModelInfo.modelHash),
                                             downloadErrorCode: .downloadFailed)
      return
    }
    downloadStatus = .downloading
    telemetryLogger?.logModelDownloadEvent(eventName: .modelDownload,
                                           status: .downloading,
                                           model: CustomModel(name: remoteModelInfo.name,
                                                              size: remoteModelInfo.size,
                                                              path: "",
                                                              hash: remoteModelInfo.modelHash),
                                           downloadErrorCode: .noError)
    downloader.downloadFile(with: remoteModelInfo.downloadURL,
                            progressHandler: { downloadedBytes, totalBytes in
                              /// Fraction of model file downloaded.
                              let calculatedProgress = Float(downloadedBytes) / Float(totalBytes)
                              self.progressHandler?(calculatedProgress)
                            }) { result in
      self.downloadStatus = .complete
      switch result {
      case let .success(response):
        DeviceLogger.logEvent(level: .debug,
                              message: ModelDownloadTask.DebugDescription
                                .receivedServerResponse,
                              messageCode: .validHTTPResponse)
        self.handleResponse(
          response: response.urlResponse,
          tempURL: response.fileURL,
          completion: self.completion
        )
      case let .failure(error):
        var downloadError: DownloadError
        switch error {
        case let FileDownloaderError.networkError(error):
          let description = ModelDownloadTask.ErrorDescription
            .invalidHostName(error.localizedDescription)
          downloadError = .failedPrecondition
          DeviceLogger.logEvent(level: .debug,
                                message: description,
                                messageCode: .hostnameError)
          self.telemetryLogger?.logModelDownloadEvent(
            eventName: .modelDownload,
            status: .failed,
            model: CustomModel(name: self.remoteModelInfo.name,
                               size: self.remoteModelInfo.size,
                               path: "",
                               hash: self.remoteModelInfo.modelHash),
            downloadErrorCode: .noConnection
          )
        case FileDownloaderError.unexpectedResponseType:
          let description = ModelDownloadTask.ErrorDescription.invalidHTTPResponse
          downloadError = .internalError(description: description)
          DeviceLogger.logEvent(level: .debug,
                                message: description,
                                messageCode: .invalidHTTPResponse)
          self.telemetryLogger?.logModelDownloadEvent(
            eventName: .modelDownload,
            status: .failed,
            model: CustomModel(name: self.remoteModelInfo.name,
                               size: self.remoteModelInfo.size,
                               path: "",
                               hash: self.remoteModelInfo.modelHash),
            downloadErrorCode: .downloadFailed
          )
        default:
          let description = ModelDownloadTask.ErrorDescription.unknownDownloadError
          downloadError = .internalError(description: description)
          DeviceLogger.logEvent(level: .debug,
                                message: description,
                                messageCode: .modelDownloadError)
          self.telemetryLogger?.logModelDownloadEvent(
            eventName: .modelDownload,
            status: .failed,
            model: CustomModel(name: self.remoteModelInfo.name,
                               size: self.remoteModelInfo.size,
                               path: "",
                               hash: self.remoteModelInfo.modelHash),
            downloadErrorCode: .downloadFailed
          )
        }
        self.completion(.failure(downloadError))
      }
    }
  }

  /// Handle model download response.
  func handleResponse(response: HTTPURLResponse, tempURL: URL, completion: @escaping Completion) {
    guard (200 ..< 299).contains(response.statusCode) else {
      switch response.statusCode {
      case 400:
        // Possible failure due to download URL expiry. Check if download URL has expired.
        guard remoteModelInfo.urlExpiryTime < Date() else {
          DeviceLogger.logEvent(level: .debug,
                                message: ModelDownloadTask.ErrorDescription
                                  .invalidArgument(remoteModelInfo.name),
                                messageCode: .invalidArgument)
          telemetryLogger?.logModelDownloadEvent(
            eventName: .modelDownload,
            status: .failed,
            model: CustomModel(name: remoteModelInfo.name,
                               size: remoteModelInfo.size,
                               path: "",
                               hash: remoteModelInfo.modelHash),
            downloadErrorCode: .httpError(code: response.statusCode)
          )
          completion(.failure(.invalidArgument))
          return
        }
        DeviceLogger.logEvent(level: .debug,
                              message: ModelDownloadTask.ErrorDescription.expiredModelInfo,
                              messageCode: .expiredModelInfo)
        telemetryLogger?.logModelDownloadEvent(
          eventName: .modelDownload,
          status: .failed,
          model: CustomModel(name: remoteModelInfo.name,
                             size: remoteModelInfo.size,
                             path: "",
                             hash: remoteModelInfo.modelHash),
          downloadErrorCode: .urlExpired
        )
        completion(.failure(.expiredDownloadURL))
      case 401, 403:
        DeviceLogger.logEvent(level: .debug,
                              message: ModelDownloadTask.ErrorDescription.permissionDenied,
                              messageCode: .permissionDenied)
        telemetryLogger?.logModelDownloadEvent(
          eventName: .modelDownload,
          status: .failed,
          model: CustomModel(name: remoteModelInfo.name,
                             size: remoteModelInfo.size,
                             path: "",
                             hash: remoteModelInfo.modelHash),
          downloadErrorCode: .httpError(code: response.statusCode)
        )
        completion(.failure(.permissionDenied))
      case 404:
        DeviceLogger.logEvent(level: .debug,
                              message: ModelDownloadTask.ErrorDescription
                                .modelNotFound(remoteModelInfo.name),
                              messageCode: .modelNotFound)
        telemetryLogger?.logModelDownloadEvent(
          eventName: .modelDownload,
          status: .failed,
          model: CustomModel(name: remoteModelInfo.name,
                             size: remoteModelInfo.size,
                             path: "",
                             hash: remoteModelInfo.modelHash),
          downloadErrorCode: .httpError(code: response.statusCode)
        )
        completion(.failure(.notFound))
      default:
        let description = ModelDownloadTask.ErrorDescription
          .modelDownloadFailed(response.statusCode)
        DeviceLogger.logEvent(level: .debug,
                              message: description,
                              messageCode: .modelDownloadError)
        telemetryLogger?.logModelDownloadEvent(
          eventName: .modelDownload,
          status: .failed,
          model: CustomModel(name: remoteModelInfo.name,
                             size: remoteModelInfo.size,
                             path: "",
                             hash: remoteModelInfo.modelHash),
          downloadErrorCode: .httpError(code: response.statusCode)
        )
        completion(.failure(.internalError(description: description)))
      }
      return
    }

    /// Construct local model file URL.
    guard var modelFileURL = ModelFileManager.getDownloadedModelFileURL(
      appName: appName,
      modelName: remoteModelInfo.name
    ) else {
      // Could not create Application Support directory to store model files.
      let description = ModelDownloadTask.ErrorDescription.noModelsDirectory
      DeviceLogger.logEvent(level: .debug,
                            message: description,
                            messageCode: .downloadedModelSaveError)
      // Downloading the file succeeding but saving failed.
      telemetryLogger?.logModelDownloadEvent(eventName: .modelDownload,
                                             status: .succeeded,
                                             model: CustomModel(name: remoteModelInfo.name,
                                                                size: remoteModelInfo.size,
                                                                path: "",
                                                                hash: remoteModelInfo.modelHash),
                                             downloadErrorCode: .downloadFailed)
      completion(.failure(.internalError(description: description)))
      return
    }

    do {
      // Try disabling iCloud backup for model files, because UserDefaults is not backed up.
      var resourceValue = URLResourceValues()
      resourceValue.isExcludedFromBackup = true
      do {
        try modelFileURL.setResourceValues(resourceValue)
      } catch {
        DeviceLogger.logEvent(level: .debug,
                              message: ModelDownloadTask.ErrorDescription.disableBackupError,
                              messageCode: .disableBackupError)
      }
      // Save model file to device.
      try ModelFileManager.moveFile(
        at: tempURL,
        to: modelFileURL,
        size: Int64(remoteModelInfo.size)
      )
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloadTask.DebugDescription.savedModelFile,
                            messageCode: .downloadedModelFileSaved)
      // Generate local model info.
      let localModelInfo = LocalModelInfo(from: remoteModelInfo)
      // Write model info to user defaults.
      localModelInfo.writeToDefaults(defaults, appName: appName)
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloadTask.DebugDescription.savedLocalModelInfo,
                            messageCode: .downloadedModelInfoSaved)
      // Build model from model info and local path.
      let model = CustomModel(localModelInfo: localModelInfo, path: modelFileURL.path)
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloadTask.DebugDescription.modelDownloaded,
                            messageCode: .modelDownloaded)
      telemetryLogger?.logModelDownloadEvent(
        eventName: .modelDownload,
        status: .succeeded,
        model: model,
        downloadErrorCode: .noError
      )
      completion(.success(model))
    } catch let error as DownloadError {
      if error == .notEnoughSpace {
        DeviceLogger.logEvent(level: .debug,
                              message: ModelDownloadTask.ErrorDescription.notEnoughSpace,
                              messageCode: .notEnoughSpace)
      } else {
        DeviceLogger.logEvent(level: .debug,
                              message: ModelDownloadTask.ErrorDescription.modelSaveError,
                              messageCode: .downloadedModelSaveError)
      }
      // Downloading the file succeeding but saving failed.
      telemetryLogger?.logModelDownloadEvent(eventName: .modelDownload,
                                             status: .succeeded,
                                             model: CustomModel(name: remoteModelInfo.name,
                                                                size: remoteModelInfo.size,
                                                                path: "",
                                                                hash: remoteModelInfo.modelHash),
                                             downloadErrorCode: .downloadFailed)
      completion(.failure(error))
      return
    } catch {
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloadTask.ErrorDescription.modelSaveError,
                            messageCode: .downloadedModelSaveError)
      // Downloading the file succeeding but saving failed.
      telemetryLogger?.logModelDownloadEvent(eventName: .modelDownload,
                                             status: .succeeded,
                                             model: CustomModel(name: remoteModelInfo.name,
                                                                size: remoteModelInfo.size,
                                                                path: "",
                                                                hash: remoteModelInfo.modelHash),
                                             downloadErrorCode: .downloadFailed)
      completion(.failure(.internalError(description: error.localizedDescription)))
      return
    }
  }
}

/// Possible states of model downloading.
enum ModelDownloadStatus {
  case ready
  case downloading
  case complete
}

/// Download error codes.
enum ModelDownloadErrorCode {
  case noError
  case urlExpired
  case noConnection
  case downloadFailed
  case httpError(code: Int)
}

/// Possible debug and error messages for model downloading.
extension ModelDownloadTask {
  /// Debug descriptions.
  private enum DebugDescription {
    static let receivedServerResponse = "Received a valid response from download server."
    static let savedModelFile = "Model file saved successfully to device."
    static let savedLocalModelInfo = "Downloaded model info saved successfully to user defaults."
    static let modelDownloaded = "Model download completed successfully."
  }

  /// Error descriptions.
  private enum ErrorDescription {
    static let invalidHostName = { (error: String) in
      "Unable to resolve hostname or connect to host: \(error)"
    }

    static let sessionInvalidated = "Session invalidated due to failed pre-conditions."
    static let invalidHTTPResponse = "Could not get valid HTTP response for model downloading."
    static let anotherDownloadInProgress = "Download already in progress."
    static let modelNotFound = { (name: String) in
      "No model found with name: \(name)"
    }

    static let invalidArgument = { (name: String) in
      "Invalid argument for model name: \(name)"
    }

    static let expiredModelInfo = "Unable to update expired model info."
    static let permissionDenied = "Invalid or missing permissions to download model."
    static let notEnoughSpace = "Not enough space on device."
    static let disableBackupError = "Unable to disable model file backup."
    static let noModelsDirectory = "Could not create directory for model storage."
    static let modelSaveError = "Unable to save downloaded remote model file."
    static let unknownDownloadError = "Unable to download model due to unknown error."
    static let modelDownloadFailed = { (code: Int) in
      "Model download failed with HTTP error code: \(code)"
    }
  }
}
