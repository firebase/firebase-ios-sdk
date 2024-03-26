// Copyright 2020 Google LLC
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

/// Generates a closure that returns a `Result` type from a closure that returns an optional type
/// and `Error`.
///
/// - Parameters:
///   - completion: A completion block returning a `Result` enum with either a generic object or
///                 an `Error`.
/// - Returns: A closure parameterized with an optional generic and optional `Error` to match
///            Objective-C APIs.
private func getResultCallback<T>(completion: @escaping (Result<T, Error>) -> Void) -> (_: T?,
                                                                                        _: Error?)
  -> Void {
  return { (value: T?, error: Error?) in
    if let value = value {
      completion(.success(value))
    } else if let error = error {
      completion(.failure(StorageError.swiftConvert(objcError: error as NSError)))
    } else {
      completion(.failure(StorageError.internalError("Internal failure in getResultCallback")))
    }
  }
}

public extension StorageReference {
  /// Asynchronously retrieves a long lived download URL with a revokable token.
  ///
  /// This can be used to share the file with others, but can be revoked by a developer
  /// in the Firebase Console.
  ///
  /// - Parameters:
  ///   - completion: A completion block returning a `Result` enum with either a URL or an `Error`.
  func downloadURL(completion: @escaping (Result<URL, Error>) -> Void) {
    downloadURL(completion: getResultCallback(completion: completion))
  }

  /// Asynchronously downloads the object at the `StorageReference` to a `Data` object.
  ///
  /// A `Data` of the provided max size will be allocated, so ensure that the device has enough
  /// memory to complete. For downloading large files, the `write` API may be a better option.

  /// - Parameters:
  ///   - maxSize: The maximum size in bytes to download.
  ///   - completion: A completion block returning a `Result` enum with either a `Data` object or
  ///                 an `Error`.
  ///
  /// - Returns: A StorageDownloadTask that can be used to monitor or manage the download.
  @discardableResult
  func getData(maxSize: Int64, completion: @escaping (Result<Data, Error>) -> Void)
    -> StorageDownloadTask {
    return getData(maxSize: maxSize, completion: getResultCallback(completion: completion))
  }

  /// Retrieves metadata associated with an object at the current path.
  ///
  /// - Parameters:
  ///   - completion: A completion block which returns a `Result` enum with either the
  ///                 object metadata or an `Error`.
  func getMetadata(completion: @escaping (Result<StorageMetadata, Error>) -> Void) {
    getMetadata(completion: getResultCallback(completion: completion))
  }

  /// Resumes a previous `list` call, starting after a pagination token.
  ///
  /// Returns the next set of items (files) and prefixes (folders) under this StorageReference.
  ///
  /// "/" is treated as a path delimiter. Firebase Storage does not support unsupported object
  /// paths that end with "/" or contain two consecutive "/"s. All invalid objects in GCS will be
  /// filtered.
  ///
  /// Only available for projects using Firebase Rules Version 2.
  ///
  /// - Parameters:
  ///   - maxResults: The maximum number of results to return in a single page. Must be
  ///                greater than 0 and at most 1000.
  ///   - pageToken: A page token from a previous call to list.
  ///   - completion: A completion handler that will be invoked with the next items and
  ///                prefixes under the current StorageReference. It returns a `Result` enum
  ///                with either the list or an `Error`.
  func list(maxResults: Int64,
            pageToken: String,
            completion: @escaping (Result<StorageListResult, Error>) -> Void) {
    list(maxResults: maxResults,
         pageToken: pageToken,
         completion: getResultCallback(completion: completion))
  }

  /// List up to `maxResults` items (files) and prefixes (folders) under this StorageReference.
  ///
  /// "/" is treated as a path delimiter. Firebase Storage does not support unsupported object
  /// paths that end with "/" or contain two consecutive "/"s. All invalid objects in GCS will be
  /// filtered.
  ///
  /// Only available for projects using Firebase Rules Version 2.
  ///
  /// - Parameters:
  ///   - maxResults: The maximum number of results to return in a single page. Must be
  ///                greater than 0 and at most 1000.
  ///   - completion: A completion handler that will be invoked with the next items and
  ///                prefixes under the current `StorageReference`. It returns a `Result` enum
  ///                with either the list or an `Error`.
  func list(maxResults: Int64,
            completion: @escaping (Result<StorageListResult, Error>) -> Void) {
    list(maxResults: maxResults,
         completion: getResultCallback(completion: completion))
  }

