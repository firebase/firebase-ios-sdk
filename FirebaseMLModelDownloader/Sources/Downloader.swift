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

  var app : FirebaseApp
  var model : CustomModel
  var downloadTask : URLSessionDownloadTask?
  let userDefaults = UserDefaults.standard

  static var modelDownloadingKeyPrefix : String {
    get {
      let bundleID = Bundle.main.bundleIdentifier
      return "com.google.firebase.ml.cloud.\(bundleID ?? "")."
    }
  }

  var downloadedModelFileName : String {
    get {
      return "fbml_model__\(app.name)__\(model.name)"
    }
  }

  init(app : FirebaseApp, model : CustomModel) {
    self.app = app
    self.model = model
  }
  
  func getLocalModelPath(model : CustomModel) -> URL? {
    let fileURL : URL = ModelFileManager.modelsDirectory.appendingPathComponent(downloadedModelFileName)
    if ModelFileManager.isFileReachableAtURL(fileURL: fileURL) {
      return fileURL
    } else {
      return nil
    }
  }

  func getLocalModel(name : String) -> CustomModel {

  }


  func getURLString(url: String) -> URL? {
    return URL(string: url)
  }
  
  func startDownload(with url: URL) {

    let urlSession = URLSession(configuration: .default,
                                delegate: self,
                                delegateQueue: nil)
    
    let downloadTask = urlSession.downloadTask(with: url)
    downloadTask.resume()
  }

  /// Check if the hash of local model at URL matches model hash.
  func isModelValid(at url: URL, model: CustomModel) -> Bool {
    if (generateHash(for: url) == model.hash) {
      return true
    }
  }

  /// Network call to fill out model info.
  func getModelInfo(from consoleURLString : String) {
    let urlSession = URLSession(configuration: .default,
                                delegate: self,
                                delegateQueue: nil)

    let downloadTask = urlSession.downloadTask(with: url)
    downloadTask.resume()
  }

  func generateHash(for url: URL) -> String {
  }
}

extension Downloader {
  func savePendingModelInfo(model : CustomModel) {
    userDefaults.set(model.hash, forKey:(Downloader.modelDownloadingKeyPrefix + ModelInfoRetriever.userDefaultsPendingHashName))
  }

  func saveDownloadedModelInfo(model : CustomModel) {
    userDefaults.set(model.hash, forKey:(Downloader.modelDownloadingKeyPrefix + ModelInfoRetriever.userDefaultsDownloadedHashName))
  }
}

extension Downloader : URLSessionDownloadDelegate {
  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didFinishDownloadingTo location: URL) {
    
    do {
      let documentsURL = try FileManager.default.url(for: .documentDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: false)
      let savedURL = documentsURL.appendingPathComponent(
        location.lastPathComponent)
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
    }
  }
}
