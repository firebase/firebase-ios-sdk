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

import FirebaseStorageInternal

/**
 * `StorageReference` represents a reference to a Google Cloud Storage object. Developers can
 * upload and download objects, as well as get/set object metadata, and delete an object at the
 * path. See the Cloud docs  for more details: https://cloud.google.com/storage/
 */

@objc(FIRStorageReference) open class StorageReference: NSObject {
  // MARK: - Public APIs

  /**
   * The `Storage` service object which created this reference.
   */
  @objc public let storage: Storage

  /**
   * The name of the Google Cloud Storage bucket associated with this reference.
   * For example, in `gs://bucket/path/to/object.txt`, the bucket would be 'bucket'.
   */
  @objc public let bucket: String
  /**
   * The full path to this object, not including the Google Cloud Storage bucket.
   * In `gs://bucket/path/to/object.txt`, the full path would be: `path/to/object.txt`
   */
  @objc public let fullPath: String

  /**
   * The short name of the object associated with this reference.
   * In `gs://bucket/path/to/object.txt`, the name of the object would be `object.txt`.
   */
  @objc public let name: String

  /**
   * Creates a new `StorageReference` pointing to the root object.
   * - Returns: A new `StorageReference` pointing to the root object.
   */
  @objc open func root() -> StorageReference {
    return StorageReference(impl: impl.root(), storage: storage)
  }

  /**
   * Creates a new `StorageReference` pointing to the parent of the current reference
   * or `nil` if this instance references the root location.
   * For example:
   *     path = foo/bar/baz   parent = foo/bar
   *     path = foo           parent = (root)
   *     path = (root)        parent = nil
   * - Returns: A new `StorageReference` pointing to the parent of the current reference.
   */
  @objc open func parent() -> StorageReference? {
    guard let parent = impl.parent() else {
      return nil
    }
    return StorageReference(impl: parent, storage: storage)
  }

  /**
   * Creates a new `StorageReference` pointing to a child object of the current reference.
   *     path = foo      child = bar    newPath = foo/bar
   *     path = foo/bar  child = baz    ntask.impl.snapshotwPath = foo/bar/baz
   * All leading and trailing slashes will be removed, and consecutive slashes will be
   * compressed to single slashes. For example:
   *     child = /foo/bar     newPath = foo/bar
   *     child = foo/bar/     newPath = foo/bar
   *     child = foo///bar    newPath = foo/bar
   * - Parameter path The path to append to the current path.
   * - Returns: A new `StorageReference` pointing to a child location of the current reference.
   */
  @objc(child:) open func child(_ path: String) -> StorageReference {
    return StorageReference(impl: impl.child(path), storage: storage)
  }

  // MARK: - Uploads

  /**
   * Asynchronously uploads data to the currently specified `StorageReference`,
   * without additional metadata.
   * This is not recommended for large files, and one should instead upload a file from disk.
   * - Parameters:
   *   - uploadData: The data to upload.
   *   - metadata: `StorageMetadata` containing additional information (MIME type, etc.)
   *       about the object being uploaded.
   * - Returns: An instance of `StorageUploadTask`, which can be used to monitor or manage the upload.
   */
  @objc(putData:metadata:)
  @discardableResult
  open func putData(_ uploadData: Data, metadata: StorageMetadata? = nil) -> StorageUploadTask {
    return StorageUploadTask(impl.put(uploadData, metadata: metadata?.impl))
  }

  /**
   * Asynchronously uploads data to the currently specified `StorageReference`.
   * This is not recommended for large files, and one should instead upload a file from disk.
   * - Parameter uploadData The data to upload.
   * - Returns: An instance of `StorageUploadTask`, which can be used to monitor or manage the upload.
   */
  @objc(putData:) @discardableResult open func __putData(_ uploadData: Data) -> StorageUploadTask {
    return StorageUploadTask(impl.put(uploadData))
  }

  /**
   * Asynchronously uploads data to the currently specified `StorageReference`.
   * This is not recommended for large files, and one should instead upload a file from disk.
   * - Parameters:
   *   - uploadData: The data to upload.
   *   - metadata: `StorageMetadata` containing additional information (MIME type, etc.)
   *       about the object being uploaded.
   *   - completion: A closure that either returns the object metadata on success,
   *       or an error on failure.
   * - Returns: An instance of `StorageUploadTask`, which can be used to monitor or manage the upload.
   */
  @objc(putData:metadata:completion:) @discardableResult
  open func putData(_ uploadData: Data,
                    metadata: StorageMetadata? = nil,
                    completion: ((_: StorageMetadata?, _: Error?) -> Void)?) -> StorageUploadTask {
    return StorageUploadTask(impl.put(uploadData, metadata: metadata?.impl) { impl, error in
      if let completion = completion {
        self.adaptMetadataCallback(completion: completion)(impl, error)
      }
    })
  }

