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

import Foundation

public extension StorageReference {
  /// Asynchronously downloads the object at the StorageReference to a Data object in memory.
  /// A Data object of the provided max size will be allocated, so ensure that the device has
  /// enough free memory to complete the download. For downloading large files, the `write`
  /// API may be a better option.
  ///
  /// If the calling task is cancelled, the download is cancelled and `StorageError.cancelled` is
  /// thrown.
  ///
  /// - Parameters:
  ///   - maxSize: The maximum size in bytes to download. If the download exceeds this size,
  ///           the task will be cancelled and an error will be thrown.
  /// - Throws: An error if the operation failed, for example if the data exceeded `maxSize`.
  /// - Returns: Data object.
  func data(maxSize: Int64) async throws -> Data {
    return try await withCancellableStorageTask { continuation in
      self.getData(maxSize: maxSize) { result in
        continuation.resume(with: result)
      }
    }
  }

  /// Asynchronously uploads data to the currently specified StorageReference.
  /// This is not recommended for large files, and one should instead upload a file from disk
  /// from the Firebase Console.
  ///
  /// If the calling task is cancelled, the upload is cancelled and `StorageError.cancelled` is
  /// thrown.
  ///
  /// - Parameters:
  ///   - uploadData: The Data to upload.
  ///   - metadata: Optional StorageMetadata containing additional information (MIME type, etc.)
  ///              about the object being uploaded.
  ///   - onProgress: An optional closure function to return a `Progress` instance while the
  /// upload proceeds.
  /// - Throws: An error if the operation failed, for example if Storage was unreachable.
  /// - Returns: StorageMetadata with additional information about the object being uploaded.
  func putDataAsync(_ uploadData: Data,
                    metadata: StorageMetadata? = nil,
                    onProgress: ((Progress?) -> Void)? = nil) async throws -> StorageMetadata {
    return try await withCancellableStorageTask { continuation in
      let uploadTask = self.putData(uploadData, metadata: metadata) { result in
        continuation.resume(with: result)
      }
      if let onProgress {
        uploadTask.observe(.progress) {
          onProgress($0.progress)
        }
      }
      return uploadTask
    }
  }

  /// Asynchronously uploads a file to the currently specified StorageReference.
  ///
  /// If the calling task is cancelled, the upload is cancelled and `StorageError.cancelled` is
  /// thrown.
  ///
  /// - Parameters:
  ///   - url: A URL representing the system file path of the object to be uploaded.
  ///   - metadata: Optional StorageMetadata containing additional information (MIME type, etc.)
  ///              about the object being uploaded.
  ///   - onProgress: An optional closure function to return a `Progress` instance while the
  /// upload proceeds.
  /// - Throws: An error if the operation failed, for example if no file was present at the
  /// specified `url`.
  /// - Returns: `StorageMetadata` with additional information about the object being uploaded.
  func putFileAsync(from url: URL,
                    metadata: StorageMetadata? = nil,
                    onProgress: ((Progress?) -> Void)? = nil) async throws -> StorageMetadata {
    return try await withCancellableStorageTask { continuation in
      let uploadTask = self.putFile(from: url, metadata: metadata) { result in
        continuation.resume(with: result)
      }
      if let onProgress {
        uploadTask.observe(.progress) {
          onProgress($0.progress)
        }
      }
      return uploadTask
    }
  }

  /// Asynchronously downloads the object at the current path to a specified system filepath.
  ///
  /// If the calling task is cancelled, the download is cancelled and `StorageError.cancelled` is
  /// thrown.
  ///
  /// - Parameters:
  ///   - fileURL: A URL representing the system file path of the object to be uploaded.
  ///   - onProgress: An optional closure function to return a `Progress` instance while the
  /// download proceeds.
  /// - Throws: An error if the operation failed, for example if Storage was unreachable
  ///   or `fileURL` did not reference a valid path on disk.
  /// - Returns: A `URL` pointing to the file path of the downloaded file.
  func writeAsync(toFile fileURL: URL,
                  onProgress: ((Progress?) -> Void)? = nil) async throws -> URL {
    return try await withCancellableStorageTask { continuation in
      let downloadTask = self.write(toFile: fileURL) { result in
        continuation.resume(with: result)
      }
      if let onProgress {
        downloadTask.observe(.progress) {
          onProgress($0.progress)
        }
      }
      return downloadTask
    }
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
  /// - Throws: An error if the operation failed, for example if Storage was unreachable
  ///   or the storage reference referenced an invalid path.
  /// - Returns: A `StorageListResult` containing the contents of the storage reference.
  func list(maxResults: Int64) async throws -> StorageListResult {
    typealias ListContinuation = CheckedContinuation<StorageListResult, Error>
    return try await withCheckedThrowingContinuation { (continuation: ListContinuation) in
      self.list(maxResults: maxResults) { result in
        continuation.resume(with: result)
      }
    }
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
  ///   - pageToken: A page token from a previous call to list.
  /// - Throws:
  ///   - An error if the operation failed, for example if Storage was unreachable
  ///   or the storage reference referenced an invalid path.
  /// - Returns:
  ///   - completion A `Result` enum with either the list or an `Error`.
  func list(maxResults: Int64, pageToken: String) async throws -> StorageListResult {
    typealias ListContinuation = CheckedContinuation<StorageListResult, Error>
    return try await withCheckedThrowingContinuation { (continuation: ListContinuation) in
      self.list(maxResults: maxResults, pageToken: pageToken) { result in
        continuation.resume(with: result)
      }
    }
  }
}

/// Starts an upload or download and waits for its result, cancelling the transfer if the calling
/// task is cancelled.
///
/// - Parameter start: Starts the transfer, arranging for `continuation` to be resumed once with
///   its result, and returns its task. Cancelling the task resumes `continuation` with
///   `StorageError.cancelled`.
/// - Returns: The result of the transfer.
private func withCancellableStorageTask<T>(_ start: (CheckedContinuation<T, Error>)
  -> StorageTaskManagement) async throws -> T {
  let canceller = StorageTaskCanceller()
  return try await withTaskCancellationHandler {
    try await withCheckedThrowingContinuation { continuation in
      canceller.setTask(start(continuation))
    }
  } onCancel: {
    canceller.cancel()
  }
}

/// Cancels a Storage task when the Swift task waiting for it is cancelled.
///
/// The `onCancel` handler of `withTaskCancellationHandler` can run before the operation has
/// started the Storage task (it runs right away if the Swift task is already cancelled),
/// concurrently with it, or after it. The lock makes sure that the Storage task is cancelled in
/// every case.
private final class StorageTaskCanceller: @unchecked Sendable {
  private let lock = NSLock()
  private var isCancelled = false
  private var task: StorageTaskManagement?

  /// Sets the task to cancel, and cancels it right away if cancellation was already requested.
  func setTask(_ task: StorageTaskManagement) {
    let cancelNow = lock.withLock { () -> Bool in
      self.task = task
      return isCancelled
    }
    if cancelNow {
      task.cancel?()
    }
  }

  /// Requests cancellation, and cancels the task if it has been set.
  func cancel() {
    let task = lock.withLock { () -> StorageTaskManagement? in
      isCancelled = true
      return self.task
    }
    task?.cancel?()
  }
}
