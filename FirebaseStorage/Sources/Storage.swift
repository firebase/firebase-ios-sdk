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

import FirebaseCore
import FirebaseAppCheckInterop
import FirebaseAuthInterop
#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

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
    return provider.storage(for: Storage.bucket(for: app))
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
    return provider.storage(for: Storage.bucket(for: app, urlString: url))
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
    didSet {
      maxUploadRetryInterval = Storage.computeRetryInterval(fromRetryTime: maxUploadRetryTime)
    }
  }

  /**
   * The maximum time in seconds to retry a download if a failure occurs.
   * Defaults to 10 minutes (600 seconds).
   */
  @objc public var maxDownloadRetryTime: TimeInterval {
    didSet {
      maxDownloadRetryInterval = Storage.computeRetryInterval(fromRetryTime: maxDownloadRetryTime)
    }
  }

  /**
   * The maximum time in seconds to retry operations other than upload and download if a failure occurs.
   * Defaults to 2 minutes (120 seconds).
   */
  @objc public var maxOperationRetryTime: TimeInterval {
    didSet {
      maxOperationRetryInterval = Storage.computeRetryInterval(fromRetryTime: maxOperationRetryTime)
    }
  }

  /**
   * A `DispatchQueue` that all developer callbacks are fired on. Defaults to the main queue.
   */
  @objc public var callbackQueue: DispatchQueue {
    get {
      ensureConfigured()
      guard let queue = fetcherService?.callbackQueue else {
        fatalError("Internal error: Failed to initialize fetcherService callbackQueue")
      }
      return queue
    }
    set(newValue) {
      ensureConfigured()
      fetcherService?.callbackQueue = newValue
    }
  }

  /**
   * Creates a `StorageReference` initialized at the root Firebase Storage location.
   * - Returns: An instance of `StorageReference` referencing the root of the storage bucket.
   */
  @objc open func reference() -> StorageReference {
    ensureConfigured()
    let path = StoragePath(with: storageBucket)
    return StorageReference(storage: self, path: path)
  }

  /**
   * Creates a StorageReference given a `gs://`, `http://`, or `https://` URL pointing to a
   * Firebase Storage location. For example, you can pass in an `https://` download URL retrieved from
   * `StorageReference.downloadURL(completion:)` or the `gs://` URL from
   * `StorageReference.description`.
   * - Parameter url A gs:// or https:// URL to initialize the reference with.
   * - Returns: An instance of StorageReference at the given child path.
   * - Throws: Throws a fatal error if `url` is not associated with the `FirebaseApp` used to initialize
   *     this Storage instance.
   */
  @objc open func reference(forURL url: String) -> StorageReference {
    ensureConfigured()
    do {
      let path = try StoragePath.path(string: url)

      // If no default bucket exists (empty string), accept anything.
      if storageBucket == "" {
        return StorageReference(storage: self, path: path)
      }
      // If there exists a default bucket, throw if provided a different bucket.
      if path.bucket != storageBucket {
        fatalError("Provided bucket: `\(path.bucket)` does not match the Storage bucket of the current " +
          "instance: `\(storageBucket)`")
      }
      return StorageReference(storage: self, path: path)
    } catch let StoragePathError.storagePathError(message) {
      fatalError(message)
    } catch {
      fatalError("Internal error finding StoragePath: \(error)")
    }
  }

  /**
   * Creates a StorageReference given a `gs://`, `http://`, or `https://` URL pointing to a
   * Firebase Storage location. For example, you can pass in an `https://` download URL retrieved from
   * `StorageReference.downloadURL(completion:)` or the `gs://` URL from
   * `StorageReference.description`.
   * - Parameter url A gs:// or https:// URL to initialize the reference with.
   * - Returns: An instance of StorageReference at the given child path.
   * - Throws: Throws an Error if `url` is not associated with the `FirebaseApp` used to initialize
   *     this Storage instance.
   */
  open func reference(for url: URL) throws -> StorageReference {
    ensureConfigured()
    var path: StoragePath
    do {
      path = try StoragePath.path(string: url.absoluteString)
    } catch let StoragePathError.storagePathError(message) {
      throw StorageError.pathError(message)
    } catch {
      throw StorageError.pathError("Internal error finding StoragePath: \(error)")
    }

    // If no default bucket exists (empty string), accept anything.
    if storageBucket == "" {
      return StorageReference(storage: self, path: path)
    }
    // If there exists a default bucket, throw if provided a different bucket.
    if path.bucket != storageBucket {
      throw StorageError
        .bucketMismatch("Provided bucket: `\(path.bucket)` does not match the Storage " +
          "bucket of the current instance: `\(storageBucket)`")
    }
    return StorageReference(storage: self, path: path)
  }

  /**
   * Creates a `StorageReference` initialized at a location specified by the `path` parameter.
   * - Parameter path A relative path from the root of the storage bucket,
   *     for instance @"path/to/object".
   * - Returns: An instance of `StorageReference` pointing to the given path.
   */
  @objc(referenceWithPath:) open func reference(withPath path: String) -> StorageReference {
    return reference().child(path)
  }

  /**
   * Configures the Storage SDK to use an emulated backend instead of the default remote backend.
   * This method should be called before invoking any other methods on a new instance of `Storage`.
   */
  @objc open func useEmulator(withHost host: String, port: Int) {
    guard host.count > 0 else {
      fatalError("Invalid host argument: Cannot connect to empty host.")
    }
    guard port >= 0 else {
      fatalError("Invalid port argument: Port must be greater or equal to zero.")
    }
    guard fetcherService == nil else {
      fatalError("Cannot connect to emulator after Storage SDK initialization. " +
        "Call useEmulator(host:port:) before creating a Storage " +
        "reference or trying to load data.")
    }
    usesEmulator = true
    scheme = "http"
    self.host = host
    self.port = port
  }

  // MARK: - NSObject overrides

  @objc override open func copy() -> Any {
    let storage = Storage(app: app, bucket: storageBucket)
    storage.callbackQueue = callbackQueue
    return storage
  }

  @objc override open func isEqual(_ object: Any?) -> Bool {
    guard let ref = object as? Storage else {
      return false
    }
    return app == ref.app && storageBucket == ref.storageBucket
  }

  @objc override public var hash: Int {
    return app.hash ^ callbackQueue.hashValue
  }

  // MARK: - Internal and Private APIs

  private var fetcherService: GTMSessionFetcherService?

  internal var fetcherServiceForApp: GTMSessionFetcherService {
    guard let value = fetcherService else {
      fatalError("Internal error: fetcherServiceForApp not yet configured.")
    }
    return value
  }

  internal let dispatchQueue: DispatchQueue

  internal init(app: FirebaseApp, bucket: String) {
    self.app = app
    auth = ComponentType<AuthInterop>.instance(for: AuthInterop.self,
                                               in: app.container)
    appCheck = ComponentType<AppCheckInterop>.instance(for: AppCheckInterop.self,
                                                       in: app.container)
    storageBucket = bucket
    host = "firebasestorage.googleapis.com"
    scheme = "https"
    port = 443
    fetcherService = nil // Configured in `ensureConfigured()`
    // Must be a serial queue.
    dispatchQueue = DispatchQueue(label: "com.google.firebase.storage")
    maxDownloadRetryTime = 600.0
    maxDownloadRetryInterval = Storage.computeRetryInterval(fromRetryTime: maxDownloadRetryTime)
    maxOperationRetryTime = 120.0
    maxOperationRetryInterval = Storage.computeRetryInterval(fromRetryTime: maxOperationRetryTime)
    maxUploadRetryTime = 600.0
    maxUploadRetryInterval = Storage.computeRetryInterval(fromRetryTime: maxUploadRetryTime)
  }

  /// Map of apps to a dictionary of buckets to GTMSessionFetcherService.
  private static let fetcherServiceLock = NSObject()
  private static var fetcherServiceMap: [String: [String: GTMSessionFetcherService]] = [:]
  private static var retryWhenOffline: GTMSessionFetcherRetryBlock = {
    (suggestedWillRetry: Bool,
     error: Error?,
     response: @escaping GTMSessionFetcherRetryResponse) in
      var shouldRetry = suggestedWillRetry
      // GTMSessionFetcher does not consider being offline a retryable error, but we do, so we
      // special-case it here.
      if !shouldRetry, error != nil {
        shouldRetry = (error as? NSError)?.code == URLError.notConnectedToInternet.rawValue
      }
      response(shouldRetry)
  }

  private static func initFetcherServiceForApp(_ app: FirebaseApp,
                                               _ bucket: String,
                                               _ auth: AuthInterop,
                                               _ appCheck: AppCheckInterop)
    -> GTMSessionFetcherService {
    objc_sync_enter(fetcherServiceLock)
    defer { objc_sync_exit(fetcherServiceLock) }
    var bucketMap = fetcherServiceMap[app.name]
    if bucketMap == nil {
      bucketMap = [:]
      fetcherServiceMap[app.name] = bucketMap
    }
    var fetcherService = bucketMap?[bucket]
    if fetcherService == nil {
      fetcherService = GTMSessionFetcherService()
      fetcherService?.isRetryEnabled = true
      fetcherService?.retryBlock = retryWhenOffline
      fetcherService?.allowLocalhostRequest = true
      let authorizer = StorageTokenAuthorizer(
        googleAppID: app.options.googleAppID,
        fetcherService: fetcherService!,
        authProvider: auth,
        appCheck: appCheck
      )
      fetcherService?.authorizer = authorizer
      bucketMap?[bucket] = fetcherService
    }
    return fetcherService!
  }

  private let auth: AuthInterop
  private let appCheck: AppCheckInterop
  private let storageBucket: String
  private var usesEmulator: Bool = false
  internal var host: String
  internal var scheme: String
  internal var port: Int
  internal var maxDownloadRetryInterval: TimeInterval
  internal var maxOperationRetryInterval: TimeInterval
  internal var maxUploadRetryInterval: TimeInterval

  /**
   * Performs a crude translation of the user provided timeouts to the retry intervals that
   * GTMSessionFetcher accepts. GTMSessionFetcher times out operations if the time between individual
   * retry attempts exceed a certain threshold, while our API contract looks at the total observed
   * time of the operation (i.e. the sum of all retries).
   * @param retryTime A timeout that caps the sum of all retry attempts
   * @return A timeout that caps the timeout of the last retry attempt
   */
  internal static func computeRetryInterval(fromRetryTime retryTime: TimeInterval) -> TimeInterval {
    // GTMSessionFetcher's retry starts at 1 second and then doubles every time. We use this
    // information to compute a best-effort estimate of what to translate the user provided retry
    // time into.
    // Note that this is the same as 2 << (log2(retryTime) - 1), but deemed more readable.
    var lastInterval = 1.0
    var sumOfAllIntervals = 1.0

    while sumOfAllIntervals < retryTime {
      lastInterval *= 2
      sumOfAllIntervals += lastInterval
    }
    return lastInterval
  }

  /**
   * Configures the storage instance. Freezes the host setting.
   */
  private func ensureConfigured() {
    guard fetcherService == nil else {
      return
    }
    fetcherService = Storage.initFetcherServiceForApp(app, storageBucket, auth, appCheck)
    if usesEmulator {
      fetcherService?.allowLocalhostRequest = true
      fetcherService?.allowedInsecureSchemes = ["http"]
    }
  }

  private static func bucket(for app: FirebaseApp) -> String {
    guard let bucket = app.options.storageBucket else {
      fatalError("No default Storage bucket found. Did you configure Firebase Storage properly?")
    }
    if bucket == "" {
      return Storage.bucket(for: app, urlString: "")
    } else {
      return Storage.bucket(for: app, urlString: "gs://\(bucket)/")
    }
  }

  private static func bucket(for app: FirebaseApp, urlString: String) -> String {
    if urlString == "" {
      return ""
    } else {
      guard let path = try? StoragePath.path(GSURI: urlString),
            path.object == nil || path.object == "" else {
        fatalError("Internal Error: Storage bucket cannot be initialized with a path")
      }
      return path.bucket
    }
  }
}
