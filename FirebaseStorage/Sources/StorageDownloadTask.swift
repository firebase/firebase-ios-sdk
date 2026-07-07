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
open class StorageDownloadTask: StorageObservableTask, StorageTaskManagement, @unchecked Sendable {
  /**
   * Prepares a task and begins execution.
   */
  @objc open func enqueue() {
    Task {
      await enqueueImplementation()
    }
  }

  /**
   * Pauses a task currently in progress. Calling this on a paused task has no effect.
   */
  @objc open func pause() {
    var fetcherToStop: GTMSessionFetcher?
    var snapshotToFire: StorageTaskSnapshot?
    stateLock.withLock {
      if state == .paused || state == .pausing || state == .success || state == .cancelled ||
        state == .failed {
        return
      }
      if let fetcher {
        state = .pausing
        // Use the resume callback to confirm pause status since it always runs after the last
        // NSURLSession update.
        fetcher.resumeDataBlock = { [weak self] (data: Data) in
          guard let self = self else { return }
          var snapshotToFire: StorageTaskSnapshot?
          self.stateLock.withLock {
            if self.state == .pausing {
              self.downloadData = data
              self.state = .paused
              snapshotToFire = self.snapshotUnderLock()
            }
          }
          if let snapshotToFire {
            self.fire(for: .pause, snapshot: snapshotToFire)
          }
        }
        fetcherToStop = fetcher
      } else {
        state = .paused
        snapshotToFire = snapshotUnderLock()
      }
    }
    if let snapshotToFire {
      fire(for: .pause, snapshot: snapshotToFire)
    }
    fetcherToStop?.stopFetching()
  }

  /**
   * Cancels a task.
   */
  @objc open func cancel() {
    cancel(withError: StorageError.cancelled as NSError)
  }

  /**
   * Resumes a paused task. Calling this on a running task has no effect.
   */
  @objc open func resume() {
    var downloadDataToResume: Data?
    var snapshotToFire: StorageTaskSnapshot?
    let shouldReturn1 = stateLock.withLock { () -> Bool in
      if state == .running || state == .resuming || state == .success || state == .cancelled ||
        state == .failed {
        return true
      }
      state = .resuming
      downloadDataToResume = downloadData
      snapshotToFire = snapshotUnderLock()
      return false
    }
    if shouldReturn1 { return }

    if let snapshotToFire {
      fire(for: .resume, snapshot: snapshotToFire)
    }

    let shouldEnqueue = stateLock.withLock { () -> Bool in
      if state == .cancelled || state == .paused || state == .pausing { return false }
      state = .running
      return true
    }

    if shouldEnqueue {
      Task {
        await self.enqueueImplementation(resumeWith: downloadDataToResume)
      }
    }
  }

  private var fetcher: GTMSessionFetcher?
  var downloadData: Data?
  // Hold completion in object to force it to be retained until completion block is called.
  var completionData: ((Data?, Error?) -> Void)?
  var completionURL: ((URL?, Error?) -> Void)?

  // MARK: - Internal Implementations

  override init(reference: StorageReference,
                queue: DispatchQueue,
                file: URL?) {
    super.init(reference: reference, queue: queue, file: file)
  }

  deinit {
    self.fetcher?.stopFetching()
  }

