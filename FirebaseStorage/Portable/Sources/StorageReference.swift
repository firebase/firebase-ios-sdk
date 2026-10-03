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

public import Foundation

/// **[Experimental]** Represents a reference to a Google Cloud Storage object.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public final class StorageReference: Sendable, Equatable, Hashable, CustomStringConvertible {
  /// **[Experimental]** The `Storage` service object that created this reference.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public let storage: Storage

  package let path: StoragePath

  package init(storage: Storage, path: StoragePath) {
    self.storage = storage
    self.path = path
  }

  /// **[Experimental]** The name of the Google Cloud Storage bucket associated with this
  /// reference.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public var bucket: String {
    path.bucket
  }

  /// **[Experimental]** The full path to this object, excluding the bucket name.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public var fullPath: String {
    path.object ?? ""
  }

  /// **[Experimental]** The short name of the object associated with this reference.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public var name: String {
    guard let object = path.object, !object.isEmpty else {
      return ""
    }
    return object.split(separator: "/").last.map(String.init) ?? ""
  }

  /// **[Experimental]** Creates a new `StorageReference` pointing to the root object.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Returns: A new `StorageReference` pointing to the root of the bucket.
  public func root() -> StorageReference {
    StorageReference(storage: storage, path: path.root())
  }

  /// **[Experimental]** Creates a new `StorageReference` pointing to the parent of the current
  /// reference, or `nil` if this reference points to the root.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Returns: A new `StorageReference` pointing to the parent path, or `nil`.
  public func parent() -> StorageReference? {
    guard let parentPath = path.parent() else {
      return nil
    }
    return StorageReference(storage: storage, path: parentPath)
  }

  /// **[Experimental]** Creates a new `StorageReference` pointing to a child path of the current
  /// reference.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameter path: The relative child path to append.
  /// - Returns: A new `StorageReference` pointing to the child location.
  public func child(_ path: String) -> StorageReference {
    StorageReference(storage: storage, path: self.path.child(path))
  }

  /// **[Experimental]** Asynchronously uploads a file to the currently specified
  /// `StorageReference`.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameters:
  ///   - url: A `URL` representing the system file path of the object to be uploaded.
  ///   - metadata: Optional `StorageMetadata` containing additional information about the object.
  ///   - onProgress: An optional closure called as upload progress updates.
  /// - Returns: `StorageMetadata` for the uploaded object.
  /// - Throws: An error because file uploads are not supported in the portable Storage stub.
  public func putFileAsync(from url: URL,
                           metadata: StorageMetadata? = nil,
                           onProgress: ((Progress?) -> Void)? = nil) async throws
    -> StorageMetadata {
    _ = (url, metadata, onProgress)
    throw NSError(
      domain: "FIRStorageErrorDomain",
      code: -13000,
      userInfo: [
        NSLocalizedDescriptionKey:
          "putFileAsync(from:metadata:onProgress:) is not supported in portable FirebaseStorage.",
      ]
    )
  }

  // MARK: - CustomStringConvertible, Equatable, Hashable

  public var description: String {
    path.stringValue()
  }

  public static func == (lhs: StorageReference, rhs: StorageReference) -> Bool {
    lhs.storage == rhs.storage && lhs.path == rhs.path
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(storage)
    hasher.combine(path)
  }
}
