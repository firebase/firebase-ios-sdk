// Copyright 2021 Google LLC
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

import FirebaseStorage

#if swift(>=5.5)
  @available(iOS 15, tvOS 15, macOS 12, *)
  public extension StorageReference {
    /// Asynchronously downloads the object at the StorageReference to a Data object in memory.
    /// A Data object of the provided max size will be allocated, so ensure that the device has
    /// enough free memory to complete the download. For downloading large files, the `write`
    /// API may be a better option.
    ///
    /// - Parameters:
    ///   - size: The maximum size in bytes to download. If the download exceeds this size,
    ///           the task will be cancelled and an error will be thrown.
    /// - Returns: Data object.
    func data(maxSize: Int64) async throws -> Data {
      typealias DataContinuation = CheckedContinuation<Data, Error>
      return try await withCheckedThrowingContinuation { (continuation: DataContinuation) in
        // TODO: Use task to handle progress and cancellation.
        _ = self.getData(maxSize: maxSize) { result in
          continuation.resume(with: result)
        }
      }
    }

    /// Asynchronously uploads data to the currently specified StorageReference.
    /// This is not recommended for large files, and one should instead upload a file from disk
    /// from the Firebase Console.
    ///
    /// - Parameters:
    ///   - uploadData: The Data to upload.
    ///   - metadata: Optional StorageMetadata containing additional information (MIME type, etc.)
    ///              about the object being uploaded.
    /// - Returns: StorageMetadata with additional information about the object being uploaded.
    func putDataAsync(_ uploadData: Data,
                      metadata: StorageMetadata? = nil) async throws -> StorageMetadata {
      typealias MetadataContinuation = CheckedContinuation<StorageMetadata, Error>
      return try await withCheckedThrowingContinuation { (continuation: MetadataContinuation) in
        // TODO: Use task to handle progress and cancellation.
        _ = self.putData(uploadData, metadata: metadata) { result in
          continuation.resume(with: result)
        }
      }
    }

    /// Asynchronously uploads a file to the currently specified StorageReference.
    ///
    /// - Parameters:
    ///   - url: A URL representing the system file path of the object to be uploaded.
    ///   - metadata: Optional StorageMetadata containing additional information (MIME type, etc.)
    ///              about the object being uploaded.
    /// - Returns: StorageMetadata with additional information about the object being uploaded.
    func putFileAsync(from url: URL,
                      metadata: StorageMetadata? = nil) async throws -> StorageMetadata {
      typealias MetadataContinuation = CheckedContinuation<StorageMetadata, Error>
      return try await withCheckedThrowingContinuation { (continuation: MetadataContinuation) in
        // TODO: Use task to handle progress and cancellation.
        _ = self.putFile(from: url, metadata: metadata) { result in
          continuation.resume(with: result)
        }
      }
    }

    /// Asynchronously downloads the object at the current path to a specified system filepath.
    ///
    /// - Parameters:
    ///   - fileUrl: A URL representing the system file path of the object to be uploaded.
    /// - Returns: URL pointing to the file path of the downloaded file.
    func writeAsync(toFile fileURL: URL) async throws -> URL {
      typealias URLContinuation = CheckedContinuation<URL, Error>
      return try await withCheckedThrowingContinuation { (continuation: URLContinuation) in
        // TODO: Use task to handle progress and cancellation.
        _ = self.write(toFile: fileURL) { result in
          continuation.resume(with: result)
        }
      }
    }
  }
#endif
