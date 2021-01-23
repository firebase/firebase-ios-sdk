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
import FirebaseCore

/// Possible states of model downloading.
enum ModelDownloadStatus {
  case notStarted
  case inProgress
  case successful
  case failed
}

/// Progress and completion handlers for a model download.
class DownloadHandlers {
  typealias ProgressHandler = (Float) -> Void
  typealias Completion = (Result<CustomModel, DownloadError>) -> Void

  var progressHandler: ProgressHandler?
  var completion: Completion

  init(progressHandler: ProgressHandler?, completion: @escaping Completion) {
    self.progressHandler = progressHandler
    self.completion = completion
  }
}

/// Manager to handle model downloading device and storing downloaded model info to persistent storage.
class ModelDownloadTask: NSObject {
  /// Name of the app associated with this instance of ModelDownloadTask.
  private let appName: String
  /// Model info downloaded from server.
  private(set) var remoteModelInfo: RemoteModelInfo
  /// User defaults to which local model info should ultimately be written.
  private let defaults: UserDefaults
  /// Progress and completion handlers associated with this model download task.
  private let downloadHandlers: DownloadHandlers
  /// Keeps track of download associated with this model download task.
  private(set) var downloadStatus: ModelDownloadStatus
  /// Downloader instance.
  private let downloader: FileDownloader
  /// Model info retriever in case of retries.
  private let modelInfoRetriever: ModelInfoRetriever
  /// Number of retries in case of model download URL expiry.
  private var numberOfRetries: Int = 1
  /// Telemetry logger.
  private let telemetryLogger: TelemetryLogger?

  init(remoteModelInfo: RemoteModelInfo,
       appName: String,
       defaults: UserDefaults,
       downloader: FileDownloader,
       modelInfoRetriever: ModelInfoRetriever,
       telemetryLogger: TelemetryLogger? = nil,
       progressHandler: DownloadHandlers.ProgressHandler? = nil,
       completion: @escaping DownloadHandlers.Completion) {
    self.remoteModelInfo = remoteModelInfo
    self.appName = appName
    self.downloader = downloader
    self.modelInfoRetriever = modelInfoRetriever
    self.telemetryLogger = telemetryLogger
    self.defaults = defaults
    downloadHandlers = DownloadHandlers(
      progressHandler: progressHandler,
      completion: completion
    )
    downloadStatus = .notStarted
  }
}

extension ModelDownloadTask {
  /// Name for model file stored on device.
  var downloadedModelFileName: String {
    return "fbml_model__\(appName)__\(remoteModelInfo.name)"
  }

  func download() {
    downloader.downloadFile(with: remoteModelInfo.downloadURL,
                            progressHandler: { downloadedBytes, totalBytes in
                              /// Fraction of model file downloaded.
                              let calculatedProgress = Float(downloadedBytes) / Float(totalBytes)
                              DispatchQueue.main.async {
                                self.downloadHandlers.progressHandler?(calculatedProgress)
                              }
                            }) { result in
      switch result {
      case let .success(response):
        self.handleResponse(response: response.urlResponse, tempURL: response.fileURL)
      case let .failure(error):
        var downloadError: DownloadError
        switch error {
        case let FileDownloaderError.networkError(error):
          downloadError = .internalError(description: ModelDownloadTask
            .ErrorDescription
            .invalidHostName(error
              .localizedDescription))
        case let FileDownloaderError.sessionInvalidated(error):
          downloadError = .failedPrecondition
        case FileDownloaderError.unexpectedResponseType:
          downloadError = .internalError(description: ModelDownloadTask
            .ErrorDescription.invalidServerResponse)

        default:
          downloadError = .internalError(description: ModelDownloadTask.ErrorDescription
            .unknownDownloadError)
        }
        DispatchQueue.main.async {
          self.downloadHandlers
            .completion(.failure(downloadError))
        }
      }
    }
  }

