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
import FirebaseCore
import FirebaseAppCheckInterop
import FirebaseAuthInterop

// Avoids exposing internal FirebaseCore APIs to Swift users.
@_implementationOnly import FirebaseCoreExtension

/**
 * Firebase Storage is a service that supports uploading and downloading binary objects,
 * such as images, videos, and other files to Google Cloud Storage. Instances of `Storage`
 * are not thread-safe.
 *
 * If you call `Storage.storage()`, the instance will initialize with the default `FirebaseApp`,
 * `FirebaseApp.app()`, and the storage location will come from the provided
 * `GoogleService-Info.plist`.
 *
 * If you provide a custom instance of `FirebaseApp`,
 * the storage location will be specified via the `FirebaseOptions.storageBucket` property.
 */
@objc(FIRStorage) open class Storage: NSObject {
  // MARK: - Public APIs

  /**
   * The default `Storage` instance.
   * - Returns: An instance of `Storage`, configured with the default `FirebaseApp`.
   */
  @objc(storage) open class func storage() -> Storage {
    return storage(app: FirebaseApp.app()!)
  }

  /**
   * A method used to create `Storage` instances initialized with a custom storage bucket URL.
   * Any `StorageReferences` generated from this instance of `Storage` will reference files
   * and directories within the specified bucket.
   * - Parameter url The `gs://` URL to your Firebase Storage bucket.
   * - Returns: A `Storage` instance, configured with the custom storage bucket.
   */
  @objc(storageWithURL:) open class func storage(url: String) -> Storage {
    return storage(app: FirebaseApp.app()!, url: url)
  }

  /**
   * Creates an instance of `Storage`, configured with a custom `FirebaseApp`. `StorageReference`s
   * generated from a resulting instance will reference files in the Firebase project
   * associated with custom `FirebaseApp`.
   * - Parameter app The custom `FirebaseApp` used for initialization.
   * - Returns: A `Storage` instance, configured with the custom `FirebaseApp`.
   */
  @objc(storageForApp:) open class func storage(app: FirebaseApp) -> Storage {
    let provider = ComponentType<StorageProvider>.instance(for: StorageProvider.self,
                                                           in: app.container)
    return provider.storage(for: FIRIMPLStorage.bucket(for: app))
  }

  /**
   * Creates an instance of `Storage`, configured with a custom `FirebaseApp` and a custom storage
   * bucket URL.
   * - Parameters:
   *   - app: The custom `FirebaseApp` used for initialization.
   *   - url: The `gs://` url to your Firebase Storage bucket.
   * - Returns: the `Storage` instance, configured with the custom `FirebaseApp` and storage bucket URL.
   */
  @objc(storageForApp:URL:)
  open class func storage(app: FirebaseApp, url: String) -> Storage {
    let provider = ComponentType<StorageProvider>.instance(for: StorageProvider.self,
                                                           in: app.container)
    return provider.storage(for: FIRIMPLStorage.bucket(for: app, url: url))
  }

  /**
   * The `FirebaseApp` associated with this Storage instance.
   */
  @objc public let app: FirebaseApp

  /**
   * The maximum time in seconds to retry an upload if a failure occurs.
   * Defaults to 10 minutes (600 seconds).
   */
  @objc public var maxUploadRetryTime: TimeInterval {
    get {
      return impl.maxUploadRetryTime
    }
    set(newValue) {
      impl.maxUploadRetryTime = newValue
    }
  }

  /**
   * The maximum time in seconds to retry a download if a failure occurs.
   * Defaults to 10 minutes (600 seconds).
   */
  @objc public var maxDownloadRetryTime: TimeInterval {
    get {
      return impl.maxDownloadRetryTime
    }
    set(newValue) {
      impl.maxDownloadRetryTime = newValue
    }
  }

  /**
   * The maximum time in seconds to retry operations other than upload and download if a failure occurs.
   * Defaults to 2 minutes (120 seconds).
   */
  @objc public var maxOperationRetryTime: TimeInterval {
    get {
      return impl.maxOperationRetryTime
    }
    set(newValue) {
      impl.maxOperationRetryTime = newValue
    }
  }

  /**
   * A `DispatchQueue` that all developer callbacks are fired on. Defaults to the main queue.
   */
  @objc public var callbackQueue: DispatchQueue {
    get {
      return impl.callbackQueue
    }
    set(newValue) {
      impl.callbackQueue = newValue
    }
  }

  /**
   * Creates a `StorageReference` initialized at the root Firebase Storage location.
   * - Returns: An instance of `StorageReference` referencing the root of the storage bucket.
   */
  @objc open func reference() -> StorageReference {
    return StorageReference(impl: impl.reference(), storage: self)
  }

  /**
   * Creates a StorageReference given a `gs://` or `https://` URL pointing to a Firebase Storage
   * location. For example, you can pass in an `https://` download URL retrieved from
   * `StorageReference.downloadURL(completion:)` or the `gs://` URL from
   * `StorageReference.description`.
   * - Parameter url A gs:// or https:// URL to initialize the reference with.
   * - Returns: An instance of StorageReference at the given child path.
   * - Throws: Throws a fatal error if `url` is not associated with the `FirebaseApp` used to initialize
   *     this Storage instance.
   */
  @objc open func reference(forURL url: String) -> StorageReference {
    return StorageReference(impl: impl.reference(forURL: url), storage: self)
  }

  /**
   * Creates a `StorageReference` initialized at a location specified by the `path` parameter.
   * - Parameter path A relative path from the root of the storage bucket,
   *     for instance @"path/to/object".
   * - Returns: An instance of `StorageReference` pointing to the given path.
   */
  @objc(referenceWithPath:) open func reference(withPath path: String) -> StorageReference {
    return StorageReference(impl: impl.reference(withPath: path), storage: self)
  }

  /**
   * Configures the Storage SDK to use an emulated backend instead of the default remote backend.
   * This method should be called before invoking any other methods on a new instance of `Storage`.
   */
  @objc open func useEmulator(withHost host: String, port: Int) {
    impl.useEmulator(withHost: host, port: port)
  }

  // MARK: - NSObject overrides

  @objc override open func copy() -> Any {
    return Storage(copy: self)
  }

  @objc override open func isEqual(_ object: Any?) -> Bool {
    guard let ref = object as? Storage else {
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

  private let impl: FIRIMPLStorage

  internal init(app: FirebaseApp, bucket: String) {
    let auth = ComponentType<AuthInterop>.instance(for: AuthInterop.self,
                                                   in: app.container)
    let appCheck = ComponentType<AppCheckInterop>.instance(for: AppCheckInterop.self,
                                                           in: app.container)
    impl = FIRIMPLStorage(app: app, bucket: bucket, auth: auth, appCheck: appCheck)
    self.app = impl.app
  }

  internal init(copy: Storage) {
    impl = copy.impl.copy() as! FIRIMPLStorage
    app = impl.app
  }
}
