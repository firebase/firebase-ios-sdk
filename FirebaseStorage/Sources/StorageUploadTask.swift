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
  internal import GoogleUtilities
#else
  internal import GoogleUtilities_Environment
#endif // COCOAPODS

#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

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
  StorageTaskManagement {
  /**
   * Prepares a task and begins execution.
   */
  @objc open func enqueue() {
    // Capturing self so that the upload is done whether or not there is a callback.
    dispatchQueue.async { [self] in
      let shouldReturn = stateLock.withLock { () -> Bool in
        if let contentValidationError = self.contentUploadError() {
          self.error = contentValidationError
          return true
        }
        self.state = .queueing
        return false
      }
      if shouldReturn {
        self.finishTaskWithStatus(status: .failure, snapshot: self.snapshot)
        return
      }

      let dataRepresentation = self.uploadMetadata.dictionaryRepresentation()
      let bodyData = try? JSONSerialization.data(withJSONObject: dataRepresentation)

      Task {
        let fetcherService = await StorageFetcherService.shared.service(reference.storage)
        var request = self.baseRequest
        request.httpMethod = "POST"
        request.timeoutInterval = self.reference.storage.maxUploadRetryTime
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
        guard let path = self.GCSEscapedString(self.uploadMetadata.path) else {
          fatalError("Internal error enqueueing a Storage task")
        }
        components?.percentEncodedQuery = "uploadType=resumable&name=\(path)"

        request.url = components?.url

        guard let contentType = self.uploadMetadata.contentType else {
          fatalError("Internal error enqueueing a Storage task")
        }

        let uploadFetcher = GTMSessionUploadFetcher(
          request: request,
          uploadMIMEType: contentType,
          chunkSize: self.reference.storage.uploadChunkSizeBytes,
          fetcherService: fetcherService
        )
        if let uploadData {
          uploadFetcher.uploadData = uploadData
          uploadFetcher.comment = "Data UploadTask"
        } else if let fileURL {
          uploadFetcher.uploadFileURL = fileURL
          uploadFetcher.comment = "File UploadTask"

          if !GULAppEnvironmentUtil.supportsBackgroundURLSessionUploads() {
            uploadFetcher.useBackgroundSession = false
          }
        }
        uploadFetcher.maxRetryInterval = self.reference.storage.maxUploadRetryInterval

        uploadFetcher.sendProgressBlock = { [weak self] (bytesSent: Int64, totalBytesSent: Int64,
                                                         totalBytesExpectedToSend: Int64) in
            guard let self = self else { return }
            let shouldReturn = self.stateLock.withLock { () -> Bool in
              if self.state == .cancelled || self.state == .pausing || self.state == .paused {
                return true
              }
              self.state = .progress
              self.progress.completedUnitCount = totalBytesSent
              self.progress.totalUnitCount = totalBytesExpectedToSend
              self.metadata = self.uploadMetadata
              return false
            }
            if shouldReturn { return }

            self.fire(for: .progress, snapshot: self.snapshot)

            self.stateLock.withLock {
              if self.state == .cancelled || self.state == .pausing || self.state == .paused {
                return
              }
              self.state = .running
            }
        }
        self.uploadFetcher = uploadFetcher

        // Process fetches
        self.stateLock.withLock {
          self.state = .running
        }
        do {
          let data = try await self.uploadFetcher?.beginFetch()
          let isCancelled = self.stateLock.withLock { self.state == .cancelled }
          if isCancelled { return }

          // Fire last progress updates
          self.fire(for: .progress, snapshot: self.snapshot)

          // Upload completed successfully, fire completion callbacks
          let shouldReturn = self.stateLock.withLock { () -> Bool in
            if self.state == .cancelled { return true }
            self.state = .success

            guard let data = data else {
              fatalError("Internal Error: uploadFetcher returned with nil data and no error")
            }

            if let responseDictionary = try? JSONSerialization
              .jsonObject(with: data) as? [String: AnyHashable] {
              let metadata = StorageMetadata(dictionary: responseDictionary)
              metadata.fileType = .file
              self.metadata = metadata
            } else {
              self.error = StorageErrorCode.error(withInvalidRequest: data)
            }
            return false
          }
          if shouldReturn { return }
          self.finishTaskWithStatus(status: .success, snapshot: self.snapshot)
        } catch {
          let isCancelled = self.stateLock.withLock { self.state == .cancelled }
          if isCancelled { return }

          self.fire(for: .progress, snapshot: self.snapshot)

          let shouldReturn = self.stateLock.withLock { () -> Bool in
            if self.state == .cancelled { return true }
            self.state = .failed
            self.error = StorageErrorCode.error(withServerError: error as NSError,
                                                ref: self.reference)
            self.metadata = self.uploadMetadata
            return false
          }
          if shouldReturn { return }

          self.finishTaskWithStatus(status: .failure, snapshot: self.snapshot)
        }
      }
    }
  }

  /**
   * Pauses a task currently in progress.
   */
  @objc open func pause() {
    let shouldReturn = stateLock.withLock { () -> Bool in
      if state == .paused || state == .pausing || state == .success || state == .cancelled || state == .failed {
        return true
      }
      state = .paused
      uploadFetcher?.pauseFetching()
      metadata = uploadMetadata
      return false
    }
    if shouldReturn { return }

    fire(for: .pause, snapshot: snapshot)
  }

  /**
   * Cancels a task.
   */
  @objc open func cancel() {
    let shouldReturn = stateLock.withLock { () -> Bool in
      if state == .cancelled || state == .success || state == .failed {
        return true
      }
      state = .cancelled
      uploadFetcher?.stopFetching()
      metadata = uploadMetadata
      error = StorageErrorCode.error(
        withServerError: StorageErrorCode.cancelled as NSError,
        ref: reference
      )
      return false
    }
    if shouldReturn { return }

    fire(for: .failure, snapshot: snapshot)
    removeAllObservers()
  }

  /**
   * Resumes a paused task.
   */
  @objc open func resume() {
    let shouldReturn1 = stateLock.withLock { () -> Bool in
      if state == .running || state == .resuming || state == .success || state == .cancelled || state == .failed {
        return true
      }
      state = .resuming
      uploadFetcher?.resumeFetching()
      metadata = uploadMetadata
      return false
    }
    if shouldReturn1 { return }

    fire(for: .resume, snapshot: snapshot)

    stateLock.withLock {
      if state == .cancelled || state == .paused || state == .pausing { return }
      state = .running
    }
  }

  private var uploadFetcher: GTMSessionUploadFetcher?
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
    self.uploadFetcher?.stopFetching()
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

extension StorageUploadTask: @unchecked Sendable {}
