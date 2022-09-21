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
 * Downloads can be returned on completion with a completion handler, and can be monitored
 * by attaching observers, or controlled by calling `pause()`, `resume()`,
 * or `cancel()`.
 * Downloads can currently be returned as `Data` in memory, or as a `URL` to a file on disk.
 * Downloads are performed on a background queue, and callbacks are raised on the developer
 * specified `callbackQueue` in Storage, or the main queue if left unspecified.
 * Currently all uploads must be initiated and managed on the main queue.
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
    weak var weakSelf = self
    DispatchQueue.global(qos: .background).async {
      guard let strongSelf = weakSelf else { return }
      if strongSelf.state == .paused || strongSelf.state == .pausing {
        return
      }
      strongSelf.state = .pausing
      // Use the resume callback to confirm pause status since it always runs after the last
      // NSURLSession update.
      strongSelf.fetcher?.resumeDataBlock = { (data: Data) in
        let strongerSelf = weakSelf
        strongerSelf?.downloadData = data
        strongerSelf?.state = .paused
        if let snapshot = strongerSelf?.snapshot {
          strongerSelf?.fire(for: .pause, snapshot: snapshot)
        }
      }
      strongSelf.fetcher?.stopFetching()
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
    weak var weakSelf = self
    DispatchQueue.global(qos: .background).async {
      weakSelf?.state = .resuming
      if let snapshot = weakSelf?.snapshot {
        weakSelf?.fire(for: .resume, snapshot: snapshot)
      }
      weakSelf?.state = .running
      weakSelf?.enqueueImplementation(resumeWith: self.downloadData)
    }
  }

  private var fetcher: GTMSessionFetcher?
  private var fetcherCompletion: ((Data?, NSError?) -> Void)?
  internal var downloadData: Data?

  // MARK: - Internal Implementations

  override internal init(reference: StorageReference,
                         service: GTMSessionFetcherService,
                         queue: DispatchQueue,
                         file: URL?) {
    super.init(reference: reference, service: service, queue: queue, file: file)
  }

  deinit {
    self.fetcher?.stopFetching()
  }

  internal func enqueueImplementation(resumeWith resumeData: Data? = nil) {
    weak var weakSelf = self
    DispatchQueue.global(qos: .background).async {
      guard let strongSelf = weakSelf else { return }
      strongSelf.state = .queueing
      var request = strongSelf.baseRequest
      request.httpMethod = "GET"
      request.timeoutInterval = strongSelf.reference.storage.maxDownloadRetryTime
      var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
      components?.query = "alt=media"
      request.url = components?.url

      var fetcher: GTMSessionFetcher
      if let resumeData = resumeData {
        fetcher = GTMSessionFetcher(downloadResumeData: resumeData)
        fetcher.comment = "Resuming DownloadTask"
      } else {
        fetcher = strongSelf.fetcherService.fetcher(with: request)
        fetcher.comment = "Resuming DownloadTask"
      }
      fetcher.maxRetryInterval = strongSelf.reference.storage.maxDownloadRetryInterval

      if let fileURL = strongSelf.fileURL {
        // Handle file downloads
        fetcher.destinationFileURL = fileURL
        fetcher.downloadProgressBlock = { (bytesWritten: Int64,
                                           totalBytesWritten: Int64,
                                           totalBytesExpectedToWrite: Int64) in
            weakSelf?.state = .progress
            weakSelf?.progress.completedUnitCount = totalBytesWritten
            weakSelf?.progress.totalUnitCount = totalBytesExpectedToWrite
            if let snapshot = weakSelf?.snapshot {
              weakSelf?.fire(for: .progress, snapshot: snapshot)
            }
            weakSelf?.state = .running
        }
      } else {
        // Handle data downloads
        fetcher.receivedProgressBlock = { (bytesWritten: Int64, totalBytesWritten: Int64) in
          weakSelf?.state = .progress
          weakSelf?.progress.completedUnitCount = totalBytesWritten
          if let totalLength = weakSelf?.fetcher?.response?.expectedContentLength {
            weakSelf?.progress.totalUnitCount = totalLength
          }
          if let snapshot = weakSelf?.snapshot {
            weakSelf?.fire(for: .progress, snapshot: snapshot)
          }
          weakSelf?.state = .running
        }
      }
      strongSelf.fetcher = fetcher
      strongSelf.fetcherCompletion = { (data: Data?, error: NSError?) in
        self.fire(for: .progress, snapshot: self.snapshot)

        // Handle potential issues with download
        if let error = error {
          self.state = .failed
          self.error = StorageErrorCode.error(withServerError: error, ref: self.reference)
          self.fire(for: .failure, snapshot: self.snapshot)
          self.removeAllObservers()
          self.fetcherCompletion = nil
          return
        }
        // Download completed successfully, fire completion callbacks
        self.state = .success
        if let data = data {
          self.downloadData = data
        }
        self.fire(for: .success, snapshot: self.snapshot)
        self.removeAllObservers()
        self.fetcherCompletion = nil
      }
      strongSelf.state = .running
      strongSelf.fetcher?.beginFetch { data, error in
        let strongSelf = weakSelf
        if let fetcherCompletion = strongSelf?.fetcherCompletion {
          fetcherCompletion(data, error as? NSError)
        }
      }
    }
  }

  internal func cancel(withError error: NSError) {
    weak var weakSelf = self
    DispatchQueue.global(qos: .background).async {
      weakSelf?.state = .cancelled
      weakSelf?.fetcher?.stopFetching()
      weakSelf?.error = error
      weakSelf?.fire(for: .failure, snapshot: self.snapshot)
    }
  }
}
