//
//  DownloadUtils.swift
//  FirebaseMLModelDownloader
//
//  Created by Manjana Chandrasekharan on 10/18/20.
//

import Foundation

enum DownloadStatus {
  case notStarted
  case inProgress
  case completed
  case failed
}

class Downloader : NSObject, URLSessionDownloadDelegate {

  var progress: Float = 0
  var downloadTask: URLSessionDownloadTask?
  var downloadStatus: DownloadStatus = .notStarted

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
      self.progress = calculatedProgress
    }
  }

  func startDownload(with url: URL) {

    let urlSession = URLSession(configuration: .default,
                                delegate: self,
                                delegateQueue: nil)

    let downloadTask = urlSession.downloadTask(with: url)
    downloadTask.resume()
    self.downloadTask = downloadTask
  }
}
