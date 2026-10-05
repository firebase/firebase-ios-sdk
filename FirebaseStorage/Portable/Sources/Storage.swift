// Copyright 2026 Google LLC
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

public import FirebaseCore
public import Foundation
private import FirebaseCoreInternal

/// **[Experimental]** A service that supports referencing objects in Google Cloud Storage.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public final class Storage: Sendable, Equatable, Hashable {
  private static let instances = UnfairLock<[String: Storage]>([:])

  /// **[Experimental]** The `FirebaseApp` associated with this `Storage` instance.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public let app: FirebaseApp

  /// The resolved Google Cloud Storage bucket name.
  package let storageBucket: String

  package init(app: FirebaseApp, bucket: String) {
    self.app = app
    storageBucket = bucket
  }

  // MARK: - Factory Methods

  /// **[Experimental]** Returns the `Storage` instance for the default `FirebaseApp`.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Returns: A `Storage` instance configured with the default `FirebaseApp`.
  public static func storage() -> Storage {
    guard let app = FirebaseApp.app() else {
      preconditionFailure(
        "FirebaseApp.configure() must be called before accessing Storage.storage()."
      )
    }
    return storage(app: app)
  }

  /// **[Experimental]** Returns a `Storage` instance initialized with a custom bucket URL.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameter url: The `gs://` URL to your Firebase Storage bucket.
  /// - Returns: A `Storage` instance configured with the custom bucket.
  public static func storage(url: String) -> Storage {
    guard let app = FirebaseApp.app() else {
      preconditionFailure(
        "FirebaseApp.configure() must be called before accessing Storage.storage(url:)."
      )
    }
    return storage(app: app, url: url)
  }

  /// **[Experimental]** Returns the `Storage` instance for the specified `FirebaseApp`.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameter app: The `FirebaseApp` used for initialization.
  /// - Returns: A `Storage` instance configured with `app`.
  public static func storage(app: FirebaseApp) -> Storage {
    storage(app: app, bucket: bucket(for: app))
  }

  /// **[Experimental]** Returns a `Storage` instance for the specified `FirebaseApp` and custom
  /// bucket URL.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameters:
  ///   - app: The `FirebaseApp` used for initialization.
  ///   - url: The `gs://` URL to your Firebase Storage bucket.
  /// - Returns: A `Storage` instance configured with `app` and `url`.
  public static func storage(app: FirebaseApp, url: String) -> Storage {
    storage(app: app, bucket: bucket(for: app, urlString: url))
  }

  private static func storage(app: FirebaseApp, bucket: String) -> Storage {
    let key = "\(app.name)|\(bucket)"
    return instances.withLock { cache in
      if let existing = cache[key] {
        return existing
      }
      let created = Storage(app: app, bucket: bucket)
      cache[key] = created
      return created
    }
  }

  // MARK: - References

  /// **[Experimental]** Creates a `StorageReference` initialized at the root of the storage bucket.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Returns: A `StorageReference` referencing the root of the bucket.
  public func reference() -> StorageReference {
    StorageReference(storage: self, path: StoragePath(with: storageBucket))
  }

  /// **[Experimental]** Creates a `StorageReference` initialized at a child path of the storage
  /// bucket.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameter path: A relative path from the root of the storage bucket.
  /// - Returns: A `StorageReference` pointing to `path`.
  public func reference(withPath path: String) -> StorageReference {
    reference().child(path)
  }

  /// **[Experimental]** Creates a `StorageReference` from a `gs://`, `http://`, or `https://` URL.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameter url: A `gs://`, `http://`, or `https://` URL string.
  /// - Returns: A `StorageReference` at the parsed path.
  public func reference(forURL url: String) -> StorageReference {
    do {
      let path = try StoragePath.path(string: url)
      if !storageBucket.isEmpty, path.bucket != storageBucket {
        fatalError(
          "Provided bucket: `\(path.bucket)` does not match the Storage bucket of the current " +
            "instance: `\(storageBucket)`"
        )
      }
      return StorageReference(storage: self, path: path)
    } catch let StoragePathError.invalidURI(message) {
      fatalError(message)
    } catch {
      fatalError("Internal error finding StoragePath: \(error)")
    }
  }

  /// **[Experimental]** Creates a `StorageReference` from a `gs://`, `http://`, or `https://` URL.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameter url: A `gs://`, `http://`, or `https://` `URL`.
  /// - Returns: A `StorageReference` at the parsed path.
  /// - Throws: An error if `url` is invalid or refers to a different bucket.
  public func reference(for url: URL) throws -> StorageReference {
    let path = try StoragePath.path(string: url.absoluteString)
    if !storageBucket.isEmpty, path.bucket != storageBucket {
      throw NSError(
        domain: "FIRStorageErrorDomain",
        code: -13010,
        userInfo: [
          NSLocalizedDescriptionKey:
            "Provided bucket: `\(path.bucket)` does not match the Storage bucket of the current " +
            "instance: `\(storageBucket)`",
        ]
      )
    }
    return StorageReference(storage: self, path: path)
  }

  // MARK: - Equatable & Hashable

  public static func == (lhs: Storage, rhs: Storage) -> Bool {
    lhs.app == rhs.app && lhs.storageBucket == rhs.storageBucket
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(app)
    hasher.combine(storageBucket)
  }

  // MARK: - Private Helpers

  private static func bucket(for app: FirebaseApp) -> String {
    guard let bucket = app.options.storageBucket else {
      fatalError("No default Storage bucket found. Did you configure Firebase Storage properly?")
    }
    if bucket.isEmpty {
      return ""
    }
    return self.bucket(for: app, urlString: "gs://\(bucket)/")
  }

  private static func bucket(for _: FirebaseApp, urlString: String) -> String {
    if urlString.isEmpty {
      return ""
    }
    guard let path = try? StoragePath.path(gsURI: urlString),
          path.object == nil || path.object == "" else {
      fatalError("Internal Error: Storage bucket cannot be initialized with a path")
    }
    return path.bucket
  }
}