  private func enqueueImplementation(resumeWith resumeData: Data? = nil) async {
    let shouldProceed = stateLock.withLock { () -> Bool in
      if state == .cancelled || state == .pausing || state == .paused || state == .success ||
        state == .failed {
        return false
      }
      state = .queueing
      return true
    }
    if !shouldProceed { return }

    var request = baseRequest
    request.httpMethod = "GET"
    request.timeoutInterval = reference.storage.maxDownloadRetryTime
    var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
    components?.query = "alt=media"
    request.url = components?.url

    var fetcher: GTMSessionFetcher
    if let resumeData {
      fetcher = GTMSessionFetcher(downloadResumeData: resumeData)
      fetcher.comment = "Resuming DownloadTask"
    } else {
      let fetcherService = await StorageFetcherService.shared.service(reference.storage)

      fetcher = fetcherService.fetcher(with: request)
      fetcher.comment = "Starting DownloadTask"
    }
    fetcher.maxRetryInterval = reference.storage.maxDownloadRetryInterval

    if let fileURL {
      // Handle file downloads
      fetcher.destinationFileURL = fileURL
      fetcher.downloadProgressBlock = { [weak self] (bytesWritten: Int64,
                                                     totalBytesWritten: Int64,
                                                     totalBytesExpectedToWrite: Int64) in
          guard let self = self else { return }
          var snapshotToFire: StorageTaskSnapshot?
          self.stateLock.withLock {
            if self.state == .cancelled || self.state == .pausing || self.state == .paused ||
              self.state == .success || self.state == .failed {
              return
            }
            self.state = .progress
            self.progress.completedUnitCount = totalBytesWritten
            self.progress.totalUnitCount = totalBytesExpectedToWrite
            snapshotToFire = self.snapshotUnderLock()
          }
          if let snapshotToFire {
            self.fire(for: .progress, snapshot: snapshotToFire)
          }

          self.stateLock.withLock {
            if self.state == .cancelled || self.state == .pausing || self.state == .paused ||
              self.state == .success || self.state == .failed {
              return
            }
            self.state = .running
          }
      }
    } else {
      // Handle data downloads
      fetcher.receivedProgressBlock = { [weak self] (bytesWritten: Int64,
                                                     totalBytesWritten: Int64) in
          guard let self = self else { return }
          var snapshotToFire: StorageTaskSnapshot?
          self.stateLock.withLock {
            if self.state == .cancelled || self.state == .pausing || self.state == .paused ||
              self.state == .success || self.state == .failed {
              return
            }
            self.state = .progress
            self.progress.completedUnitCount = totalBytesWritten
            if let totalLength = self.fetcher?.response?.expectedContentLength {
              self.progress.totalUnitCount = totalLength
            }
            snapshotToFire = self.snapshotUnderLock()
          }
          if let snapshotToFire {
            self.fire(for: .progress, snapshot: snapshotToFire)
          }

          self.stateLock.withLock {
            if self.state == .cancelled || self.state == .pausing || self.state == .paused ||
              self.state == .success || self.state == .failed {
              return
            }
            self.state = .running
          }
      }
    }
    var isPausing = false
    let shouldContinue = stateLock.withLock { () -> Bool in
      if state == .cancelled || state == .pausing || state == .paused {
        isPausing = state == .pausing
        return false
      }
      self.fetcher = fetcher
      state = .running
      return true
    }
    if !shouldContinue {
      if isPausing {
        fetcher.resumeDataBlock = { [weak self] (data: Data) in
          guard let self = self else { return }
          var snapshotToFire: StorageTaskSnapshot?
          self.stateLock.withLock {
            if self.state == .pausing {
              self.downloadData = data
              self.state = .paused
              snapshotToFire = self.snapshotUnderLock()
            }
          }
          if let snapshotToFire {
            self.fire(for: .pause, snapshot: snapshotToFire)
          }
        }
      }
      fetcher.stopFetching()
      return
    }
    do {
      let data = try await fetcher.beginFetch()
      let isCancelled = stateLock.withLock { state == .cancelled }
      if isCancelled { return }

      var progressSnapshot: StorageTaskSnapshot?
      var successSnapshot: StorageTaskSnapshot?

      stateLock.withLock {
        if state == .cancelled { return }

        state = .progress
        progressSnapshot = snapshotUnderLock()

        state = .success
        downloadData = data
        successSnapshot = snapshotUnderLock()
      }

      if let progressSnapshot {
        fire(for: .progress, snapshot: progressSnapshot)
      }
      if let successSnapshot {
        fire(for: .success, snapshot: successSnapshot)
        removeAllObservers()
      }
    } catch {
      var progressSnapshot: StorageTaskSnapshot?
      var failureSnapshot: StorageTaskSnapshot?

      stateLock.withLock {
        if state == .cancelled || state == .paused || state == .pausing { return }

        state = .progress
        progressSnapshot = snapshotUnderLock()

        state = .failed
        self.error = StorageErrorCode.error(
          withServerError: error as NSError,
          ref: reference
        )
        failureSnapshot = snapshotUnderLock()
      }

      if let progressSnapshot {
        fire(for: .progress, snapshot: progressSnapshot)
      }
      if let failureSnapshot {
        fire(for: .failure, snapshot: failureSnapshot)
        removeAllObservers()
      }
    }
  }

  func cancel(withError error: NSError) {
    var fetcherToStop: GTMSessionFetcher?
    var failureSnapshot: StorageTaskSnapshot?
    stateLock.withLock {
      if state == .cancelled || state == .success || state == .failed {
        return
      }
      state = .cancelled
      self.error = error
      fetcherToStop = fetcher
      failureSnapshot = snapshotUnderLock()
    }
    if let failureSnapshot {
      fetcherToStop?.stopFetching()
      fire(for: .failure, snapshot: failureSnapshot)
      removeAllObservers()
    }
  }
}
