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

import FirebaseCoreInternal
import Foundation

/// `StorageReference` represents a reference to a Google Cloud Storage object. Developers can
/// upload and download objects, as well as get/set object metadata, and delete an object at the
/// path. See the [Cloud docs](https://cloud.google.com/storage/)  for more details.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRStorageReference) open class StorageReference: NSObject,
  @unchecked Sendable /* TODO: sendable */ {
  // MARK: - Public APIs

  /// The `Storage` service object which created this reference.
  @objc public let storage: Storage

  /// The name of the Google Cloud Storage bucket associated with this reference.
  /// For example, in `gs://bucket/path/to/object.txt`, the bucket would be 'bucket'.
  @objc public var bucket: String {
    return path.bucket
  }

  /// The full path to this object, not including the Google Cloud Storage bucket.
  /// In `gs://bucket/path/to/object.txt`, the full path would be: `path/to/object.txt`.
  @objc public var fullPath: String {
    return path.object ?? ""
  }

  /// The short name of the object associated with this reference.
  ///
  /// In `gs://bucket/path/to/object.txt`, the name of the object would be `object.txt`.
  @objc public var name: String {
    return (path.object as? NSString)?.lastPathComponent ?? ""
  }

  /// Creates a new `StorageReference` pointing to the root object.
  /// - Returns: A new `StorageReference` pointing to the root object.
  @objc open func root() -> StorageReference {
    return StorageReference(storage: storage, path: path.root())
  }

  /// Creates a new `StorageReference` pointing to the parent of the current reference
  /// or `nil` if this instance references the root location.
  /// ```
  /// For example:
  ///     path = foo/bar/baz   parent = foo/bar
  ///     path = foo           parent = (root)
  ///     path = (root)        parent = nil
  /// ```
  /// - Returns: A new `StorageReference` pointing to the parent of the current reference.
  @objc open func parent() -> StorageReference? {
    guard let parentPath = path.parent() else {
      return nil
    }
    return StorageReference(storage: storage, path: parentPath)
  }

  /// Creates a new `StorageReference` pointing to a child object of the current reference.
  /// ```
  ///     path = foo      child = bar    newPath = foo/bar
  ///     path = foo/bar  child = baz    ntask.impl.snapshotwPath = foo/bar/baz
  /// All leading and trailing slashes will be removed, and consecutive slashes will be
  /// compressed to single slashes. For example:
  ///     child = /foo/bar     newPath = foo/bar
  ///     child = foo/bar/     newPath = foo/bar
  ///     child = foo///bar    newPath = foo/bar
  /// ```
  ///
  /// - Parameter path: The path to append to the current path.
  /// - Returns: A new `StorageReference` pointing to a child location of the current reference.
  @objc(child:) open func child(_ path: String) -> StorageReference {
    return StorageReference(storage: storage, path: self.path.child(path))
  }

  // MARK: - Uploads

  /// Asynchronously uploads data to the currently specified `StorageReference`,
  /// without additional metadata.
  /// This is not recommended for large files, and one should instead upload a file from disk.
  /// - Parameters:
  ///   - uploadData: The data to upload.
  ///   - metadata: `StorageMetadata` containing additional information (MIME type, etc.)
  ///       about the object being uploaded.
  /// - Returns: An instance of `StorageUploadTask`, which can be used to monitor or manage the
  /// upload.
  @objc(putData:metadata:)
  @discardableResult
  open func putData(_ uploadData: Data, metadata: StorageMetadata? = nil) -> StorageUploadTask {
    return putData(uploadData, metadata: metadata, completion: nil)
  }

  /// Asynchronously uploads data to the currently specified `StorageReference`.
  /// This is not recommended for large files, and one should instead upload a file from disk.
  /// - Parameter uploadData The data to upload.
  /// - Returns: An instance of `StorageUploadTask`, which can be used to monitor or manage the
  /// upload.
  @objc(putData:) @discardableResult open func __putData(_ uploadData: Data) -> StorageUploadTask {
    return putData(uploadData, metadata: nil, completion: nil)
  }

  /// Asynchronously uploads data to the currently specified `StorageReference`.
  /// This is not recommended for large files, and one should instead upload a file from disk.
  /// - Parameters:
  ///   - uploadData: The data to upload.
  ///   - metadata: `StorageMetadata` containing additional information (MIME type, etc.)
  ///       about the object being uploaded.
  ///   - completion: A closure that either returns the object metadata on success,
  ///       or an error on failure.
  /// - Returns: An instance of `StorageUploadTask`, which can be used to monitor or manage the
  /// upload.
  @objc(putData:metadata:completion:) @discardableResult
  open func putData(_ uploadData: Data,
                    metadata: StorageMetadata? = nil,
                    completion: ((_: StorageMetadata?, _: Error?) -> Void)?) -> StorageUploadTask {
    let putMetadata = metadata ?? StorageMetadata()
    if let path = path.object {
      putMetadata.path = path
      putMetadata.name = (path as NSString).lastPathComponent as String
    }
    let task = StorageUploadTask(reference: self,
                                 queue: storage.dispatchQueue,
                                 data: uploadData,
                                 metadata: putMetadata)
    startAndObserveUploadTask(task: task, completion: completion)
    return task
  }

  /// Asynchronously uploads a file to the currently specified `StorageReference`.
  /// - Parameters:
  ///   - fileURL: A URL representing the system file path of the object to be uploaded.
  ///   - metadata: `StorageMetadata` containing additional information (MIME type, etc.)
  ///       about the object being uploaded.
  /// - Returns: An instance of `StorageUploadTask`, which can be used to monitor or manage the
  /// upload.
  @objc(putFile:metadata:) @discardableResult
  open func putFile(from fileURL: URL, metadata: StorageMetadata? = nil) -> StorageUploadTask {
    return putFile(from: fileURL, metadata: metadata, completion: nil)
  }

  /// Asynchronously uploads a file to the currently specified `StorageReference`,
  /// without additional metadata.
  /// @param fileURL A URL representing the system file path of the object to be uploaded.
  /// @return An instance of StorageUploadTask, which can be used to monitor or manage the upload.
  @objc(putFile:) @discardableResult open func __putFile(from fileURL: URL) -> StorageUploadTask {
    return putFile(from: fileURL, metadata: nil, completion: nil)
  }

  /// Asynchronously uploads a file to the currently specified `StorageReference`.
  /// - Parameters:
  ///   - fileURL: A URL representing the system file path of the object to be uploaded.
  ///   - metadata: `StorageMetadata` containing additional information (MIME type, etc.)
  ///       about the object being uploaded.
  ///   - completion: A completion block that either returns the object metadata on success,
  ///       or an error on failure.
  /// - Returns: An instance of `StorageUploadTask`, which can be used to monitor or manage the
  /// upload.
  @objc(putFile:metadata:completion:) @discardableResult
  open func putFile(from fileURL: URL,
                    metadata: StorageMetadata? = nil,
                    completion: ((_: StorageMetadata?, _: Error?) -> Void)?) -> StorageUploadTask {
    let putMetadata: StorageMetadata = metadata ?? StorageMetadata()
    if let path = path.object {
      putMetadata.path = path
      putMetadata.name = (path as NSString).lastPathComponent as String
    }
    let task = StorageUploadTask(reference: self,
                                 queue: storage.dispatchQueue,
                                 file: fileURL,
                                 metadata: putMetadata)
    startAndObserveUploadTask(task: task, completion: completion)
    return task
  }

  // MARK: - Downloads

  /// Asynchronously downloads the object at the `StorageReference` to a `Data` instance in memory.
  /// A `Data` buffer of the provided max size will be allocated, so ensure that the device has
  /// enough free
  /// memory to complete the download. For downloading large files, `write(toFile:)` may be a better
  /// option.
  /// - Parameters:
  ///   - maxSize: The maximum size in bytes to download. If the download exceeds this size,
  ///       the task will be cancelled and an error will be returned.
  ///   - completion: A completion block that either returns the object data on success,
  ///       or an error on failure.
  /// - Returns: A `StorageDownloadTask` that can be used to monitor or manage the download.
  @objc(dataWithMaxSize:completion:) @discardableResult
  open func getData(maxSize: Int64,
                    completion: @escaping ((_: Data?, _: Error?) -> Void)) -> StorageDownloadTask {
    let task = StorageDownloadTask(reference: self,
                                   queue: storage.dispatchQueue,
                                   file: nil)

    task.completionData = completion
    let callbackQueue = storage.callbackQueue

    task.observe(.success) { snapshot in
      let error = self.checkSizeOverflow(task: snapshot.task, maxSize: maxSize)
      callbackQueue.async {
        if let completion = task.completionData {
          let data = error == nil ? task.downloadData : nil
          completion(data, error)
          task.completionData = nil
        }
      }
    }
    task.observe(.failure) { snapshot in
      callbackQueue.async {
        task.completionData?(nil, snapshot.error)
        task.completionData = nil
      }
    }
    task.observe(.progress) { snapshot in
      if let error = self.checkSizeOverflow(task: snapshot.task, maxSize: maxSize) {
        task.cancel(withError: error)
      }
    }
    task.enqueue()
    return task
  }

  /// Asynchronously retrieves a long lived download URL with a revokable token.
  /// This can be used to share the file with others, but can be revoked by a developer
  /// in the Firebase Console.
  /// - Parameter completion: A completion block that either returns the URL on success,
  ///     or an error on failure.
  @objc(downloadURLWithCompletion:)
  open func downloadURL(completion: @escaping (@Sendable (_: URL?, _: Error?) -> Void)) {
    StorageGetDownloadURLTask.getDownloadURLTask(reference: self,
                                                 queue: storage.dispatchQueue,
                                                 completion: completion)
  }

  /// Asynchronously retrieves a long lived download URL with a revokable token.
  /// This can be used to share the file with others, but can be revoked by a developer
  /// in the Firebase Console.
  /// - Throws: An error if the download URL could not be retrieved.
  /// - Returns: The URL on success.
  open func downloadURL() async throws -> URL {
    return try await withCheckedThrowingContinuation { continuation in
      self.downloadURL { result in
        continuation.resume(with: result)
      }
    }
  }

  /// Asynchronously downloads the object at the current path to a specified system filepath.
  /// - Parameter fileURL: A file system URL representing the path the object should be downloaded
  /// to.
  /// - Returns A `StorageDownloadTask` that can be used to monitor or manage the download.
  @objc(writeToFile:) @discardableResult
  open func write(toFile fileURL: URL) -> StorageDownloadTask {
    return write(toFile: fileURL, completion: nil)
  }

  /// Asynchronously downloads the object at the current path to a specified system filepath.
  /// - Parameters:
  ///   - fileURL: A file system URL representing the path the object should be downloaded to.
  ///   - completion: A closure that fires when the file download completes, passed either
  ///       a URL pointing to the file path of the downloaded file on success,
  ///       or an error on failure.
  /// - Returns: A `StorageDownloadTask` that can be used to monitor or manage the download.
  @objc(writeToFile:completion:) @discardableResult
  open func write(toFile fileURL: URL,
                  completion: ((_: URL?, _: Error?) -> Void)?) -> StorageDownloadTask {
    let task = StorageDownloadTask(reference: self,
                                   queue: storage.dispatchQueue,
                                   file: fileURL)

    if let completion {
      task.completionURL = completion
      let callbackQueue = storage.callbackQueue

      task.observe(.success) { snapshot in
        callbackQueue.async {
          task.completionURL?(fileURL, nil)
          task.completionURL = nil
        }
      }
      task.observe(.failure) { snapshot in
        callbackQueue.async {
          task.completionURL?(nil, snapshot.error)
          task.completionURL = nil
        }
      }
    }
    task.enqueue()
    return task
  }

  // MARK: - List Support

  /// Lists all items (files) and prefixes (folders) under this `StorageReference`.
  ///
  /// This is a helper method for calling `list()` repeatedly until there are no more results.
  ///
  /// Consistency of the result is not guaranteed if objects are inserted or removed while this
  /// operation is executing. All results are buffered in memory.
  ///
  /// `listAll(completion:)` is only available for projects using Firebase Rules Version 2.
  /// - Parameter completion: A completion handler that will be invoked with all items and prefixes
  /// under
  ///       the current `StorageReference`.
  @objc(listAllWithCompletion:)
  open func listAll(completion: @escaping @Sendable (_: StorageListResult?, _: Error?) -> Void) {
    // Making this a closure changes its self-capture semantics, which causes
    // a compiler error.
    @Sendable func paginatedCompletion(_ listResult: StorageListResult?, _ error: Error?) {
      var prefixes = [StorageReference]()
      var items = [StorageReference]()

      if let error {
        completion(nil, error)
        return
      }
      guard let listResult = listResult else {
        fatalError("internal error: both listResult and error are nil")
      }
      prefixes.append(contentsOf: listResult.prefixes)
      items.append(contentsOf: listResult.items)

      if let pageToken = listResult.pageToken {
        StorageListTask.listTask(reference: self,
                                 queue: storage.dispatchQueue,
                                 pageSize: nil,
                                 previousPageToken: pageToken,
                                 completion: paginatedCompletion)
      } else {
        let result = StorageListResult(withPrefixes: prefixes, items: items, pageToken: nil)
        completion(result, nil)
      }
    }

    StorageListTask.listTask(reference: self,
                             queue: storage.dispatchQueue,
                             pageSize: nil,
                             previousPageToken: nil,
                             completion: paginatedCompletion)
  }

  /// Lists all items (files) and prefixes (folders) under this StorageReference.
  /// This is a helper method for calling list() repeatedly until there are no more results.
  /// Consistency of the result is not guaranteed if objects are inserted or removed while this
  /// operation is executing. All results are buffered in memory.
  /// `listAll()` is only available for projects using Firebase Rules Version 2.
  /// - Throws: An error if the list operation failed.
  /// - Returns: All items and prefixes under the current `StorageReference`.
  open func listAll() async throws -> StorageListResult {
    return try await withCheckedThrowingContinuation { continuation in
      self.listAll { result in
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
  /// - Parameters:
  ///   - maxResults: The maximum number of results to return in a single page. Must be
  ///                greater than 0 and at most 1000.
  ///   - completion: A completion handler that will be invoked with up to `maxResults` items and
  ///       prefixes under the current `StorageReference`.
  @objc(listWithMaxResults:completion:)
  open func list(maxResults: Int64,
                 completion: @escaping (@Sendable (_: StorageListResult?, _: Error?) -> Void)) {
    if maxResults <= 0 || maxResults > 1000 {
      completion(nil, StorageError.invalidArgument(
        message: "Argument 'maxResults' must be between 1 and 1000 inclusive."
      ))
    } else {
      StorageListTask.listTask(reference: self,
                               queue: storage.dispatchQueue,
                               pageSize: maxResults,
                               previousPageToken: nil,
                               completion: completion)
    }
  }

  /// Resumes a previous call to `list(maxResults:completion:)`, starting after a pagination token.
  ///
  /// Returns the next set of items (files) and prefixes (folders) under this `StorageReference`.
  ///
  /// "/" is treated as a path delimiter. Storage does not support unsupported object
  /// paths that end with "/" or contain two consecutive "/"s. All invalid objects in GCS will be
  /// filtered.
  ///
  /// `list(maxResults:pageToken:completion:)`is only available for projects using Firebase Rules
  /// Version 2.
  /// - Parameters:
  ///   - maxResults: The maximum number of results to return in a single page. Must be greater
  ///     than 0 and at most 1000.
  ///   - pageToken: A page token from a previous call to list.
  ///   - completion: A completion handler that will be invoked with the next items and prefixes
  ///     under the current StorageReference.
  @objc(listWithMaxResults:pageToken:completion:)
  open func list(maxResults: Int64,
                 pageToken: String,
                 completion: @escaping (@Sendable (_: StorageListResult?, _: Error?) -> Void)) {
    if maxResults <= 0 || maxResults > 1000 {
      completion(nil, StorageError.invalidArgument(
        message: "Argument 'maxResults' must be between 1 and 1000 inclusive."
      ))
    } else {
      StorageListTask.listTask(reference: self,
                               queue: storage.dispatchQueue,
                               pageSize: maxResults,
                               previousPageToken: pageToken,
                               completion: completion)
    }
  }

  // MARK: - Metadata Operations

  /// Retrieves metadata associated with an object at the current path.
  /// - Parameter completion: A completion block which returns the object metadata on success,
  ///   or an error on failure.
  @objc(metadataWithCompletion:)
  open func getMetadata(completion: @escaping @Sendable (_: StorageMetadata?, _: Error?) -> Void) {
    StorageGetMetadataTask.getMetadataTask(reference: self,
                                           queue: storage.dispatchQueue,
                                           completion: completion)
  }

  /// Retrieves metadata associated with an object at the current path.
  /// - Throws: An error if the object metadata could not be retrieved.
  /// - Returns: The object metadata on success.
  open func getMetadata() async throws -> StorageMetadata {
    return try await withCheckedThrowingContinuation { continuation in
      self.getMetadata { result in
        continuation.resume(with: result)
      }
    }
  }

  /// Updates the metadata associated with an object at the current path.
  /// - Parameters:
  ///   - metadata: A `StorageMetadata` object with the metadata to update.
  ///   - completion: A completion block which returns the `StorageMetadata` on success,
  ///     or an error on failure.
  @objc(updateMetadata:completion:)
  open func updateMetadata(_ metadata: StorageMetadata,
                           completion: (@Sendable (_: StorageMetadata?, _: Error?) -> Void)?) {
    StorageUpdateMetadataTask.updateMetadataTask(reference: self,
                                                 queue: storage.dispatchQueue,
                                                 metadata: metadata,
                                                 completion: completion)
  }

  /// Updates the metadata associated with an object at the current path.
  /// - Parameter metadata: A `StorageMetadata` object with the metadata to update.
  /// - Throws: An error if the metadata update operation failed.
  /// - Returns: The object metadata on success.
  open func updateMetadata(_ metadata: StorageMetadata) async throws -> StorageMetadata {
    return try await withCheckedThrowingContinuation { continuation in
      self.updateMetadata(metadata) { result in
        continuation.resume(with: result)
      }
    }
  }

  // MARK: - Delete

  /// Deletes the object at the current path.
  /// - Parameter completion: A completion block which returns a nonnull error on failure.
  @objc(deleteWithCompletion:)
  open func delete(completion: (@Sendable (_: Error?) -> Void)?) {
    let completionWrap: @Sendable (Data?, Error?) -> Void = { (_: Data?, error: Error?) in
      if let completion {
        completion(error)
      }
    }
    StorageDeleteTask.deleteTask(reference: self,
                                 queue: storage.dispatchQueue,
                                 completion: completionWrap)
  }

  /// Deletes the object at the current path.
  /// - Throws: An error if the delete operation failed.
  open func delete() async throws {
    return try await withCheckedThrowingContinuation { continuation in
      self.delete { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  // MARK: - NSObject overrides

  /// NSObject override
  @objc override open func copy() -> Any {
    return StorageReference(storage: storage, path: path)
  }

  /// NSObject override
  @objc override open func isEqual(_ object: Any?) -> Bool {
    guard let ref = object as? StorageReference else {
      return false
    }
    return storage == ref.storage && path == ref.path
  }

  /// NSObject override
  @objc override public var hash: Int {
    return storage.hash ^ path.bucket.hashValue
  }

  /// NSObject override
  @objc override public var description: String {
    return "gs://\(path.bucket)/\(path.object ?? "")"
  }

  // MARK: - Internal APIs

  /// The current path which points to an object in the Google Cloud Storage bucket.
  let path: StoragePath

  override init() {
    storage = Storage.storage()
    let storageBucket = storage.app.options.storageBucket!
    path = StoragePath(with: storageBucket)
  }

  init(storage: Storage, path: StoragePath) {
    self.storage = storage
    self.path = path
  }

  /// For maxSize API, return an error if the size is exceeded.
  private func checkSizeOverflow(task: StorageTask, maxSize: Int64) -> NSError? {
    if task.progress.totalUnitCount > maxSize || task.progress.completedUnitCount > maxSize {
      return StorageError.downloadSizeExceeded(
        total: task.progress.totalUnitCount,
        maxSize: maxSize
      ) as NSError
    }
    return nil
  }

  private func startAndObserveUploadTask(task: StorageUploadTask,
                                         completion: ((_: StorageMetadata?, _: Error?) -> Void)?) {
    if let completion {
      task.completionMetadata = completion
      let callbackQueue = storage.callbackQueue

      task.observe(.success) { snapshot in
        callbackQueue.async {
          task.completionMetadata?(snapshot.metadata, nil)
          task.completionMetadata = nil
        }
      }
      task.observe(.failure) { snapshot in
        callbackQueue.async {
          task.completionMetadata?(nil, snapshot.error)
          task.completionMetadata = nil
        }
      }
    }
    task.enqueue()
  }
}
