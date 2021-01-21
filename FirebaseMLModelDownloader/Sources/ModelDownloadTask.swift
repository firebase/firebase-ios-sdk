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
  /// Task to handle model file download.
  private var downloadTask: URLSessionDownloadTask?
  /// Progress and completion handlers associated with this model download task.
  private let downloadHandlers: DownloadHandlers
  /// Keeps track of download associated with this model download task.
  private(set) var downloadStatus: ModelDownloadStatus
  /// URLSession to handle model downloads.
  private lazy var downloadSession = URLSession(configuration: .ephemeral,
                                                delegate: self,
                                                delegateQueue: nil)
  /// Model info retriever in case of retries.
  private let modelInfoRetriever: ModelInfoRetriever
  /// Number of retries in case of model download URL expiry.
  private var numberOfRetries: Int = 1
  /// Telemetry logger.
  private let telemetryLogger: TelemetryLogger?

  init(remoteModelInfo: RemoteModelInfo, appName: String, defaults: UserDefaults,
       modelInfoRetriever: ModelInfoRetriever,
       telemetryLogger: TelemetryLogger? = nil,
       progressHandler: DownloadHandlers.ProgressHandler? = nil,
       completion: @escaping DownloadHandlers.Completion) {
    self.remoteModelInfo = remoteModelInfo
    self.appName = appName
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
  /// Asynchronously download model file to device.
  func resumeModelDownload() {
    guard downloadStatus == .notStarted else { return }
    let downloadTask = downloadSession.downloadTask(with: remoteModelInfo.downloadURL)
    downloadTask.resume()
    downloadStatus = .inProgress
    self.downloadTask = downloadTask
  }

  /// Fetch model info again and retry download.
  func retryDownload() {
    modelInfoRetriever.downloadModelInfo { result in
      switch result {
      case let .success(downloadModelInfoResult):
        switch downloadModelInfoResult {
        /// New model info was downloaded from server.
        case let .modelInfo(remoteModelInfo):
          self.remoteModelInfo = remoteModelInfo
          self.downloadStatus = .notStarted
          self.resumeModelDownload()
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
        let currentDateTime = Date()
        /// Retry download if allowed.
        guard currentDateTime > remoteModelInfo.urlExpiryTime, numberOfRetries > 0 else {
          downloadStatus = .failed
          downloadHandlers
            .completion(.failure(.internalError(description: ModelDownloadTask.ErrorDescription
                .expiredModelInfo)))
          return
        }
        retryDownload()
        numberOfRetries -= 1
      }
      return
    }

    let modelFileURL = ModelFileManager.getDownloadedModelFilePath(
      appName: appName,
      modelName: remoteModelInfo.name
    )
    do {
      try ModelFileManager.moveFile(at: tempURL, to: modelFileURL)
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
  }
}

/// Extension to handle delegate methods.
extension ModelDownloadTask: URLSessionDownloadDelegate {
  /// Name for model file stored on device.
  var downloadedModelFileName: String {
    return "fbml_model__\(appName)__\(remoteModelInfo.name)"
  }

  /// Handle client-side errors.
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    // TODO: Log this.
    guard task == downloadTask else { return }
    guard let error = error else { return }
    /// Unable to resolve hostname or connect to host.
    DispatchQueue.main.async {
      self.downloadHandlers
        .completion(.failure(.internalError(description: ModelDownloadTask.ErrorDescription
            .invalidHostName(error.localizedDescription))))
    }
  }

  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didFinishDownloadingTo location: URL) {
    // TODO: Log this.
    guard downloadTask == self.downloadTask else { return }
    guard let response = downloadTask.response as? HTTPURLResponse else {
      DispatchQueue.main.async {
        self.downloadHandlers
          .completion(.failure(.internalError(description: ModelDownloadTask
              .ErrorDescription.invalidServerResponse)))
      }
      return
    }

    handleResponse(response: response, tempURL: location)
  }

  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didWriteData bytesWritten: Int64,
                  totalBytesWritten: Int64,
                  totalBytesExpectedToWrite: Int64) {
    // TODO: Log this.
    guard downloadTask == self.downloadTask else { return }
    /// Check if progress handler is unspecified.
    guard let progressHandler = downloadHandlers.progressHandler else { return }
    let calculatedProgress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
    DispatchQueue.main.async {
      progressHandler(calculatedProgress)
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
    static let saveModel: StaticString =
      "Unable to save downloaded remote model file."
    static let expiredModelInfo = "Unable to update expired model info."
  }
}
