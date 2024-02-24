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

#if canImport(Combine) && swift(>=5.0)

  import Combine
  import FirebaseStorage
  import Foundation

  @available(swift 5.0)
  @available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, *)
  public extension StorageReference {
    // MARK: - Uploads

    /// Asynchronously uploads data to the currently specified `StorageReference`.
    /// This is not recommended for large files, and one should instead upload a file from disk.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///   - uploadData: The Data to upload.
    ///   - metadata: metadata `StorageMetadata` containing additional information (MIME type, etc.)
    ///
    /// - Returns: A publisher emitting a `StorageMetadata` instance. The publisher will emit on the
    /// *main* thread.
    @discardableResult
    func putData(_ data: Data,
                 metadata: StorageMetadata? = nil) -> Future<StorageMetadata, Error> {
      var task: StorageUploadTask?
      return Future<StorageMetadata, Error> { promise in
        task = self.putData(data, metadata: metadata) { result in
          promise(result)
        }
      }
      .handleEvents(receiveCancel: {
        task?.cancel()
      })
      .upstream
    }

    /// Asynchronously uploads a file to the currently specified `StorageReference`.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///   - fileURL: A `URL` representing the system file path of the object to be uploaded.
    ///   - metadata: `StorageMetadata` containing additional information (MIME type, etc.) about
    /// the object being uploaded.
    ///
    /// - Returns: A publisher emitting a `StorageMetadata` instance. The publisher will emit on the
    /// *main* thread.
    @discardableResult
    func putFile(from fileURL: URL,
                 metadata: StorageMetadata? = nil)
      -> Future<StorageMetadata, Error> {
      var task: StorageUploadTask?
      return Future<StorageMetadata, Error> { promise in
        task = self.putFile(from: fileURL, metadata: metadata) { result in
          promise(result)
        }
      }
      .handleEvents(receiveCancel: {
        task?.cancel()
      })
      .upstream
    }

    // MARK: - Downloads

    /// Asynchronously downloads the object at the `StorageReference` to an `Data` object in memory.
    /// An `Data` of the provided max size will be allocated, so ensure that the device has enough
    /// free
    /// memory to complete the download. For downloading large files, `writeToFile` may be a better
    /// option.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///   - size: The maximum size in bytes to download. If the download exceeds this size,
    ///     the task will be cancelled and an error will be returned.
    ///
    /// - Returns: A publisher emitting a `Data` instance. The publisher will emit on the *main*
    /// thread.
    @discardableResult
    func getData(maxSize size: Int64) -> Future<Data, Error> {
      var task: StorageDownloadTask?
      return Future<Data, Error> { promise in
        task = self.getData(maxSize: size) { result in
          promise(result)
        }
      }
      .handleEvents(receiveCancel: {
        task?.cancel()
      })
      .upstream
    }

    /// Asynchronously downloads the object at the current path to a specified system filepath.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///   - fileURL: A file system URL representing the path the object should be downloaded to.
    ///
    /// - Returns: A publisher emitting a `URL`  pointing to the file path of the downloaded file
    ///   on success. The publisher will emit on the *main* thread.
    @discardableResult
    func write(toFile fileURL: URL) -> Future<URL, Error> {
      var task: StorageDownloadTask?
      return Future<URL, Error> { promise in
        task = self.write(toFile: fileURL) { result in
          promise(result)
        }
      }
      .handleEvents(receiveCancel: {
        task?.cancel()
      })
      .upstream
    }

    /// Asynchronously retrieves a long lived download URL with a revokable token.
    /// This can be used to share the file with others, but can be revoked by a developer
    /// in the Firebase Console if desired.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Returns: A publisher emitting a `URL` instance. The publisher will emit on the *main*
    /// thread.
    @discardableResult
    func downloadURL() -> Future<URL, Error> {
      Future<URL, Error> { promise in
        self.downloadURL { result in
          promise(result)
        }
      }
    }

    // MARK: - List Support

    /// List all items (files) and prefixes (folders) under this `StorageReference`.
    ///
    /// This is a helper method for calling `list()` repeatedly until there are no more results.
    /// Consistency of the result is not guaranteed if objects are inserted or removed while this
    /// operation is executing. All results are buffered in memory.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Remark:
    ///    `listAll` is only available for projects using Firebase Rules Version 2.
    ///
    /// - Returns: A publisher emitting a `StorageListResult` instance. The publisher will emit on
    /// the *main* thread.
    @discardableResult
    func listAll() -> Future<StorageListResult, Error> {
      Future<StorageListResult, Error> { promise in
        self.listAll { result in
          promise(result)
        }
      }
    }

    /// List up to `maxResults` items (files) and prefixes (folders) under this `StorageReference`.
    ///
    /// Note that "/" is treated as a path delimiter. Firebase Storage does not support unsupported
    /// object
    /// paths that end with "/" or contain two consecutive "/"s. All invalid objects in Firebase
    /// Storage will be
    /// filtered.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///     - maxResults: The maximum number of results to return in a single page. Must be greater
    ///       than 0 and at most 1000.
    ///
    /// - Remark:
    ///    `list(maxResults:)` is only available for projects using Firebase Rules Version 2.
    ///
    /// - Returns: A publisher emitting a `StorageListResult` instance. The publisher will emit on
    /// the *main* thread.
    @discardableResult
    func list(maxResults: Int64) -> Future<StorageListResult, Error> {
      Future<StorageListResult, Error> { promise in
        self.list(maxResults: maxResults) { result in
          promise(result)
        }
      }
    }

    /// Resumes a previous call to `list(maxResults:)`, starting after a pagination token.
    /// Returns the next set of items (files) and prefixes (folders) under this `StorageReference.
    ///
    /// Note that "/" is treated as a path delimiter. Firebase Storage does not support unsupported
    /// object
    /// paths that end with "/" or contain two consecutive "/"s. All invalid objects in Firebase
    /// Storage
    /// will be filtered out.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///   - maxResults: The maximum number of results to return in a single page. Must be greater
    ///       than 0 and at most 1000.
    ///   - pageToken: A page token from a previous call to list.
    ///
    /// - Remark:
    ///    `list(maxResults:pageToken:)` is only available for projects using Firebase Rules Version
    /// 2.
    ///
    /// - Returns: A publisher emitting a `StorageListResult` instance. The publisher will emit on
    /// the *main* thread.
    @discardableResult
    func list(maxResults: Int64, pageToken: String) -> Future<StorageListResult, Error> {
      Future<StorageListResult, Error> { promise in
        self.list(maxResults: maxResults, pageToken: pageToken) { result in
          promise(result)
        }
      }
    }

    // MARK: - Metadata Operations

    /// Retrieves metadata associated with an object at the current path.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Returns: A publisher emitting a `StorageMetadata` instance. The publisher will emit on the
    /// *main* thread.
    @discardableResult
    func getMetadata() -> Future<StorageMetadata, Error> {
      Future<StorageMetadata, Error> { promise in
        self.getMetadata { result in
          promise(result)
        }
      }
    }

    /// Updates the metadata associated with an object at the current path.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///   - metadata: A `StorageMetadata` object with the metadata to update.
    ///
    /// - Returns: A publisher emitting a `StorageMetadata` instance. The publisher will emit on the
    /// *main* thread.
    @discardableResult
    func updateMetadata(_ metadata: StorageMetadata) -> Future<StorageMetadata, Error> {
      Future<StorageMetadata, Error> { promise in
        self.updateMetadata(metadata) { result in
          promise(result)
        }
      }
    }

    // MARK: - Delete

    /// Deletes the object at the current path.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Returns: A publisher that emits whether the call was successful or not. The publisher will
    /// emit on the *main* thread.
    @discardableResult
    func delete() -> Future<Bool, Error> {
      Future<Bool, Error> { promise in
        self.delete { error in
          if let error {
            promise(.failure(error))
          } else {
            promise(.success(true))
          }
        }
      }
    }
  }

#endif // canImport(Combine) && swift(>=5.0)
