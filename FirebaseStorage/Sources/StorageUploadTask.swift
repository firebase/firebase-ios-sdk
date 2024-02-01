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
      if let contentValidationError = self.contentUploadError() {
        self.error = contentValidationError
        self.finishTaskWithStatus(status: .failure, snapshot: self.snapshot)
        return
      }

      self.state = .queueing
      var request = self.baseRequest
      request.httpMethod = "POST"
      request.timeoutInterval = self.reference.storage.maxUploadRetryTime

      let dataRepresentation = self.uploadMetadata.dictionaryRepresentation()
      let bodyData = try? JSONSerialization.data(withJSONObject: dataRepresentation)

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
        fetcherService: self.fetcherService
      )
      if let data = self.uploadData {
        uploadFetcher.uploadData = data
        uploadFetcher.comment = "Data UploadTask"
      } else if let fileURL = self.fileURL {
        uploadFetcher.uploadFileURL = fileURL
        uploadFetcher.comment = "File UploadTask"
      }
      uploadFetcher.maxRetryInterval = self.reference.storage.maxUploadRetryInterval

      uploadFetcher.sendProgressBlock = { [weak self] (bytesSent: Int64, totalBytesSent: Int64,
                                                       totalBytesExpectedToSend: Int64) in
          guard let self = self else { return }
          self.state = .progress
          self.progress.completedUnitCount = totalBytesSent
          self.progress.totalUnitCount = totalBytesExpectedToSend
          self.metadata = self.uploadMetadata
          self.fire(for: .progress, snapshot: self.snapshot)
          self.state = .running
      }
      self.uploadFetcher = uploadFetcher

      // Process fetches
      self.state = .running

      self.fetcherCompletion = { [self] (data: Data?, error: NSError?) in
        // Fire last progress updates
        self.fire(for: .progress, snapshot: self.snapshot)

        // Handle potential issues with upload
        if let error = error {
          self.state = .failed
          self.error = StorageErrorCode.error(withServerError: error, ref: self.reference)
          self.metadata = self.uploadMetadata
          self.finishTaskWithStatus(status: .failure, snapshot: self.snapshot)
          return
        }
        // Upload completed successfully, fire completion callbacks
        self.state = .success

        guard let data = data else {
          fatalError("Internal Error: fetcherCompletion returned with nil data and nil error")
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
      }
      self.uploadFetcher?.beginFetch { [weak self] (data: Data?, error: Error?) in
        self?.fetcherCompletion?(data, error as NSError?)
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
  private var fetcherCompletion: ((Data?, NSError?) -> Void)?
  private var uploadMetadata: StorageMetadata
  private var uploadData: Data?
  // Hold completion in object to force it to be retained until completion block is called.
  var completionMetadata: ((StorageMetadata?, Error?) -> Void)?

  // MARK: - Internal Implementations

  init(reference: StorageReference,
       service: GTMSessionFetcherService,
       queue: DispatchQueue,
       file: URL? = nil,
       data: Data? = nil,
       metadata: StorageMetadata) {
    uploadMetadata = metadata
    uploadData = data
    super.init(reference: reference, service: service, queue: queue, file: file)

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
    let userInfo = [NSLocalizedDescriptionKey:
      "File at URL: \(fileURL?.absoluteString ?? "") is not reachable."
      + " Ensure file URL is not a directory, symbolic link, or invalid url."]
    return NSError(
      domain: StorageErrorDomain,
      code: StorageErrorCode.unknown.rawValue,
      userInfo: userInfo
    )
  }

  func finishTaskWithStatus(status: StorageTaskStatus, snapshot: StorageTaskSnapshot) {
    fire(for: status, snapshot: snapshot)
    removeAllObservers()
    fetcherCompletion = nil
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
