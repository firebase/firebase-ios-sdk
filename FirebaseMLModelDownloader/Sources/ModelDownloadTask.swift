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
  private(set) var modelInfo: ModelInfo
  private var downloadTask: URLSessionDownloadTask?
  private let downloadHandlers: DownloadHandlers

  private(set) var downloadStatus: DownloadStatus = .notStarted

  private lazy var downloadSession = URLSession(configuration: .ephemeral,
                                                delegate: self,
                                                delegateQueue: nil)

  init(modelInfo: ModelInfo, appName: String,
       progressHandler: DownloadHandlers.ProgressHandler? = nil,
       completion: @escaping DownloadHandlers.Completion) {
    self.modelInfo = modelInfo
    self.appName = appName
    downloadHandlers = DownloadHandlers(
      progressHandler: progressHandler,
      completion: completion
    )
  }

  /// Asynchronously download model file to device.
  func resumeModelDownload() {
    guard downloadStatus == .notStarted else { return }
    let downloadTask = downloadSession.downloadTask(with: modelInfo.downloadURL)
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
    } catch {
      downloadHandlers
        .completion(.failure(.internalError(description: error.localizedDescription)))
      return
    }

    /// Set path to local model.
    modelInfo.path = savedURL.absoluteString
    /// Write model to user defaults.
    do {
      try modelInfo.save(toDefaults: .firebaseMLDefaults, appName: appName)
    } catch {
      downloadHandlers
        .completion(.failure(.internalError(description: error.localizedDescription)))
    }
    /// Build model from model info.
    guard let model = buildModel() else {
      downloadHandlers
        .completion(
          .failure(
            .internalError(description: "Could not create model due to incomplete model info.")
          )
        )
      return
    }
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
    return "fbml_model__\(appName)__\(modelInfo.name)"
  }

  /// Build custom model object from model info.
  // TODO: Consider moving this to CustomModel as a convenience init
  func buildModel() -> CustomModel? {
    /// Build custom model only if the model file is already on device.
    guard let path = modelInfo.path else { return nil }
    let model = CustomModel(
      name: modelInfo.name,
      size: modelInfo.size,
      path: path,
      hash: modelInfo.modelHash
    )
    return model
  }

  /// Get the local path to model on device.
  func getLocalModelPath(model: CustomModel) -> URL? {
    let fileURL: URL = ModelFileManager.modelsDirectory
      .appendingPathComponent(downloadedModelFileName)
    if ModelFileManager.isFileReachable(at: fileURL) {
      return fileURL
    } else {
      return nil
    }
  }
}

/// Named user defaults for FirebaseML.
extension UserDefaults {
  static var firebaseMLDefaults: UserDefaults {
    let suiteName = "com.google.firebase.ml"
    // TODO: reconsider force unwrapping
    let defaults = UserDefaults(suiteName: suiteName)!
    return defaults
  }
}