  /**
   * Asynchronously uploads a file to the currently specified `StorageReference`.
   * - Parameters:
   *   - fileURL: A URL representing the system file path of the object to be uploaded.
   *   - metadata: `StorageMetadata` containing additional information (MIME type, etc.)
   *       about the object being uploaded.
   * - Returns: An instance of `StorageUploadTask`, which can be used to monitor or manage the upload.
   */
  @objc(putFile:metadata:) @discardableResult
  open func putFile(from fileURL: URL, metadata: StorageMetadata? = nil) -> StorageUploadTask {
    return StorageUploadTask(impl.putFile(fileURL, metadata: metadata?.impl))
  }

  /**
   * Asynchronously uploads a file to the currently specified `StorageReference`,
   * without additional metadata.
   * @param fileURL A URL representing the system file path of the object to be uploaded.
   * @return An instance of StorageUploadTask, which can be used to monitor or manage the upload.
   */
  @objc(putFile:) @discardableResult open func __putFile(from fileURL: URL) -> StorageUploadTask {
    return StorageUploadTask(impl.putFile(fileURL))
  }

  /**
   * Asynchronously uploads a file to the currently specified `StorageReference`.
   * - Parameters:
   *   - fileURL: A URL representing the system file path of the object to be uploaded.
   *   - metadata: `StorageMetadata` containing additional information (MIME type, etc.)
   *       about the object being uploaded.
   *   - completion: A completion block that either returns the object metadata on success,
   *       or an error on failure.
   * - Returns: An instance of `StorageUploadTask`, which can be used to monitor or manage the upload.
   */
  @objc(putFile:metadata:completion:) @discardableResult
  open func putFile(from fileURL: URL,
                    metadata: StorageMetadata? = nil,
                    completion: ((_: StorageMetadata?, _: Error?) -> Void)?) -> StorageUploadTask {
    return StorageUploadTask(impl.putFile(fileURL, metadata: metadata?.impl) { impl, error in
      if let completion = completion {
        self.adaptMetadataCallback(completion: completion)(impl, error)
      }
    })
  }

  // MARK: - Downloads

  /**
   * Asynchronously downloads the object at the `StorageReference` to a `Data` instance in memory.
   * A `Data` buffer of the provided max size will be allocated, so ensure that the device has enough free
   * memory to complete the download. For downloading large files, `write(toFile:)` may be a better option.
   * - Parameters:
   *   - maxSize: The maximum size in bytes to download. If the download exceeds this size,
   *       the task will be cancelled and an error will be returned.
   *   - completion: A completion block that either returns the object data on success,
   *       or an error on failure.
   * - Returns: An `StorageDownloadTask` that can be used to monitor or manage the download.
   */
  @objc(dataWithMaxSize:completion:) @discardableResult
  open func getData(maxSize: Int64,
                    completion: @escaping ((_: Data?, _: Error?) -> Void)) -> StorageDownloadTask {
    return StorageDownloadTask(impl.data(withMaxSize: maxSize, completion: completion))
  }

