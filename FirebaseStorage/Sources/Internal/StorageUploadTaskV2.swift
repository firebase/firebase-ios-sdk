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
 * `StorageUploadTaskV2` implements resumable uploads to a file in Firebase Storage.
 * Uploads can be done via an async/await function or with a completion callback with a
 * Swift task return value.
 * Uploads can be initialized from `Data` in memory, or a URL to a file on disk.
 * Uploads are performed on a background queue, and callbacks are raised on the developer
 * specified `callbackQueue` in Storage, or the main queue if unspecified.
 * Currently all uploads must be initiated and managed on the main queue.
 */
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
internal class StorageUploadTaskV2: StorageTask {
  /**
   * Prepares a GTMSessionFetcher task and does an upload.
   */
  internal func upload() async throws -> StorageMetadata {
    if let contentValidationError = isContentToUploadInvalid() {
      throw StorageError.swiftConvert(objcError: contentValidationError)
    }

    var request = baseRequest
    request.httpMethod = "POST"
    request.timeoutInterval = reference.storage.maxUploadRetryTime

    let dataRepresentation = uploadMetadata.dictionaryRepresentation()
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
    guard let path = GCSEscapedString(uploadMetadata.path) else {
      fatalError("Internal error enqueueing a Storage task")
    }
    components?.percentEncodedQuery = "uploadType=resumable&name=\(path)"

    request.url = components?.url

    guard let contentType = uploadMetadata.contentType else {
      fatalError("Internal error enqueueing a Storage task")
    }
    let uploadFetcher = GTMSessionUploadFetcher(
      request: request,
      uploadMIMEType: contentType,
      chunkSize: Int64.max,
      fetcherService: fetcherService
    )
    if let data = uploadData {
      uploadFetcher.uploadData = data
      uploadFetcher.comment = "Data UploadTask"
    } else if let fileURL = fileURL {
      uploadFetcher.uploadFileURL = fileURL
      uploadFetcher.comment = "File UploadTask"
    }
    uploadFetcher.maxRetryInterval = reference.storage.maxUploadRetryInterval

    if let progressBlock = progressBlock {
      uploadFetcher.sendProgressBlock = { (bytesSent: Int64, totalBytesSent: Int64,
                                           totalBytesExpectedToSend: Int64) in
          self.progress.completedUnitCount = totalBytesSent
          self.progress.totalUnitCount = totalBytesExpectedToSend
          self.metadata = self.uploadMetadata
          progressBlock(self.progress)
      }
    }

    let (data, error) = await beginFetch(uploadFetcher: uploadFetcher)
    defer {
      uploadFetcher.stopFetching()
    }

    // Handle potential issues with upload
    if let error = error {
      throw StorageError.swiftConvert(objcError: StorageErrorCode.error(
        withServerError: error as NSError, ref: reference
      ))
    }

    guard let data = data else {
      fatalError("Internal Error: fetcherCompletion returned with nil data and nil error")
    }

    if let responseDictionary = try? JSONSerialization
      .jsonObject(with: data) as? [String: AnyHashable] {
      let metadata = StorageMetadata(dictionary: responseDictionary)
      metadata.fileType = .file
      return metadata
    } else {
      throw StorageError.swiftConvert(objcError: StorageErrorCode.error(withInvalidRequest: data))
    }
  }

  private func beginFetch(uploadFetcher: GTMSessionUploadFetcher) async -> (Data?, Error?) {
    return await withCheckedContinuation { continuation in
      uploadFetcher.beginFetch { data, error in
        continuation.resume(returning: (data, error))
      }
    }
  }

  private let uploadMetadata: StorageMetadata
  private let uploadData: Data?
  private let progressBlock: ((Progress) -> Void)?
  /**
   * The file to download to or upload from
   */
  private let fileURL: URL?

  // MARK: - Internal Implementations

  internal init(reference: StorageReference,
                service: GTMSessionFetcherService,
                queue: DispatchQueue,
                file: URL? = nil,
                data: Data? = nil,
                metadata: StorageMetadata,
                progressBlock: ((Progress) -> Void)? = nil) {
    uploadMetadata = metadata
    uploadData = data
    fileURL = file
    self.progressBlock = progressBlock
    super.init(reference: reference, service: service, queue: queue)

    if uploadMetadata.contentType == nil {
      uploadMetadata.contentType = StorageUtils.MIMETypeForExtension(file?.pathExtension)
    }
  }

  internal func isContentToUploadInvalid() -> NSError? {
    // TODO: - Does checkResourceIsReachableAndReturnError need to be ported here?
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
