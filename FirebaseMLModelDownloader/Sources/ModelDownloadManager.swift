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
  case failed
  case unknown
}

class Downloader : NSObject {
  let downloadTask : URLSessionDownloadTask
  var progressHandler : ModelDownloadManager.progressHandler?
  var completion : ModelDownloadManager.completion

  init(downloadTask : URLSessionDownloadTask, progressHandler : ModelDownloadManager.progressHandler?, completion : @escaping ModelDownloadManager.completion) {
    self.downloadTask = downloadTask
    self.progressHandler = progressHandler
    self.completion = completion
  }
}

class ModelDownloadManager : NSObject {

  var app : FirebaseApp
  var modelInfo : ModelInfo
  var downloadTask : URLSessionDownloadTask?

  typealias progressHandler = (Float) -> Void
  typealias completion = (Result<CustomModel, DownloadError>) -> Void

  var downloadedModelFileName : String {
    get {
      return "fbml_model__\(app.name)__\(modelInfo.name)"
    }
  }

  init(app : FirebaseApp, modelInfo : ModelInfo) {
    self.app = app
    self.modelInfo = modelInfo
  }

  func getLocalModelPath(model : CustomModel) -> URL? {
    let fileURL : URL = ModelFileManager.modelsDirectory.appendingPathComponent(downloadedModelFileName)
    if ModelFileManager.isFileReachable(at: fileURL) {
      return fileURL
    } else {
      return nil
    }
  }

  private lazy var downloadSession = URLSession(configuration: .ephemeral,
                                                delegate: self,
                                                delegateQueue: nil)

  func startModelDownload(url: URL) {
    let downloadTask = self.downloadSession.downloadTask(with: url)
    downloadTask.resume()
    self.downloadTask = downloadTask
  }

}

extension ModelDownloadManager : URLSessionDownloadDelegate {
  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didFinishDownloadingTo location: URL) {

    guard let response = downloadTask.response as? HTTPURLResponse else { return }
    print("Downloaded \(response) to \(location).")

    do {
      let documentsURL = try FileManager.default.url(for: .documentDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: false)
      let savedURL = documentsURL.appendingPathComponent(
        location.lastPathComponent)
      print(savedURL)
      try FileManager.default.moveItem(at: location, to: savedURL)
    } catch {
      // handle filesystem error
    }

  }

  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didWriteData bytesWritten: Int64,
                  totalBytesWritten: Int64,
                  totalBytesExpectedToWrite: Int64) {
    if downloadTask == self.downloadTask {
      let calculatedProgress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
      DispatchQueue.main.async {
        print(calculatedProgress)
      }
    }
  }
}

