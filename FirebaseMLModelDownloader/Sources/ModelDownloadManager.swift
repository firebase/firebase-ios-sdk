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
class DownloadHandlers: NSObject {
  typealias ProgressHandler = (Float) -> Void
  typealias Completion = (Result<CustomModel, DownloadError>) -> Void

  var progressHandler: ProgressHandler?
  var completion: Completion

  init(progressHandler: ProgressHandler?, completion: @escaping Completion) {
    self.progressHandler = progressHandler
    self.completion = completion
  }
}

/// Manager for model downloads.
class ModelDownloadManager: NSObject {
  let app: FirebaseApp
  var modelInfo: ModelInfo
  var taskHandlers: [URLSessionDownloadTask: DownloadHandlers] = [:]

  private(set) var downloadStatus: DownloadStatus = .notStarted

  private lazy var downloadSession = URLSession(configuration: .ephemeral,
                                                delegate: self,
                                                delegateQueue: nil)

  init(app: FirebaseApp, modelInfo: ModelInfo) {
    self.app = app
    self.modelInfo = modelInfo
  }

  private func setHandlers(for downloadTask: URLSessionDownloadTask, handlers: DownloadHandlers) {
    taskHandlers[downloadTask] = handlers
  }

  private func getHandlers(for downloadTask: URLSessionDownloadTask) -> DownloadHandlers? {
    return taskHandlers[downloadTask]
  }

  func startModelDownload(url: URL, progressHandler: DownloadHandlers.ProgressHandler? = nil,
                          completion: @escaping DownloadHandlers.Completion) {
    let downloadTask = downloadSession.downloadTask(with: url)
    let downloadHandlers = DownloadHandlers(
      progressHandler: progressHandler,
      completion: completion
    )
    setHandlers(for: downloadTask, handlers: downloadHandlers)
    downloadTask.resume()
    downloadStatus = .inProgress
  }
}

extension ModelDownloadManager: URLSessionDownloadDelegate {
  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didFinishDownloadingTo location: URL) {
    guard let handlers = getHandlers(for: downloadTask) else { return }
    downloadStatus = .completed
    let savedURL = ModelFileManager.modelsDirectory
      .appendingPathComponent(downloadedModelFileName)
    do {
      try ModelFileManager.moveFile(at: location, to: savedURL)
    } catch {
      let errorDescription = error.localizedDescription
      handlers.completion(.failure(.internalError(description: errorDescription)))
      return
    }

    modelInfo.path = savedURL.absoluteString
    guard let model = buildModel() else {
      handlers.completion(.failure(.internalError(description: "Incomplete model info.")))
      return
    }
    handlers.completion(.success(model))
  }

  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didWriteData bytesWritten: Int64,
                  totalBytesWritten: Int64,
                  totalBytesExpectedToWrite: Int64) {
    guard let handlers = getHandlers(for: downloadTask) else { return }
    let calculatedProgress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
    handlers.progressHandler?(calculatedProgress)
  }
}

extension ModelDownloadManager {
  var downloadedModelFileName: String {
    return "fbml_model__\(app.name)__\(modelInfo.name)"
  }

  /// Build custom model object from model info.
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
