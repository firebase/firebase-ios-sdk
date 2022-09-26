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
 * Uploads can be returned on completion with a completion callback, and can be monitored
 * by attaching observers, or controlled by calling `pause()`, `resume()`,
 * or `cancel()`.
 * Uploads can be initialized from `Data` in memory, or a URL to a file on disk.
 * Uploads are performed on a background queue, and callbacks are raised on the developer
 * specified `callbackQueue` in Storage, or the main queue if unspecified.
 * Currently all uploads must be initiated and managed on the main queue.
 */
@objc(FIRStorageUploadTask) open class StorageUploadTask: StorageObservableTask,
  StorageTaskManagement {
  /**
   * Prepares a task and begins execution.
   */
  @objc open func enqueue() {
    weak var weakSelf = self
    DispatchQueue.global(qos: .background).async {
      guard let strongSelf = weakSelf else { return }
      if let contentValidationError = strongSelf.contentUploadError() {
        strongSelf.error = contentValidationError
        strongSelf.finishTaskWithStatus(status: .failure, snapshot: strongSelf.snapshot)
        return
      }

      strongSelf.state = .queueing
      var request = strongSelf.baseRequest
      request.httpMethod = "POST"
      request.timeoutInterval = strongSelf.reference.storage.maxUploadRetryTime

      let dataRepresentation = strongSelf.uploadMetadata.dictionaryRepresentation()
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
      guard let path = strongSelf.GCSEscapedString(self.uploadMetadata.path) else {
        fatalError("Internal error enqueueing a Storage task")
      }
      components?.percentEncodedQuery = "uploadType=resumable&name=\(path)"

      request.url = components?.url

      guard let contentType = strongSelf.uploadMetadata.contentType else {
        fatalError("Internal error enqueueing a Storage task")
      }
      let uploadFetcher = GTMSessionUploadFetcher(
        request: request,
        uploadMIMEType: contentType,
        chunkSize: Int64.max,
        fetcherService: strongSelf.fetcherService
      )
      if let data = strongSelf.uploadData {
        uploadFetcher.uploadData = data
        uploadFetcher.comment = "Data UploadTask"
      } else if let fileURL = strongSelf.fileURL {
        uploadFetcher.uploadFileURL = fileURL
        uploadFetcher.comment = "File UploadTask"
      }
      uploadFetcher.maxRetryInterval = strongSelf.reference.storage.maxUploadRetryInterval

      uploadFetcher.sendProgressBlock = { (bytesSent: Int64, totalBytesSent: Int64,
                                           totalBytesExpectedToSend: Int64) in
          weakSelf?.state = .progress
          weakSelf?.progress.completedUnitCount = totalBytesSent
          weakSelf?.progress.totalUnitCount = totalBytesExpectedToSend
          weakSelf?.metadata = weakSelf?.uploadMetadata
          if let snapshot = weakSelf?.snapshot {
            weakSelf?.fire(for: .progress, snapshot: snapshot)
          }
          weakSelf?.state = .running
      }
      strongSelf.uploadFetcher = uploadFetcher

      // Process fetches
      strongSelf.state = .running

      strongSelf.fetcherCompletion = { (data: Data?, error: NSError?) in
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
      strongSelf.uploadFetcher?.beginFetch { (data: Data?, error: Error?) in
        let strongSelf = weakSelf
        if let fetcherCompletion = strongSelf?.fetcherCompletion {
          fetcherCompletion(data, error as NSError?)
        }
      }
    }
  }

  /**
   * Pauses a task currently in progress.
   */
  @objc open func pause() {
    weak var weakSelf = self
    DispatchQueue.global(qos: .background).async {
      weakSelf?.state = .paused
      weakSelf?.uploadFetcher?.pauseFetching()
      if weakSelf?.state != .success {
        weakSelf?.metadata = weakSelf?.uploadMetadata
      }
      if let snapshot = weakSelf?.snapshot {
        weakSelf?.fire(for: .pause, snapshot: snapshot)
      }
    }
  }

  /**
   * Cancels a task.
   */
  @objc open func cancel() {
    weak var weakSelf = self
    DispatchQueue.global(qos: .background).async {
      weakSelf?.state = .cancelled
      weakSelf?.uploadFetcher?.stopFetching()
      if weakSelf?.state != .success {
        weakSelf?.metadata = weakSelf?.uploadMetadata
      }
      weakSelf?.error = StorageErrorCode.error(
        withServerError: StorageErrorCode.cancelled as NSError,
        ref: self.reference
      )
      if let snapshot = weakSelf?.snapshot {
        weakSelf?.fire(for: .failure, snapshot: snapshot)
      }
    }
  }

  /**
   * Resumes a paused task.
   */
  @objc open func resume() {
    weak var weakSelf = self
    DispatchQueue.global(qos: .background).async {
      weakSelf?.state = .resuming
      weakSelf?.uploadFetcher?.resumeFetching()
      if weakSelf?.state != .success {
        weakSelf?.metadata = weakSelf?.uploadMetadata
      }
      if let snapshot = weakSelf?.snapshot {
        weakSelf?.fire(for: .resume, snapshot: snapshot)
      }
      weakSelf?.state = .running
    }
  }

  private var uploadFetcher: GTMSessionUploadFetcher?
  private var fetcherCompletion: ((Data?, NSError?) -> Void)?
  private var uploadMetadata: StorageMetadata
  private var uploadData: Data?

  // MARK: - Internal Implementations

  internal init(reference: StorageReference,
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

  internal func finishTaskWithStatus(status: StorageTaskStatus, snapshot: StorageTaskSnapshot) {
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
