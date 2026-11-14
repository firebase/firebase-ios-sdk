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

internal import FirebaseCoreInternal

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
    let generation = stateLock.withLock { () -> UInt64? in
      guard state == .unknown, transfer == nil else { return nil }
      enqueueGeneration &+= 1
      return enqueueGeneration
    }
    guard let generation else { return }
    Task {
      await enqueueImplementation(generation: generation)
    }
  }

  /**
   * Pauses a task currently in progress. Calling this on a paused task has no effect.
   */
  @objc open func pause() {
    var transferToStop: Task<Void, Never>?
    var snapshotToFire: StorageTaskSnapshot?
    stateLock.withLock {
      guard state == .unknown || state == .queueing || state == .resuming || state == .running ||
        state == .progress else {
        return
      }
      if let transfer {
        // The transfer reports the pause once it has stopped. A download to a file then has the
        // data to resume from where it stopped.
        state = .pausing
        transferToStop = transfer.task
      } else {
        state = .paused
        snapshotToFire = snapshotUnderLock()
      }
    }
    if let snapshotToFire {
      fire(for: .pause, snapshot: snapshotToFire)
    }
    transferToStop?.cancel()
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
    var generation: UInt64 = 0
    let shouldReturn1 = stateLock.withLock { () -> Bool in
      guard state == .unknown || state == .queueing || state == .pausing || state == .paused else {
        return true
      }
      state = .resuming
      enqueueGeneration &+= 1
      generation = enqueueGeneration
      downloadDataToResume = downloadData
      snapshotToFire = snapshotUnderLock()
      return false
    }
    if shouldReturn1 { return }

    if let snapshotToFire {
      fire(for: .resume, snapshot: snapshotToFire)
    }

    let shouldEnqueue = stateLock.withLock { () -> Bool in
      guard generation == enqueueGeneration else { return false }
      if state == .cancelled || state == .paused || state == .pausing { return false }
      state = .running
      return true
    }

    if shouldEnqueue {
      Task {
        await self.enqueueImplementation(resumeWith: downloadDataToResume, generation: generation)
      }
    }
  }

  /// The task that downloads the object, and the enqueue generation that started it.
  private var transfer: (task: Task<Void, Never>, generation: UInt64)?
  private var enqueueGeneration: UInt64 = 0
  var hasTransferForTesting: Bool {
    stateLock.withLock { transfer != nil }
  }

  /// The downloaded data after a download to memory succeeds, or, while a download to a file is
  /// paused, the data to resume it.
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
    self.transfer?.task.cancel()
  }

  private func enqueueImplementation(resumeWith resumeData: Data? = nil,
                                     generation: UInt64) async {
    let shouldProceed = stateLock.withLock { () -> Bool in
      guard generation == enqueueGeneration else { return false }
      guard state == .unknown || state == .queueing || state == .resuming || state == .running ||
        state == .progress else {
        return false
      }
      state = .queueing
      return true
    }
    if !shouldProceed {
      notifySetupDiscardedForTesting()
      return
    }

    var request = baseRequest
    request.httpMethod = "GET"
    request.timeoutInterval = reference.storage.maxDownloadRetryTime
    var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
    components?.query = "alt=media"
    request.url = components?.url

    if resumeData == nil {
      await StorageHTTPService.shared.waitForSetup()
      guard stateLock.withLock({ generation == enqueueGeneration }) else {
        notifySetupDiscardedForTesting()
        return
      }
    }

    let shouldContinue = stateLock.withLock { () -> Bool in
      guard generation == enqueueGeneration else { return false }
      if state == .cancelled || state == .pausing || state == .paused {
        return false
      }
      let task = Task { [request] in
        await self.run(request, resumeData: resumeData, generation: generation)
      }
      transfer = (task, generation)
      state = .running
      return true
    }
    if !shouldContinue {
      notifySetupDiscardedForTesting()
    }
  }

  /// Downloads the object, and reports the outcome.
  private func run(_ request: URLRequest, resumeData: Data?, generation: UInt64) async {
    let storage = reference.storage
    let progress: @Sendable (HTTPTransferProgress) -> Void = { [weak self] progress in
      self?.transferDidProgress(progress, generation: generation)
    }
    do {
      if let fileURL {
        let downloadedFile = try await StorageHTTPService.shared.download(
          for: request, resumeData: resumeData, storage: storage,
          maxRetryTime: storage.maxDownloadRetryTime, progress: progress
        )
        try Self.moveDownloadedFile(at: downloadedFile, to: fileURL)
        fetchDidSucceed(with: Data(), generation: generation)
      } else {
        let data = try await StorageHTTPService.shared.data(
          for: request, storage: storage, maxRetryTime: storage.maxDownloadRetryTime,
          progress: progress
        )
        fetchDidSucceed(with: data, generation: generation)
      }
    } catch let cancellation as HTTPDownloadCancellation {
      transferDidStop(resumeData: cancellation.resumeData, generation: generation)
    } catch is CancellationError {
      transferDidStop(resumeData: nil, generation: generation)
    } catch {
      fetchDidFail(with: error, generation: generation)
    }
  }

  /// Moves a downloaded file to `destination`, replacing any file there and creating the
  /// destination's directory if needed.
  private static func moveDownloadedFile(at location: URL, to destination: URL) throws {
    let fileManager = FileManager.default
    do {
      try? fileManager.removeItem(at: destination)
      try fileManager.createDirectory(at: destination.deletingLastPathComponent(),
                                      withIntermediateDirectories: true)
      try fileManager.moveItem(at: location, to: destination)
    } catch {
      try? fileManager.removeItem(at: location)
      throw error
    }
  }

  private func transferDidProgress(_ transferProgress: HTTPTransferProgress, generation: UInt64) {
    var snapshotToFire: StorageTaskSnapshot?
    stateLock.withLock {
      guard generation == enqueueGeneration else { return }
      guard state == .unknown || state == .queueing || state == .resuming ||
        state == .running || state == .progress else {
        return
      }
      state = .progress
      progress.completedUnitCount = transferProgress.completedBytes
      progress.totalUnitCount = transferProgress.expectedBytes
      snapshotToFire = snapshotUnderLock()
    }
    if let snapshotToFire {
      fire(for: .progress, snapshot: snapshotToFire)
    }

    stateLock.withLock {
      guard generation == enqueueGeneration else { return }
      guard state == .unknown || state == .queueing || state == .resuming ||
        state == .running || state == .progress else {
        return
      }
      state = .running
    }
  }

  /// Clears `transfer` if it's the transfer that `generation` started. Must be called with
  /// `stateLock` held.
  private func clearTransferUnderLock(generation: UInt64) {
    if transfer?.generation == generation {
      transfer = nil
    }
  }

  /// Completes a pending pause once the transfer has stopped. A download to a file keeps the
  /// data to resume from where it stopped. A download to memory starts over when resumed.
  private func transferDidStop(resumeData: Data?, generation: UInt64) {
    var snapshotToFire: StorageTaskSnapshot?
    stateLock.withLock {
      clearTransferUnderLock(generation: generation)
      guard state == .pausing, transfer == nil else { return }
      downloadData = resumeData
      state = .paused
      snapshotToFire = snapshotUnderLock()
    }
    if let snapshotToFire {
      fire(for: .pause, snapshot: snapshotToFire)
    }
  }

  private func fetchDidSucceed(with data: Data, generation: UInt64) {
    var progressSnapshot: StorageTaskSnapshot?
    var successSnapshot: StorageTaskSnapshot?

    stateLock.withLock {
      clearTransferUnderLock(generation: generation)
      guard generation == enqueueGeneration else { return }
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
  }

  private func fetchDidFail(with error: Error, generation: UInt64) {
    if stateLock.withLock({ state == .pausing }) {
      // The download failed as it was being paused. Complete the pause.
      transferDidStop(resumeData: nil, generation: generation)
      return
    }

    var progressSnapshot: StorageTaskSnapshot?
    var failureSnapshot: StorageTaskSnapshot?

    stateLock.withLock {
      clearTransferUnderLock(generation: generation)
      guard generation == enqueueGeneration else { return }
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

  func cancel(withError error: NSError) {
    var transferToStop: Task<Void, Never>?
    var failureSnapshot: StorageTaskSnapshot?
    stateLock.withLock {
      if state == .cancelled || state == .success || state == .failed {
        return
      }
      state = .cancelled
      self.error = error
      transferToStop = transfer?.task
      failureSnapshot = snapshotUnderLock()
    }
    if let failureSnapshot {
      transferToStop?.cancel()
      fire(for: .failure, snapshot: failureSnapshot)
      removeAllObservers()
    }
  }
}
