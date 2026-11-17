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

@_spi(FirebaseNetworking) internal import FirebaseCoreInternal

#if COCOAPODS
  internal import GoogleUtilities
#else
  internal import GoogleUtilities_Environment
#endif // COCOAPODS

/**
 * `StorageUploadTask` implements resumable uploads to a file in Firebase Storage.
 *
 * Uploads can be returned on completion with a completion callback, and can be monitored
 * by attaching observers, or controlled by calling `pause()`, `resume()`,
 * or `cancel()`.
 *
 * Uploads can be initialized from `Data` in memory, or a URL to a file on disk.
 *
 * Uploads are performed on a background queue, and callbacks are raised on the developer
 * specified `callbackQueue` in Storage, or the main queue if unspecified.
 */
@objc(FIRStorageUploadTask) open class StorageUploadTask: StorageObservableTask,
  StorageTaskManagement, @unchecked Sendable {
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
    enqueueImplementation(generation: generation)
  }

  private func enqueueImplementation(generation: UInt64) {
    // Capturing self so that the upload is done whether or not there is a callback.
    dispatchQueue.async { [self] in
      let contentValidationError = self.contentUploadError()
      var failureSnapshot: StorageTaskSnapshot?
      let shouldProceed = stateLock.withLock { () -> Bool in
        guard generation == enqueueGeneration else { return false }
        guard state == .unknown || state == .queueing || state == .resuming || state == .running ||
          state == .progress else {
          return false
        }
        if let contentValidationError {
          self.error = contentValidationError
          self.state = .failed
          failureSnapshot = self.snapshotUnderLock()
          return false
        }
        self.state = .queueing
        return true
      }
      if !shouldProceed {
        if let failureSnapshot {
          self.finishTaskWithStatus(status: .failure, snapshot: failureSnapshot)
        } else {
          notifySetupDiscardedForTesting()
        }
        return
      }

      let upload = self.makeUpload()
      Task {
        await StorageHTTPService.shared.waitForSetup()
        self.startTransfer(of: upload, generation: generation)
      }
    }
  }

  /**
   * Pauses a task currently in progress.
   */
  @objc open func pause() {
    var transferToStop: Task<Void, Never>?
    var pauseSnapshot: StorageTaskSnapshot?
    stateLock.withLock {
      guard state == .unknown || state == .queueing || state == .resuming || state == .running ||
        state == .progress else {
        return
      }
      // The upload session stays open, so a resumed upload continues from the bytes that the
      // server has received.
      state = .paused
      metadata = uploadMetadata
      transferToStop = transfer?.task
      pauseSnapshot = snapshotUnderLock()
    }
    if let pauseSnapshot {
      transferToStop?.cancel()
      fire(for: .pause, snapshot: pauseSnapshot)
    }
  }

  /**
   * Cancels a task.
   */
  @objc open func cancel() {
    var transferToStop: Task<Void, Never>?
    var sessionToCancel: StorageResumableUpload.Session?
    var failureSnapshot: StorageTaskSnapshot?
    stateLock.withLock {
      if state == .cancelled || state == .success || state == .failed {
        return
      }
      state = .cancelled
      metadata = uploadMetadata
      error = StorageError.cancelled as NSError
      transferToStop = transfer?.task
      sessionToCancel = uploadSession
      uploadSession = nil
      failureSnapshot = snapshotUnderLock()
    }
    if let failureSnapshot {
      transferToStop?.cancel()
      if let sessionToCancel {
        cancelOnServer(sessionToCancel)
      }
      fire(for: .failure, snapshot: failureSnapshot)
      removeAllObservers()
    }
  }

  /**
   * Resumes a paused task.
   */
  @objc open func resume() {
    var generation: UInt64 = 0
    var resumeSnapshot: StorageTaskSnapshot?
    let shouldResume = stateLock.withLock { () -> Bool in
      guard state == .unknown || state == .queueing || state == .pausing || state == .paused else {
        return false
      }
      state = .resuming
      metadata = uploadMetadata
      // A new generation ignores late callbacks of the stopped transfer.
      enqueueGeneration &+= 1
      generation = enqueueGeneration
      resumeSnapshot = snapshotUnderLock()
      return true
    }
    if !shouldResume { return }

    if let resumeSnapshot {
      fire(for: .resume, snapshot: resumeSnapshot)
    }

    let shouldProceed = stateLock.withLock { () -> Bool in
      guard generation == enqueueGeneration else { return false }
      if state == .cancelled || state == .paused || state == .pausing { return false }
      state = .running
      return true
    }

    if shouldProceed {
      enqueueImplementation(generation: generation)
    }
  }

  /// The task that runs the upload, and the enqueue generation that started it.
  private var transfer: (task: Task<Void, Never>, generation: UInt64)?
  private var enqueueGeneration: UInt64 = 0
  var hasTransferForTesting: Bool {
    stateLock.withLock { transfer != nil }
  }

  /// The open upload session, which a resumed upload continues.
  private var uploadSession: StorageResumableUpload.Session?

  private var uploadMetadata: StorageMetadata
  private var uploadData: Data?
  // Hold completion in object to force it to be retained until completion block is called.
  var completionMetadata: ((StorageMetadata?, Error?) -> Void)?

  // MARK: - Internal Implementations

  init(reference: StorageReference,
       queue: DispatchQueue,
       file: URL? = nil,
       data: Data? = nil,
       metadata: StorageMetadata) {
    uploadMetadata = metadata
    uploadData = data
    super.init(reference: reference, queue: queue, file: file)

    if uploadMetadata.contentType == nil {
      uploadMetadata.contentType = StorageUtils.MIMETypeForExtension(file?.pathExtension)
    }
  }

  deinit {
    self.transfer?.task.cancel()
    // A paused upload that is released can't be resumed, so close its session.
    if let uploadSession {
      let storage = reference.storage
      Task {
        await StorageResumableUpload.cancel(uploadSession, storage: storage)
      }
    }
  }

  private func contentUploadError() -> NSError? {
    if uploadData != nil {
      return nil
    }
    if let resourceValues = try? fileURL?.resourceValues(forKeys: [.isRegularFileKey]),
       let isFile = resourceValues.isRegularFile,
       isFile == true {
      return nil
    }
    return StorageError.unknown(message: "File at URL: \(fileURL?.absoluteString ?? "") is " +
      "not reachable. Ensure file URL is not " +
      "a directory, symbolic link, or invalid url.",
      serverError: [:]) as NSError
  }

  func finishTaskWithStatus(status: StorageTaskStatus, snapshot: StorageTaskSnapshot) {
    fire(for: status, snapshot: snapshot)
    removeAllObservers()
  }

  /// Returns the upload of the task's data or file, with the request that opens its session.
  private func makeUpload() -> StorageResumableUpload {
    let storage = reference.storage
    let dataRepresentation = uploadMetadata.dictionaryRepresentation()
    let bodyData = try? JSONSerialization.data(withJSONObject: dataRepresentation)

    var request = baseRequest
    request.httpMethod = "POST"
    request.timeoutInterval = storage.maxUploadRetryTime
    request.httpBody = bodyData
    request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
    if let count = bodyData?.count {
      request.setValue("\(count)", forHTTPHeaderField: "Content-Length")
    }

    var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
    if components?.host == "www.googleapis.com",
       let path = components?.path {
      components?.percentEncodedPath = "/upload\(path)"
    }
    guard let path = GCSEscapedString(uploadMetadata.path) else {
      fatalError("Internal error enqueueing a Storage task")
    }
    components?.percentEncodedQuery = "uploadType=resumable&name=\(path)"

    request.url = components?.url

    guard let contentType = uploadMetadata.contentType else {
      fatalError("Internal error enqueueing a Storage task")
    }

    let source: StorageResumableUpload.Source
    let length: Int64
    var usesBackgroundSession = false
    if let uploadData {
      source = .data(uploadData)
      length = Int64(uploadData.count)
    } else if let fileURL {
      source = .file(fileURL)
      let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
      length = Int64(fileSize ?? 0)
      // File uploads continue while the app is suspended where background sessions support
      // uploads. Simulators don't use them.
      #if !targetEnvironment(simulator)
        usesBackgroundSession = GULAppEnvironmentUtil.supportsBackgroundURLSessionUploads()
      #endif
    } else {
      fatalError("Internal error enqueueing a Storage task")
    }

    return StorageResumableUpload(
      startRequest: request,
      source: source,
      length: length,
      contentType: contentType,
      chunkSize: storage.uploadChunkSizeBytes,
      storage: storage,
      usesBackgroundSession: usesBackgroundSession
    )
  }

  /// Starts the transfer of `upload`, unless the task was paused, cancelled, or enqueued again
  /// since `generation` began.
  private func startTransfer(of upload: StorageResumableUpload, generation: UInt64) {
    let shouldContinue = stateLock.withLock { () -> Bool in
      guard generation == enqueueGeneration else { return false }
      if state == .cancelled || state == .pausing || state == .paused {
        return false
      }
      let session = uploadSession
      let task = Task {
        await self.run(upload, resuming: session, generation: generation)
      }
      transfer = (task, generation)
      state = .running
      return true
    }
    if !shouldContinue {
      notifySetupDiscardedForTesting()
    }
  }

  /// Uploads the data or file, and reports the outcome.
  private func run(_ upload: StorageResumableUpload,
                   resuming session: StorageResumableUpload.Session?,
                   generation: UInt64) async {
    do {
      let data = try await upload.run(
        resuming: session,
        didOpenSession: { session in
          self.sessionDidOpen(session, generation: generation)
        },
        progress: { [weak self] progress in
          self?.transferDidProgress(progress, generation: generation)
        }
      )
      fetchDidSucceed(with: data, generation: generation)
    } catch is CancellationError {
      transferDidStop(generation: generation)
    } catch {
      fetchDidFail(with: error, generation: generation)
    }
  }

  /// Keeps the session that the transfer of `generation` opened, so a resumed upload continues
  /// it.
  private func sessionDidOpen(_ session: StorageResumableUpload.Session, generation: UInt64) {
    let isCurrent = stateLock.withLock { () -> Bool in
      guard generation == enqueueGeneration, state != .cancelled else { return false }
      uploadSession = session
      return true
    }
    if !isCurrent {
      // The task was cancelled, or resumed with a new session, while this one opened.
      cancelOnServer(session)
    }
  }

  /// Sends the `cancel` command for `session` without waiting for the response.
  private func cancelOnServer(_ session: StorageResumableUpload.Session) {
    let storage = reference.storage
    Task {
      await StorageResumableUpload.cancel(session, storage: storage)
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
      metadata = uploadMetadata
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

  /// Clears the transfer after a pause or cancellation stopped it. `pause()` and `cancel()`
  /// already reported the change.
  private func transferDidStop(generation: UInt64) {
    stateLock.withLock {
      clearTransferUnderLock(generation: generation)
    }
  }

  private func fetchDidSucceed(with data: Data, generation: UInt64) {
    var progressSnapshot: StorageTaskSnapshot?
    var successSnapshot: StorageTaskSnapshot?
    var failureSnapshot: StorageTaskSnapshot?

    stateLock.withLock {
      clearTransferUnderLock(generation: generation)
      guard generation == enqueueGeneration else { return }
      // The upload is finished, so there's no session to continue or cancel.
      uploadSession = nil
      if state == .cancelled { return }

      state = .progress
      progressSnapshot = snapshotUnderLock()

      if let responseDictionary = try? JSONSerialization
        .jsonObject(with: data) as? [String: AnyHashable] {
        state = .success
        let metadata = StorageMetadata(dictionary: responseDictionary)
        metadata.fileType = .file
        self.metadata = metadata
        successSnapshot = snapshotUnderLock()
      } else {
        state = .failed
        error = StorageErrorCode.error(withInvalidRequest: data)
        failureSnapshot = snapshotUnderLock()
      }
    }

    if let progressSnapshot {
      fire(for: .progress, snapshot: progressSnapshot)
    }
    if let successSnapshot {
      finishTaskWithStatus(status: .success, snapshot: successSnapshot)
    } else if let failureSnapshot {
      finishTaskWithStatus(status: .failure, snapshot: failureSnapshot)
    }
  }

  private func fetchDidFail(with error: Error, generation: UInt64) {
    var progressSnapshot: StorageTaskSnapshot?
    var failureSnapshot: StorageTaskSnapshot?
    var sessionToCancel: StorageResumableUpload.Session?

    stateLock.withLock {
      clearTransferUnderLock(generation: generation)
      guard generation == enqueueGeneration else { return }
      if state == .cancelled || state == .paused || state == .pausing { return }

      // The upload can't continue, so close its session.
      sessionToCancel = uploadSession
      uploadSession = nil

      state = .progress
      progressSnapshot = snapshotUnderLock()

      state = .failed
      self.error = StorageErrorCode.error(withServerError: error as NSError, ref: reference)
      metadata = uploadMetadata
      failureSnapshot = snapshotUnderLock()
    }

    if let sessionToCancel {
      cancelOnServer(sessionToCancel)
    }
    if let progressSnapshot {
      fire(for: .progress, snapshot: progressSnapshot)
    }
    if let failureSnapshot {
      finishTaskWithStatus(status: .failure, snapshot: failureSnapshot)
    }
  }

  private func GCSEscapedString(_ input: String?) -> String? {
    guard let input = input else {
      return nil
    }
    let GCSObjectAllowedCharacterSet =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~!$'()*,=:@"
    let allowedCharacters = CharacterSet(charactersIn: GCSObjectAllowedCharacterSet)
    return input.addingPercentEncoding(withAllowedCharacters: allowedCharacters)
  }
}
