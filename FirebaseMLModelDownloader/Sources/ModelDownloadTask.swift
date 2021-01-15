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
  /// Model conditions for download.
  private let conditions: ModelDownloadConditions
  /// User defaults to which local model info should ultimately be written.
  private let defaults: UserDefaults
  /// Task to handle model file download.
  private var downloadTask: URLSessionDownloadTask?
  /// Progress and completion handlers associated with this model download task.
  private let downloadHandlers: DownloadHandlers
  /// Keeps track of download associated with this model download task.
  private(set) var downloadStatus: ModelDownloadStatus
  /// Background session identifier.
  private let backgroundSessionIdentifier = "ModelDownloadBackgroundSession"
  /// Optional background completion handler.
  private var backgroundCompletion: (() -> Void)?
  /// URLSession to handle model downloads.
  private lazy var downloadSession: URLSession = {
    var configuration = URLSessionConfiguration.ephemeral
    if conditions.allowsBackgroundDownloading {
      configuration = URLSessionConfiguration
        .background(withIdentifier: backgroundSessionIdentifier)
      configuration.sessionSendsLaunchEvents = true
    }
    if #available(iOS 11.0, *) {
      configuration.waitsForConnectivity = true
      configuration.timeoutIntervalForResource = 60
    }
    configuration.allowsCellularAccess = conditions.allowsCellularAccess
    return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
  }()

  /// Telemetry logger.
  private let telemetryLogger: TelemetryLogger?

  init(remoteModelInfo: RemoteModelInfo, conditions: ModelDownloadConditions, appName: String,
       defaults: UserDefaults,
       telemetryLogger: TelemetryLogger? = nil,
       progressHandler: DownloadHandlers.ProgressHandler? = nil,
       completion: @escaping DownloadHandlers.Completion) {
    self.remoteModelInfo = remoteModelInfo
    self.conditions = conditions
    self.appName = appName
    self.telemetryLogger = telemetryLogger
    self.defaults = defaults
    downloadHandlers = DownloadHandlers(
      progressHandler: progressHandler,
      completion: completion
    )
    downloadStatus = .notStarted
  }

  /// Asynchronously download model file to device.
  func resumeModelDownload() {
    guard downloadStatus == .notStarted else { return }
    let downloadTask = downloadSession.downloadTask(with: remoteModelInfo.downloadURL)
    downloadTask.resume()
    downloadStatus = .inProgress
    self.downloadTask = downloadTask
  }
}

/// Extension to handle delegate methods.
extension ModelDownloadTask: URLSessionDownloadDelegate {
  /// Name for model file stored on device.
  var downloadedModelFileName: String {
    return "fbml_model__\(appName)__\(remoteModelInfo.name)"
  }

  func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
    // TODO: Handle waiting for connectivity, if needed.
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    // TODO: Handle client errors.
  }

  func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
    // TODO: Handle configuration errors.
  }

  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didFinishDownloadingTo location: URL) {
    assert(downloadTask == self.downloadTask)
    guard let response = downloadTask.response as? HTTPURLResponse else {
      // TODO: Handle error.
      return
    }
    if response.statusCode == 404 {
      // TODO: Check if model download url expired; if yes then retry.
      return
    }

    let modelFileURL = ModelFileManager.getDownloadedModelFilePath(
      appName: appName,
      modelName: remoteModelInfo.name
    )
    do {
      try ModelFileManager.moveFile(at: location, to: modelFileURL)
    } catch let error as DownloadError {
      downloadStatus = .failed
      telemetryLogger?.logModelDownloadEvent(eventName: .modelDownload, status: downloadStatus)
      DeviceLogger.logEvent(
        level: .info,
        category: .modelDownload,
        message: "Unable to save downloaded remote model file.",
        messageCode: .modelDownloaded
      )
      DispatchQueue.main.async {
        self.downloadHandlers
          .completion(.failure(error))
      }
    } catch {
      downloadStatus = .failed
      telemetryLogger?.logModelDownloadEvent(eventName: .modelDownload, status: downloadStatus)
      DeviceLogger.logEvent(
        level: .info,
        category: .modelDownload,
        message: "Unable to save downloaded remote model file.",
        messageCode: .modelDownloaded
      )
      DispatchQueue.main.async {
        self.downloadHandlers
          .completion(.failure(.internalError(description: error.localizedDescription)))
      }
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

  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didWriteData bytesWritten: Int64,
                  totalBytesWritten: Int64,
                  totalBytesExpectedToWrite: Int64) {
    assert(downloadTask == self.downloadTask)
    /// Check if progress handler is unspecified.
    guard let progressHandler = downloadHandlers.progressHandler else { return }
    let calculatedProgress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
    DispatchQueue.main.async {
      progressHandler(calculatedProgress)
    }
  }
}

/// Extension to handle background downloading.
extension ModelDownloadTask: UIApplicationDelegate {
  /// Save completion handler for background download.
  func application(_ application: UIApplication,
                   handleEventsForBackgroundURLSession identifier: String,
                   completionHandler: @escaping () -> Void) {
    assert(identifier == backgroundSessionIdentifier)
    backgroundCompletion = completionHandler
  }

  /// Call background completion handler when resumed from background.
  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    DispatchQueue.main.async {
      guard let backgroundCompletionHandler = self.backgroundCompletion else { return }
      backgroundCompletionHandler()
    }
  }
}
