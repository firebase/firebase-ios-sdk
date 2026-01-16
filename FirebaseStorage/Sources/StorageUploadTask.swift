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
 *
 * Uploads support cross-app-restart resumption. Use `snapshot.uploadSessionUri` to get
 * the GCS session URI during an upload, persist it, and pass it to
 * `putFile(from:metadata:existingUploadUri:)` to resume after app restart.
 */
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRStorageUploadTask) open class StorageUploadTask: StorageObservableTask,
  StorageTaskManagement {
  /**
   * Prepares a task and begins execution.
   */
  @objc open func enqueue() {
    // Capturing self so that the upload is done whether or not there is a callback.
    dispatchQueue.async { [self] in
      if let contentValidationError = self.contentUploadError() {
        self.error = contentValidationError
        self.finishTaskWithStatus(status: .failure, snapshot: self.snapshot)
        return
      }

      self.state = .queueing

      Task {
        let fetcherService = await StorageFetcherService.shared.service(reference.storage)

        guard let contentType = self.uploadMetadata.contentType else {
          fatalError("Internal error enqueueing a Storage task")
        }

        let uploadFetcher: GTMSessionUploadFetcher

        if let existingUri = self.existingUploadUri {
          // RESUME: Use existing upload session URI
          do {
            uploadFetcher = try await self.createResumingFetcher(
              sessionUri: existingUri,
              contentType: contentType,
              fetcherService: fetcherService
            )
          } catch {
            self.state = .failed
            self.error = StorageErrorCode.error(withServerError: error as NSError,
                                                ref: self.reference)
            self.metadata = self.uploadMetadata
            self.finishTaskWithStatus(status: .failure, snapshot: self.snapshot)
            return
          }
        } else {
          // NEW UPLOAD: Create fresh session
          let dataRepresentation = self.uploadMetadata.dictionaryRepresentation()
          let bodyData = try? JSONSerialization.data(withJSONObject: dataRepresentation)

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

          uploadFetcher = GTMSessionUploadFetcher(
            request: request,
            uploadMIMEType: contentType,
            chunkSize: self.reference.storage.uploadChunkSizeBytes,
            fetcherService: fetcherService
          )
        }

        // Configure the fetcher with upload data or file
        if let uploadData {
          uploadFetcher.uploadData = uploadData
          uploadFetcher.comment = "Data UploadTask"
        } else if let fileURL {
          uploadFetcher.uploadFileURL = fileURL
          uploadFetcher.comment = self.existingUploadUri != nil ? "Resumed File UploadTask" : "File UploadTask"

          // Disable background sessions to enable retry-based offset querying.
          // Background sessions handle network loss by pausing/waiting internally,
          // which bypasses the retry path that queries the server for upload offset.
          // Without this, network interruptions would not trigger the offset query.
          uploadFetcher.useBackgroundSession = false
        }
        uploadFetcher.maxRetryInterval = self.reference.storage.maxUploadRetryInterval

        // Enable retry so that retryBlock is called on errors.
        // The fetcher service has this enabled, but upload fetchers need it explicitly.
        uploadFetcher.isRetryEnabled = true

        // Enable retry for network errors so GTMSessionUploadFetcher queries the server
        // for the upload offset before resuming. Without this, network interruptions
        // would restart the upload from 0% instead of continuing from the last confirmed offset.
        uploadFetcher.retryBlock = { (suggestedWillRetry: Bool,
                                      error: Error?,
                                      response: @escaping GTMSessionFetcherRetryResponse) in
          var shouldRetry = suggestedWillRetry
          // GTMSessionFetcher does not consider being offline a retryable error, but we do.
          // When offline, we want to retry so the upload fetcher will query for the offset.
          if !shouldRetry, let nsError = error as? NSError {
            shouldRetry = nsError.code == URLError.notConnectedToInternet.rawValue ||
                          nsError.code == URLError.networkConnectionLost.rawValue ||
                          nsError.code == URLError.timedOut.rawValue
          }
          response(shouldRetry)
        }

        uploadFetcher.sendProgressBlock = { [weak self] (bytesSent: Int64, totalBytesSent: Int64,
                                                         totalBytesExpectedToSend: Int64) in
            guard let self = self else { return }
            self.state = .progress
            // Add resume offset for resumed uploads - totalBytesSent only counts this session
            let actualCompleted = totalBytesSent + self.resumeByteOffset
            let actualTotal = totalBytesExpectedToSend + self.resumeByteOffset
            self.progress.completedUnitCount = actualCompleted
            self.progress.totalUnitCount = actualTotal
            self.metadata = self.uploadMetadata
            self.fire(for: .progress, snapshot: self.snapshot)
            self.state = .running
        }
        self.uploadFetcher = uploadFetcher

        // Process fetches
        self.state = .running
        do {
          let data = try await self.uploadFetcher?.beginFetch()
          // Fire last progress updates
          self.fire(for: .progress, snapshot: self.snapshot)

          // Upload completed successfully, fire completion callbacks
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
          self.finishTaskWithStatus(status: .success, snapshot: self.snapshot)
        } catch {
          self.fire(for: .progress, snapshot: self.snapshot)
          self.state = .failed
          self.error = StorageErrorCode.error(withServerError: error as NSError,
                                              ref: self.reference)
          self.metadata = self.uploadMetadata
          self.finishTaskWithStatus(status: .failure, snapshot: self.snapshot)
        }
      }
    }
  }

  /**
   * Pauses a task currently in progress.
   */
  @objc open func pause() {
    dispatchQueue.async { [weak self] in
      guard let self = self else { return }
      self.state = .paused
      self.uploadFetcher?.pauseFetching()
      if self.state != .success {
        self.metadata = self.uploadMetadata
      }
      self.fire(for: .pause, snapshot: self.snapshot)
    }
  }

  /**
   * Cancels a task.
   */
  @objc open func cancel() {
    dispatchQueue.async { [weak self] in
      guard let self = self else { return }
      self.state = .cancelled
      self.uploadFetcher?.stopFetching()
      if self.state != .success {
        self.metadata = self.uploadMetadata
      }
      self.error = StorageErrorCode.error(
        withServerError: StorageErrorCode.cancelled as NSError,
        ref: self.reference
      )
      self.fire(for: .failure, snapshot: self.snapshot)
    }
  }

  /**
   * Resumes a paused task.
   */
  @objc open func resume() {
    dispatchQueue.async { [weak self] in
      guard let self = self else { return }
      self.state = .resuming
      self.uploadFetcher?.resumeFetching()
      if self.state != .success {
        self.metadata = self.uploadMetadata
      }
      self.fire(for: .resume, snapshot: self.snapshot)
      self.state = .running
    }
  }

  private var uploadFetcher: GTMSessionUploadFetcher?
  private var uploadMetadata: StorageMetadata
  private var uploadData: Data?
  // Hold completion in object to force it to be retained until completion block is called.
  var completionMetadata: ((StorageMetadata?, Error?) -> Void)?

  /// URI for an existing upload session to resume. If provided, the upload will attempt
  /// to resume from where the previous session left off.
  private var existingUploadUri: URL?

  /// Bytes already uploaded from a previous session (for accurate progress reporting).
  /// GTMSessionUploadFetcher's progress callback reports bytes sent in the current session only,
  /// so we need to add this offset for resumed uploads.
  private var resumeByteOffset: Int64 = 0

  /// The URI for the current upload session. Can be used to resume the upload after app restart.
  /// This URI remains valid for approximately one week after creation.
  /// - Note: This property is only available after the upload has started and the server
  ///   has returned a session URI. Returns `nil` before that point or for data uploads.
  public var uploadSessionUri: URL? {
    return uploadFetcher?.uploadLocationURL
  }

  // MARK: - Internal Implementations

  init(reference: StorageReference,
       queue: DispatchQueue,
       file: URL? = nil,
       data: Data? = nil,
       metadata: StorageMetadata,
       existingUploadUri: URL? = nil) {
    uploadMetadata = metadata
    uploadData = data
    self.existingUploadUri = existingUploadUri
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

  // MARK: - Resumable Upload Support

  /// Creates a GTMSessionUploadFetcher configured to resume an existing upload session.
  ///
  /// This method queries the GCS server for the current upload state, then creates a fetcher
  /// using the location-based initializer which puts GTMSessionUploadFetcher into "resume mode".
  ///
  /// - Parameters:
  ///   - sessionUri: The GCS resumable upload session URI from a previous upload.
  ///   - contentType: The MIME type of the content being uploaded.
  ///   - fetcherService: The fetcher service to use for the upload.
  /// - Returns: A configured GTMSessionUploadFetcher ready to resume the upload.
  private func createResumingFetcher(
    sessionUri: URL,
    contentType: String,
    fetcherService: GTMSessionFetcherService
  ) async throws -> GTMSessionUploadFetcher {
    // Query the server for current upload state
    let bytesUploaded = try await queryUploadStatus(sessionUri: sessionUri)

    // CRITICAL: Use the location-based initializer for resumption.
    // GTMSessionUploadFetcher has two mutually exclusive modes:
    // 1. New upload: init(request:...) - starts a fresh upload session
    // 2. Resume: init(location:...) - continues an existing session
    // Using init(request:) and then setting uploadLocationURL does NOT work -
    // the fetcher will start a new session instead of resuming.
    let uploadFetcher = GTMSessionUploadFetcher(
      location: sessionUri,
      uploadMIMEType: contentType,
      chunkSize: reference.storage.uploadChunkSizeBytes,
      fetcherService: fetcherService
    )

    // Enable retry for network errors so GTMSessionUploadFetcher queries the server
    // for the upload offset before resuming.
    uploadFetcher.retryBlock = { (suggestedWillRetry: Bool,
                                  error: Error?,
                                  response: @escaping GTMSessionFetcherRetryResponse) in
      var shouldRetry = suggestedWillRetry
      if !shouldRetry, let nsError = error as? NSError {
        shouldRetry = nsError.code == URLError.notConnectedToInternet.rawValue ||
                      nsError.code == URLError.networkConnectionLost.rawValue ||
                      nsError.code == URLError.timedOut.rawValue
      }
      response(shouldRetry)
    }

    // Store resume offset for progress calculation.
    // GTMSessionUploadFetcher's progress callback reports bytes sent in this session only.
    self.resumeByteOffset = bytesUploaded

    // Set initial progress based on server's confirmed bytes
    self.progress.completedUnitCount = bytesUploaded

    return uploadFetcher
  }

  /// Queries the GCS server for the current status of an upload session.
  ///
  /// This sends a "query" command to the GCS resumable upload endpoint to determine
  /// how many bytes the server has confirmed receiving.
  ///
  /// - Parameter sessionUri: The GCS resumable upload session URI.
  /// - Returns: The number of bytes the server has confirmed receiving.
  /// - Throws: An error if the session has expired or the query fails.
  private func queryUploadStatus(sessionUri: URL) async throws -> Int64 {
    // Fetch auth tokens first
    let authToken: String? = await withCheckedContinuation { continuation in
      guard let auth = reference.storage.auth else {
        continuation.resume(returning: nil)
        return
      }
      auth.getToken(forcingRefresh: false) { token, _ in
        continuation.resume(returning: token)
      }
    }

    let appCheckToken: String? = await withCheckedContinuation { continuation in
      guard let appCheck = reference.storage.appCheck else {
        continuation.resume(returning: nil)
        return
      }
      appCheck.getToken(forcingRefresh: false) { tokenResult in
        continuation.resume(returning: tokenResult.token)
      }
    }

    // Build the request with tokens
    var request = URLRequest(url: sessionUri)
    request.httpMethod = "POST"
    request.setValue("resumable", forHTTPHeaderField: "X-Goog-Upload-Protocol")
    request.setValue("query", forHTTPHeaderField: "X-Goog-Upload-Command")

    if let authToken = authToken {
      request.setValue("Firebase \(authToken)", forHTTPHeaderField: "Authorization")
    }
    if let appCheckToken = appCheckToken {
      request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
    }

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw StorageError.unknown(
        message: "Invalid response when querying upload status",
        serverError: [:]
      )
    }

    // Check for error status codes
    if httpResponse.statusCode >= 400 {
      let bodyString = String(data: data, encoding: .utf8) ?? ""
      throw StorageError.unknown(
        message: "Upload session query failed with status \(httpResponse.statusCode). " +
                 "The session may have expired. Response: \(bodyString.prefix(200))",
        serverError: ["statusCode": httpResponse.statusCode]
      )
    }

    // Parse X-Goog-Upload-Size-Received header to get confirmed bytes
    if let bytesString = httpResponse.value(forHTTPHeaderField: "X-Goog-Upload-Size-Received"),
       let bytes = Int64(bytesString) {
      return bytes
    }

    // If header is missing, start from the beginning
    return 0
  }
}