  /// List all items (files) and prefixes (folders) under this StorageReference.
  ///
  /// This is a helper method for calling list() repeatedly until there are no more results.
  /// Consistency of the result is not guaranteed if objects are inserted or removed while this
  /// operation is executing. All results are buffered in memory.
  ///
  /// Only available for projects using Firebase Rules Version 2.
  ///
  /// - Parameters:
  ///   - completion: A completion handler that will be invoked with all items and prefixes
  ///                under the current StorageReference. It returns a `Result` enum with either the
  ///                list or an `Error`.
  func listAll(completion: @escaping (Result<StorageListResult, Error>) -> Void) {
    listAll(completion: getResultCallback(completion: completion))
  }

  /// Asynchronously uploads data to the currently specified `StorageReference`.
  /// This is not recommended for large files, and one should instead upload a file from disk.
  ///
  /// - Parameters:
  ///   - uploadData: The `Data` to upload.
  ///   - metadata: `StorageMetadata` containing additional information (MIME type, etc.)
  ///              about the object being uploaded.
  ///   - completion: A completion block that returns a `Result` enum with either the
  ///                object metadata or an `Error`.
  ///
  /// - Returns: An instance of `StorageUploadTask`, which can be used to monitor or manage
  ///            the upload.
  @discardableResult
  func putData(_ uploadData: Data,
               metadata: StorageMetadata? = nil,
               completion: @escaping (Result<StorageMetadata, Error>) -> Void)
    -> StorageUploadTask {
    return putData(uploadData,
                   metadata: metadata,
                   completion: getResultCallback(completion: completion))
  }

  /// Asynchronously uploads a file to the currently specified `StorageReference`.
  ///
  /// - Parameters:
  ///   - from: A URL representing the system file path of the object to be uploaded.
  ///   - metadata: `StorageMetadata` containing additional information (MIME type, etc.)
  ///              about the object being uploaded.
  ///   - completion: A completion block that returns a `Result` enum with either the
  ///                object metadata or an `Error`.
  ///
  /// - Returns: An instance of `StorageUploadTask`, which can be used to monitor or manage
  ///            the upload.
  @discardableResult
  func putFile(from: URL,
               metadata: StorageMetadata? = nil,
               completion: @escaping (Result<StorageMetadata, Error>) -> Void)
    -> StorageUploadTask {
    return putFile(from: from,
                   metadata: metadata,
                   completion: getResultCallback(completion: completion))
  }

  /// Updates the metadata associated with an object at the current path.
  ///
  /// - Parameters:
  ///   - metadata: A `StorageMetadata` object with the metadata to update.
  ///   - completion: A completion block which returns a `Result` enum with either the
  ///                object metadata or an `Error`.
  func updateMetadata(_ metadata: StorageMetadata,
                      completion: @escaping (Result<StorageMetadata, Error>) -> Void) {
    updateMetadata(metadata, completion: getResultCallback(completion: completion))
  }

  /// Asynchronously downloads the object at the current path to a specified system filepath.
  ///
  /// - Parameters:
  ///   - toFile: A file system URL representing the path the object should be downloaded to.
  ///   - completion: A completion block that fires when the file download completes. The
  ///                block returns a `Result` enum with either an NSURL pointing to the file
  ///                path of the downloaded file or an `Error`.
  ///
  /// - Returns: A `StorageDownloadTask` that can be used to monitor or manage the download.
  @discardableResult
  func write(toFile: URL, completion: @escaping (Result<URL, Error>)
    -> Void) -> StorageDownloadTask {
    return write(toFile: toFile, completion: getResultCallback(completion: completion))
  }
}
