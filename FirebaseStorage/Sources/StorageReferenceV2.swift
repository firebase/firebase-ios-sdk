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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public extension StorageReference {
  /**
   * Asynchronously uploads data to the currently specified `StorageReference`.
   * This is not recommended for large files, and one should instead upload a file from disk.
   * - Parameters:
   *   - uploadData: The data to upload.
   *   - metadata: `StorageMetadata` containing additional information (MIME type, etc.)
   *       about the object being uploaded.
   * - Returns: A `StorageMetadata` on success.
   * - Throws: A StorageError on failure
   */
  @discardableResult
  func putDataV2(_ uploadData: Data,
                 metadata: StorageMetadata? = nil) async throws -> StorageMetadata {
    let putMetadata = metadata ?? StorageMetadata()
    if let path = path.object {
      putMetadata.path = path
      putMetadata.name = (path as NSString).lastPathComponent as String
    }
    let fetcherService = storage.fetcherServiceForApp
    let task = StorageUploadTaskV2(reference: self,
                                   service: fetcherService,
                                   queue: storage.dispatchQueue,
                                   data: uploadData,
                                   metadata: putMetadata)

    return try await task.upload()
  }

  /**
   * Asynchronously uploads a file to the currently specified `StorageReference`.
   * - Parameters:
   *   - fileURL: A URL representing the system file path of the object to be uploaded.
   *   - metadata: `StorageMetadata` containing additional information (MIME type, etc.)
   *       about the object being uploaded.
   * - Returns: A `StorageMetadata` on success.
   * - Throws: A StorageError on failure
   */
  @discardableResult
  func putFileV2(from fileURL: URL,
                 metadata: StorageMetadata? = nil,
                 progress: Progress? = nil,
                 progressBlock: ((Progress) -> Void)? = nil) async throws -> StorageMetadata {
    var putMetadata: StorageMetadata
    if let progress = progress,
       progress.isCancelled {
      throw StorageError.cancelled
    }
    if metadata == nil {
      putMetadata = StorageMetadata()
      if let path = path.object {
        putMetadata.path = path
        putMetadata.name = (path as NSString).lastPathComponent as String
      }
    } else {
      putMetadata = metadata!
    }
    let fetcherService = storage.fetcherServiceForApp
    let uploadTask = StorageUploadTaskV2(reference: self,
                                         service: fetcherService,
                                         queue: storage.dispatchQueue,
                                         file: fileURL,
                                         metadata: putMetadata,
                                         progress: progress,
                                         progressBlock: progressBlock)
    return try await uploadTask.upload()
  }
}