  /// Fetch model info again and retry download if allowed.
  // TODO: Move this to model downloader.
  func maybeRetryDownload() {
    let currentDateTime = Date()
    guard currentDateTime > remoteModelInfo.urlExpiryTime, numberOfRetries > 0 else {
      downloadStatus = .failed
      downloadHandlers
        .completion(.failure(.internalError(description: ModelDownloadTask.ErrorDescription
            .expiredModelInfo)))
      return
    }
    numberOfRetries -= 1
    modelInfoRetriever.downloadModelInfo { result in
      switch result {
      case let .success(downloadModelInfoResult):
        switch downloadModelInfoResult {
        /// New model info was downloaded from server.
        case let .modelInfo(remoteModelInfo):
          self.remoteModelInfo = remoteModelInfo
          self.downloadStatus = .notStarted
          self.download()
        /// This should not ever be the case - model info cannot be unmodified within ModelDownloadTask.
        case .notModified:
          DispatchQueue.main.async {
            self.downloadHandlers
              .completion(.failure(.internalError(description: ModelDownloadTask
                  .ErrorDescription.expiredModelInfo)))
          }
        }
      case .failure:
        self.downloadStatus = .failed
        DispatchQueue.main.async {
          self.downloadHandlers
            .completion(.failure(.internalError(description: ModelDownloadTask
                .ErrorDescription.expiredModelInfo)))
        }
      }
    }
  }

  /// Handle model download response.
  func handleResponse(response: HTTPURLResponse, tempURL: URL) {
    /// Retry model download if url expired.
    guard (200 ..< 299).contains(response.statusCode) else {
      /// Possible failure due to download URL expiry.
      if response.statusCode == 400 {
        maybeRetryDownload()
        return
      }
      return
    }

    let modelFileURL = ModelFileManager.getDownloadedModelFilePath(
      appName: appName,
      modelName: remoteModelInfo.name
    )

    do {
      try ModelFileManager.moveFile(at: tempURL, to: modelFileURL)
      /// Generate local model info.
      let localModelInfo = LocalModelInfo(from: remoteModelInfo, path: modelFileURL.absoluteString)
      /// Write model to user defaults.
      localModelInfo.writeToDefaults(defaults, appName: appName)
      /// Build model from model info.
      let model = CustomModel(localModelInfo: localModelInfo)
      downloadStatus = .successful
      telemetryLogger?.logModelDownloadEvent(
        eventName: .modelDownload,
        status: downloadStatus,
        model: model
      )

      DispatchQueue.main.async {
        self.downloadHandlers.completion(.success(model))
      }
    } catch let error as DownloadError {
      downloadStatus = .failed
      telemetryLogger?.logModelDownloadEvent(eventName: .modelDownload, status: downloadStatus)
      DeviceLogger.logEvent(
        level: .info,
        category: .modelDownload,
        message: ModelDownloadTask.ErrorDescription.saveModel,
        messageCode: .modelDownloaded
      )
      DispatchQueue.main.async {
        self.downloadHandlers
          .completion(.failure(error))
      }
      return
    } catch {
      downloadStatus = .failed
      telemetryLogger?.logModelDownloadEvent(eventName: .modelDownload, status: downloadStatus)
      DeviceLogger.logEvent(
        level: .info,
        category: .modelDownload,
        message: ModelDownloadTask.ErrorDescription.saveModel,
        messageCode: .modelDownloaded
      )
      DispatchQueue.main.async {
        self.downloadHandlers
          .completion(.failure(.internalError(description: error.localizedDescription)))
      }
      return
    }
  }
}

/// Possible error messages for model downloading.
extension ModelDownloadTask {
  /// Error descriptions.
  private enum ErrorDescription {
    static let invalidHostName = { (error: String) in
      "Unable to resolve hostname or connect to host: \(error)"
    }

    static let invalidServerResponse =
      "Could not get server response for model downloading."
    static let unknownDownloadError = "Unable to download model due to unknown error."
    static let saveModel: StaticString =
      "Unable to save downloaded remote model file."
    static let expiredModelInfo = "Unable to update expired model info."
  }
}
