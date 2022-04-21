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
import FirebaseCoreExtension
import FirebaseAppCheckInterop
import FirebaseAuthInterop

/**
 * FirebaseStorage is a service that supports uploading and downloading binary objects,
 * such as images, videos, and other files to Google Cloud Storage.
 *
 * If you call `FirebaseStorage.storage()`, the instance will initialize with the default FirebaseApp,
 * `FirebaseApp.app()`, and the storage location will come from the provided
 * GoogleService-Info.plist.
 *
 * If you provide a custom instance of FirebaseApp,
 * the storage location will be specified via the FirebaseOptions#storageBucket property.
 */
@objc(FIRStorage) open class Storage: NSObject {
  // MARK: - Public APIs

  /**
   * An instance of FirebaseStorage, configured with the default FirebaseApp.
   * @return the FirebaseStorage instance, configured with the default FirebaseApp.
   */
  @objc(storage) open class func storage() -> Storage {
    return storage(app: FirebaseApp.app()!)
  }

  /**
   * An instance of FirebaseStorage, configured with a custom storage bucket @a url.
   * @param url The gs:// url to your Firebase Storage Bucket.
   * @return the FirebaseStorage instance, configured with the custom FirebaseApp.
   */
  @objc(storageWithURL:) open class func storage(url: String) -> Storage {
    return storage(app: FirebaseApp.app()!, url: url)
  }

  /**
   * Creates an instance of FirebaseStorage, configured with the custom FirebaseApp @a app.
   * @param app The custom FirebaseApp used for initialization.
   * @return the FirebaseStorage instance, configured with the custom FirebaseApp.
   */
  @objc(storageForApp:) open class func storage(app: FirebaseApp) -> Storage {
    let provider = ComponentType<StorageProvider>.instance(for: StorageProvider.self,
                                                           in: app.container)
    return provider.storage(for: FIRIMPLStorage.bucket(for: app))
  }

  /**
   * Creates an instance of FirebaseStorage, configured with a custom FirebaseApp @a app and a custom storage
   * bucket @a url.
   * @param app The custom FirebaseApp used for initialization.
   * @param url The gs:// url to your Firebase Storage Bucket.
   * @return the FirebaseStorage instance, configured with the custom FirebaseApp.
   */
  @objc(storageForApp:URL:)
  open class func storage(app: FirebaseApp, url: String) -> Storage {
    let provider = ComponentType<StorageProvider>.instance(for: StorageProvider.self,
                                                           in: app.container)
    return provider.storage(for: FIRIMPLStorage.bucket(for: app, url: url))
  }

  /**
   * The Firebase App associated with this Firebase Storage instance.
   */
  @objc public let app: FirebaseApp

  /**
   * Maximum time in seconds to retry an upload if a failure occurs.
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
   * Maximum time in seconds to retry a download if a failure occurs.
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
   * Maximum time in seconds to retry operations other than upload and download if a failure occurs.
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
   * Queue that all developer callbacks are fired on. Defaults to the main queue.
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
   * Creates a StorageReference initialized at the root Firebase Storage location.
   * @return An instance of StorageReference initialized at the root.
   */
  @objc open func reference() -> StorageReference {
    return StorageReference(impl: impl.reference(), storage: self)
  }

  /**
   * Creates a StorageReference given a gs:// or https:// URL pointing to a Firebase Storage
   * location. For example, you can pass in an https:// download URL retrieved from
   * [StorageReference downloadURLWithCompletion] or the gs:// URI from
   * [StorageReference description].
   * @param string A gs:// or https:// URL to initialize the reference with.
   * @return An instance of StorageReference at the given child path.
   * @throws Throws an exception if passed in URL is not associated with the FirebaseApp used to initialize
   * this FirebaseStorage.
   */
  @objc open func reference(forURL string: String) -> StorageReference {
    return StorageReference(impl: impl.reference(forURL: string), storage: self)
  }

  /**
   * Creates a StorageReference initialized at a child Firebase Storage location.
   * @param string A relative path from the root to initialize the reference with,
   * for instance @"path/to/object".
   * @return An instance of StorageReference at the given child path.
   */
  @objc(referenceWithPath:) open func reference(withPath string: String) -> StorageReference {
    return StorageReference(impl: impl.reference(withPath: string), storage: self)
  }

  /**
   * Configures the Storage SDK to use an emulated backend instead of the default remote backend.
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
