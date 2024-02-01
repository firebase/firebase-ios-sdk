// Copyright 2022 Google LLC
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

#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

/**
 * `StorageDownloadTask` implements resumable downloads from an object in Firebase Storage.
 *
 * Downloads can be returned on completion with a completion handler, and can be monitored
 * by attaching observers, or controlled by calling `pause()`, `resume()`,
 * or `cancel()`.
 *
 * Downloads can currently be returned as `Data` in memory, or as a `URL` to a file on disk.
 *
 * Downloads are performed on a background queue, and callbacks are raised on the developer
 * specified `callbackQueue` in Storage, or the main queue if left unspecified.
 */
@objc(FIRStorageDownloadTask)
open class StorageDownloadTask: StorageObservableTask, StorageTaskManagement {
  /**
   * Prepares a task and begins execution.
   */
  @objc open func enqueue() {
    enqueueImplementation()
  }

  /**
   * Pauses a task currently in progress. Calling this on a paused task has no effect.
   */
  @objc open func pause() {
    dispatchQueue.async { [weak self] in
      guard let self = self else { return }
      if self.state == .paused || self.state == .pausing {
        return
      }
      self.state = .pausing
      // Use the resume callback to confirm pause status since it always runs after the last
      // NSURLSession update.
      self.fetcher?.resumeDataBlock = { [weak self] (data: Data) in
        guard let self = self else { return }
        self.downloadData = data
        self.state = .paused
        self.fire(for: .pause, snapshot: self.snapshot)
      }
      self.fetcher?.stopFetching()
    }
  }

  /**
   * Cancels a task.
   */
  @objc open func cancel() {
    let error = StorageErrorCode.error(withCode: .cancelled)
    cancel(withError: error)
  }

  /**
   * Resumes a paused task. Calling this on a running task has no effect.
   */
  @objc open func resume() {
    dispatchQueue.async { [weak self] in
      guard let self = self else { return }
      self.state = .resuming
      self.fire(for: .resume, snapshot: self.snapshot)
      self.state = .running
      self.enqueueImplementation(resumeWith: self.downloadData)
    }
  }

  private var fetcher: GTMSessionFetcher?
  private var fetcherCompletion: ((Data?, NSError?) -> Void)?
  var downloadData: Data?
  // Hold completion in object to force it to be retained until completion block is called.
  var completionData: ((Data?, Error?) -> Void)?
  var completionURL: ((URL?, Error?) -> Void)?

  // MARK: - Internal Implementations

  override init(reference: StorageReference,
                service: GTMSessionFetcherService,
                queue: DispatchQueue,
                file: URL?) {
    super.init(reference: reference, service: service, queue: queue, file: file)
  }

  deinit {
    self.fetcher?.stopFetching()
  }

  func enqueueImplementation(resumeWith resumeData: Data? = nil) {
    dispatchQueue.async { [weak self] in
      guard let self = self else { return }
      self.state = .queueing
      var request = self.baseRequest
      request.httpMethod = "GET"
      request.timeoutInterval = self.reference.storage.maxDownloadRetryTime
      var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
      components?.query = "alt=media"
      request.url = components?.url

      var fetcher: GTMSessionFetcher
      if let resumeData = resumeData {
        fetcher = GTMSessionFetcher(downloadResumeData: resumeData)
        fetcher.comment = "Resuming DownloadTask"
      } else {
        fetcher = self.fetcherService.fetcher(with: request)
        fetcher.comment = "Starting DownloadTask"
      }
      fetcher.maxRetryInterval = self.reference.storage.maxDownloadRetryInterval

      if let fileURL = self.fileURL {
        // Handle file downloads
        fetcher.destinationFileURL = fileURL
        fetcher.downloadProgressBlock = { [weak self] (bytesWritten: Int64,
                                                       totalBytesWritten: Int64,
                                                       totalBytesExpectedToWrite: Int64) in
            guard let self = self else { return }
            self.state = .progress
            self.progress.completedUnitCount = totalBytesWritten
            self.progress.totalUnitCount = totalBytesExpectedToWrite
            self.fire(for: .progress, snapshot: self.snapshot)
            self.state = .running
        }
      } else {
        // Handle data downloads
        fetcher.receivedProgressBlock = { [weak self] (bytesWritten: Int64,
                                                       totalBytesWritten: Int64) in
            guard let self = self else { return }
            self.state = .progress
            self.progress.completedUnitCount = totalBytesWritten
            if let totalLength = self.fetcher?.response?.expectedContentLength {
              self.progress.totalUnitCount = totalLength
            }
            self.fire(for: .progress, snapshot: self.snapshot)
            self.state = .running
        }
      }
      self.fetcher = fetcher

      // Capture self here to retain until completion.
      self.fetcherCompletion = { [self] (data: Data?, error: NSError?) in
        defer {
          self.removeAllObservers()
          self.fetcherCompletion = nil
        }
        self.fire(for: .progress, snapshot: self.snapshot)

        // Handle potential issues with download
        if let error = error {
          self.state = .failed
          self.error = StorageErrorCode.error(withServerError: error, ref: self.reference)
          self.fire(for: .failure, snapshot: self.snapshot)
          return
        }
        // Download completed successfully, fire completion callbacks
        self.state = .success
        if let data = data {
          self.downloadData = data
        }
        self.fire(for: .success, snapshot: self.snapshot)
      }
      self.state = .running
      self.fetcher?.beginFetch { [self] data, error in
        self.fetcherCompletion?(data, error as? NSError)
      }
    }
  }

  func cancel(withError error: NSError) {
    dispatchQueue.async { [weak self] in
      guard let self = self else { return }
      self.state = .cancelled
      self.fetcher?.stopFetching()
      self.error = error
      self.fire(for: .failure, snapshot: self.snapshot)
    }
  }
}