  /**
   * Asynchronously retrieves a long lived download URL with a revokable token.
   * This can be used to share the file with others, but can be revoked by a developer
   * in the Firebase Console.
   * - Parameter completion A completion block that either returns the URL on success,
   *     or an error on failure.
   */
  @objc(downloadURLWithCompletion:)
  open func downloadURL(completion: @escaping ((_: URL?, _: Error?) -> Void)) {
    impl.downloadURL(completion: completion)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    /**
     * Asynchronously retrieves a long lived download URL with a revokable token.
     * This can be used to share the file with others, but can be revoked by a developer
     * in the Firebase Console.
     * - Throws: An error if the download URL could not be retrieved.
     * - Returns: The URL on success.
     */
    @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
    open func downloadURL() async throws -> URL {
      return try await impl.downloadURL()
    }
  #endif // compiler(>=5.5) && canImport(_Concurrency)

  /**
   * Asynchronously downloads the object at the current path to a specified system filepath.
   * - Parameter fileURL A file system URL representing the path the object should be downloaded to.
   * - Returns An `StorageDownloadTask` that can be used to monitor or manage the download.
   */
  @objc(writeToFile:) @discardableResult
  open func write(toFile fileURL: URL) -> StorageDownloadTask {
    return StorageDownloadTask(impl.write(toFile: fileURL))
  }

  /**
   * Asynchronously downloads the object at the current path to a specified system filepath.
   * - Parameters:
   *   - fileURL: A file system URL representing the path the object should be downloaded to.
   *   - completion: A closure that fires when the file download completes, passed either
   *       a URL pointing to the file path of the downloaded file on success,
   *       or an error on failure.
   * - Returns: A `StorageDownloadTask` that can be used to monitor or manage the download.
   */
  @objc(writeToFile:completion:) @discardableResult
  open func write(toFile fileURL: URL,
                  completion: ((_: URL?, _: Error?) -> Void)?) -> StorageDownloadTask {
    return StorageDownloadTask(impl.write(toFile: fileURL, completion: completion))
  }

  // MARK: - List Support

  /**
   * Lists all items (files) and prefixes (folders) under this `StorageReference`.
   *
   * This is a helper method for calling `list()` repeatedly until there are no more results.
   * Consistency of the result is not guaranteed if objects are inserted or removed while this
   * operation is executing. All results are buffered in memory.
   *
   * `listAll(completion:)` is only available for projects using Firebase Rules Version 2.
   *
   * - Parameter completion A completion handler that will be invoked with all items and prefixes under
   *       the current `StorageReference`.
   */
  @objc(listAllWithCompletion:)
  open func listAll(completion: @escaping ((_: StorageListResult?, _: Error?) -> Void)) {
    impl.listAll { listResult, error in
      if error != nil {
        completion(nil, error)
      } else {
        completion(StorageListResult(listResult), error)
      }
    }
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    /**
     * Lists all items (files) and prefixes (folders) under this StorageReference.
     *
     * This is a helper method for calling list() repeatedly until there are no more results.
     * Consistency of the result is not guaranteed if objects are inserted or removed while this
     * operation is executing. All results are buffered in memory.
     *
     * `listAll()` is only available for projects using Firebase Rules Version 2.
     *
     * - Throws: An error if the list operation failed.
     * - Returns: All items and prefixes under the current `StorageReference`.
     */
    @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
    open func listAll() async throws -> StorageListResult {
      return try await StorageListResult(impl.listAll())
    }
  #endif // compiler(>=5.5) && canImport(_Concurrency)

  /**
   * List up to `maxResults` items (files) and prefixes (folders) under this StorageReference.
   *
   * "/" is treated as a path delimiter. Firebase Storage does not support unsupported object
   * paths that end with "/" or contain two consecutive "/"s. All invalid objects in GCS will be
   * filtered.
   *
   * `list(maxResults:completion:)` is only available for projects using Firebase Rules Version 2.
   *
   * - Parameters:
   *   - maxResults: The maximum number of results to return in a single page. Must be greater
   *       than 0 and at most 1000.
   *   - completion: A completion handler that will be invoked with up to `maxResults` items and
   *       prefixes under the current `StorageReference`.
   */
  @objc(listWithMaxResults:completion:)
  open func list(maxResults: Int64,
                 completion: @escaping ((_: StorageListResult?, _: Error?) -> Void)) {
    impl.list(withMaxResults: maxResults) { listResult, error in
      if error != nil {
        completion(nil, error)
      } else {
        completion(StorageListResult(listResult), error)
      }
    }
  }

  /**
   * Resumes a previous call to `list(maxResults:completion:)`, starting after a pagination token.
   * Returns the next set of items (files) and prefixes (folders) under this `StorageReference`.
   *
   * "/" is treated as a path delimiter. Storage does not support unsupported object
   * paths that end with "/" or contain two consecutive "/"s. All invalid objects in GCS will be
   * filtered.
   *
   * `list(maxResults:pageToken:completion:)`is only available for projects using Firebase Rules
   * Version 2.
   *
   * - Parameters:
   *   - maxResults: The maximum number of results to return in a single page. Must be greater
   *     than 0 and at most 1000.
   *   - pageToken: A page token from a previous call to list.
   *   - completion: A completion handler that will be invoked with the next items and prefixes
   *     under the current StorageReference.
   */
  @objc(listWithMaxResults:pageToken:completion:)
  open func list(maxResults: Int64,
                 pageToken: String,
                 completion: @escaping ((_: StorageListResult?, _: Error?) -> Void)) {
    impl.list(withMaxResults: maxResults, pageToken: pageToken) { listResult, error in
      if error != nil {
        completion(nil, error)
      } else {
        completion(StorageListResult(listResult), error)
      }
    }
  }

  // MARK: - Metadata Operations

  /**
   * Retrieves metadata associated with an object at the current path.
   * - Parameter completion A completion block which returns the object metadata on success,
   *   or an error on failure.
   */
  @objc(metadataWithCompletion:)
  open func getMetadata(completion: @escaping ((_: StorageMetadata?, _: Error?) -> Void)) {
    impl.metadata { impl, error in
      self.adaptMetadataCallback(completion: completion)(impl, error)
    }
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    /**
     * Retrieves metadata associated with an object at the current path.
     * - Throws: An error if the object metadata could not be retrieved.
     * - Returns: The object metadata on success.
     */
    @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
    open func getMetadata() async throws -> StorageMetadata {
      return try await StorageMetadata(impl: impl.metadata())
    }
  #endif // compiler(>=5.5) && canImport(_Concurrency)

  /**
   * Updates the metadata associated with an object at the current path.
   * - Parameters:
   *   - metadata: A `StorageMetadata` object with the metadata to update.
   *   - completion: A completion block which returns the `StorageMetadata` on success,
   *     or an error on failure.
   */
  @objc(updateMetadata:completion:)
  open func updateMetadata(_ metadata: StorageMetadata,
                           completion: ((_: StorageMetadata?, _: Error?) -> Void)?) {
    impl.update(metadata.impl) { impl, error in
      if let completion = completion {
        self.adaptMetadataCallback(completion: completion)(impl, error)
      }
    }
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    /**
     * Updates the metadata associated with an object at the current path.
     * - Parameter metadata A `StorageMetadata` object with the metadata to update.
     * - Throws: An error if the metadata update operation failed.
     * - Returns: The object metadata on success.
     */
    @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
    open func updateMetadata(_ metadata: StorageMetadata) async throws -> StorageMetadata {
      return try await StorageMetadata(impl: impl.update(metadata.impl))
    }
  #endif // compiler(>=5.5) && canImport(_Concurrency)

  private func adaptMetadataCallback(completion: @escaping (StorageMetadata?, Error?) -> Void) ->
    (_: FIRIMPLStorageMetadata?, _: Error?)
    -> Void {
    return { (impl: FIRIMPLStorageMetadata?, error: Error?) in
      if let impl = impl {
        completion(StorageMetadata(impl: impl), error)
      } else {
        completion(nil, error)
      }
    }
  }

  // MARK: - Delete

  /**
   * Deletes the object at the current path.
   * - Parameter completion A completion block which returns a nonnull error on failure.
   */
  @objc(deleteWithCompletion:)
  open func delete(completion: ((_: Error?) -> Void)?) {
    impl.delete(completion: completion)
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    /**
     * Deletes the object at the current path.
     * - Throws: An error if the delete operation failed.
     */
    @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
    open func delete() async throws {
      return try await impl.delete()
    }
  #endif // compiler(>=5.5) && canImport(_Concurrency)

  // MARK: - NSObject overrides

  @objc open func copy(_ zone: NSZone) -> StorageReference {
    return StorageReference(impl.copy() as! FIRIMPLStorageReference)
  }

  @objc override open func isEqual(_ object: Any?) -> Bool {
    guard let ref = object as? StorageReference else {
      return false
    }
    return impl.isEqual(ref.impl)
  }

  @objc override public var hash: Int {
    return impl.hash
  }

  @objc override public var description: String {
    return impl.description
  }

  // MARK: - Internal APIs

  private let impl: FIRIMPLStorageReference

  internal convenience init(_ impl: FIRIMPLStorageReference) {
    self.init(impl: impl, storage: Storage(app: impl.storage.app, bucket: impl.bucket))
  }

  internal init(impl: FIRIMPLStorageReference, storage: Storage) {
    self.impl = impl
    self.storage = storage
    bucket = impl.bucket
    fullPath = impl.fullPath
    name = impl.name
  }
}
