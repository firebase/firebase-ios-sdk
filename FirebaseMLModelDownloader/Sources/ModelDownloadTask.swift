// Copyright 2020 Google LLC
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

enum DownloadStatus {
  case notStarted
  case inProgress
  case completed
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
  private let appName: String
  private(set) var remoteModelInfo: RemoteModelInfo
  private let defaults: UserDefaults
  private var downloadTask: URLSessionDownloadTask?
  private let downloadHandlers: DownloadHandlers

  private(set) var downloadStatus: DownloadStatus = .notStarted

  private lazy var downloadSession = URLSession(configuration: .ephemeral,
                                                delegate: self,
                                                delegateQueue: nil)

  init(remoteModelInfo: RemoteModelInfo, appName: String, defaults: UserDefaults,
       progressHandler: DownloadHandlers.ProgressHandler? = nil,
       completion: @escaping DownloadHandlers.Completion) {
    self.remoteModelInfo = remoteModelInfo
    self.appName = appName
    self.defaults = defaults
    downloadHandlers = DownloadHandlers(
      progressHandler: progressHandler,
      completion: completion
    )
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
  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didFinishDownloadingTo location: URL) {
    assert(downloadTask == self.downloadTask)
    downloadStatus = .completed
    let savedURL = ModelFileManager.modelsDirectory
      .appendingPathComponent(downloadedModelFileName)
    do {
      try ModelFileManager.moveFile(at: location, to: savedURL)
    } catch let error as DownloadError {
      downloadHandlers
        .completion(.failure(error))
    } catch {
      downloadHandlers
        .completion(.failure(.internalError(description: error.localizedDescription)))
    }

    /// Generate local model info.
    let localModelInfo = LocalModelInfo(from: remoteModelInfo, path: savedURL.absoluteString)
    /// Write model to user defaults.
    localModelInfo.writeToDefaults(defaults, appName: appName)
    /// Build model from model info.
    let model = CustomModel(localModelInfo: localModelInfo)
    downloadHandlers.completion(.success(model))
  }

  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didWriteData bytesWritten: Int64,
                  totalBytesWritten: Int64,
                  totalBytesExpectedToWrite: Int64) {
    assert(downloadTask == self.downloadTask)
    guard let progressHandler = downloadHandlers.progressHandler else { return }
    let calculatedProgress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
    progressHandler(calculatedProgress)
  }
}

/// Extension to handle post-download operations.
extension ModelDownloadTask {
  var downloadedModelFileName: String {
    return "fbml_model__\(appName)__\(remoteModelInfo.name)"
  }

  /// Get the local path to model on device.
  func getLocalModelPath() -> URL? {
    let fileURL: URL = ModelFileManager.modelsDirectory
      .appendingPathComponent(downloadedModelFileName)
    if ModelFileManager.isFileReachable(at: fileURL) {
      return fileURL
    } else {
      return nil
    }
  }
}
