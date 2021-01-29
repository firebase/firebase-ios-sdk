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

enum FileDownloaderError: Error {
  case unexpectedResponseType
  case networkError(Error)
  case anotherDownloadInProgress
}

struct FileDownloaderResponse {
  var urlResponse: HTTPURLResponse
  var fileURL: URL
}

/// URL Session to use while retrieving model info.
protocol FileDownloader {
  typealias CompletionHandler = (Result<FileDownloaderResponse, Error>) -> Void
  typealias ProgressHandler = (_ bytesWritten: Int64, _ bytesExpectedToWrite: Int64) -> Void

  func downloadFile(with url: URL,
                    progressHandler: @escaping ProgressHandler,
                    completion: @escaping CompletionHandler)
}

/// Downloader to get model files from server.
class ModelFileDownloader: NSObject, FileDownloader {
  /// Model conditions for download.
  private let conditions: ModelDownloadConditions
  /// URL session configuration.
  private let configuration: URLSessionConfiguration
  /// Task to handle model file download.
  private var downloadTask: URLSessionDownloadTask?
  /// URLSession to handle model downloads.
  private lazy var downloadSession: URLSession = URLSession(
    configuration: configuration,
    delegate: self,
    delegateQueue: nil
  )
  /// Successful download completion handler.
  private var completion: FileDownloader.CompletionHandler?
  /// Download progress handler.
  private var progressHandler: FileDownloader.ProgressHandler?

  init(conditions: ModelDownloadConditions) {
    self.conditions = conditions
    configuration = URLSessionConfiguration.ephemeral
    /// Wait for network connectivity, if unavailable.
    if #available(iOS 11.0, macOS 10.13, macCatalyst 13.0, tvOS 11.0, watchOS 4.0, *) {
      self.configuration.waitsForConnectivity = true
      /// Wait for 10 minutes.
      self.configuration.timeoutIntervalForResource = 600
    }
    /// Prevent multiple download calls to the same host.
    configuration.httpMaximumConnectionsPerHost = 1
    configuration.allowsCellularAccess = conditions.allowsCellularAccess
  }

  func downloadFile(with url: URL,
                    progressHandler: @escaping (Int64, Int64) -> Void,
                    completion: @escaping (Result<FileDownloaderResponse, Error>) -> Void) {
    self.completion = completion
    self.progressHandler = progressHandler
    let downloadTask = downloadSession.downloadTask(with: url)
    if downloadTask.state == .running {
      completion(.failure(FileDownloaderError.anotherDownloadInProgress))
    }
    downloadTask.resume()
    self.downloadTask = downloadTask
  }
}

/// Extension to handle delegate methods.
extension ModelFileDownloader: URLSessionDownloadDelegate {
  /// Handle client-side errors.
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let error = error else { return }
    session.finishTasksAndInvalidate()
    /// Unable to resolve hostname or connect to host.
    completion?(.failure(FileDownloaderError.networkError(error)))
  }

  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didFinishDownloadingTo location: URL) {
    guard let response = downloadTask.response,
      let urlResponse = response as? HTTPURLResponse else {
      completion?(.failure(FileDownloaderError.unexpectedResponseType))
      return
    }
    let downloaderResponse = FileDownloaderResponse(urlResponse: urlResponse, fileURL: location)
    session.finishTasksAndInvalidate()
    completion?(.success(downloaderResponse))
  }

  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didWriteData bytesWritten: Int64,
                  totalBytesWritten: Int64,
                  totalBytesExpectedToWrite: Int64) {
    progressHandler?(totalBytesWritten, totalBytesExpectedToWrite)
  }
}
