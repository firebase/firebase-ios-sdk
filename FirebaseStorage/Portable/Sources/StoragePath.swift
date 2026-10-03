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

import Foundation

/// Errors thrown while parsing Cloud Storage URIs or URLs.
package enum StoragePathError: Error, Sendable, Equatable {
  case invalidURI(String)
}

/// Represents a canonical path in Google Cloud Storage (`gs://bucket/path/to/object`).
package struct StoragePath: Sendable, Equatable, Hashable {
  /// The Google Cloud Storage bucket name.
  package let bucket: String

  /// The canonical object path within `bucket`, or `nil` when referencing the bucket root.
  package let object: String?

  /// Creates a `StoragePath` for the given bucket and optional object path.
  ///
  /// - Parameters:
  ///   - bucket: The Google Cloud Storage bucket name.
  ///   - object: The object path within the bucket.
  package init(with bucket: String, object: String? = nil) {
    self.bucket = bucket
    if let object {
      self.object = StoragePath.standardizedPath(object)
    } else {
      self.object = nil
    }
  }

  /// Parses a `gs://`, `http://`, or `https://` URI/URL string into a `StoragePath`.
  ///
  /// - Parameter string: The URI or URL string to parse.
  /// - Returns: The parsed `StoragePath`.
  /// - Throws: `StoragePathError.invalidURI` if `string` is not a valid Cloud Storage URI/URL.
  package static func path(string: String) throws -> StoragePath {
    if string.hasPrefix("gs://") {
      return try path(gsURI: string)
    } else if string.hasPrefix("http://") || string.hasPrefix("https://") {
      return try path(httpURL: string)
    } else {
      throw StoragePathError.invalidURI(
        "Internal error: URL scheme must be one of gs://, http://, or https://"
      )
    }
  }

  /// Parses a `gs://bucket/path/to/object` URI string into a `StoragePath`.
  ///
  /// - Parameter uriString: The `gs://` URI string to parse.
  /// - Returns: The parsed `StoragePath`.
  /// - Throws: `StoragePathError.invalidURI` if `uriString` is not a valid `gs://` URI.
  package static func path(gsURI uriString: String) throws -> StoragePath {
    guard uriString.hasPrefix("gs://") else {
      throw StoragePathError.invalidURI(
        "Internal error: URI must be in the form of gs://<bucket>/<path/to/object>"
      )
    }
    let bucketObject = uriString.dropFirst("gs://".count)
    if bucketObject.contains("/") {
      let parts = bucketObject.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
      if let bucketName = parts.first, !bucketName.isEmpty {
        let objectPath = parts.count > 1 ? String(parts[1]) : nil
        return StoragePath(with: String(bucketName), object: objectPath)
      }
    } else if !bucketObject.isEmpty {
      return StoragePath(with: String(bucketObject))
    }
    throw StoragePathError.invalidURI(
      "Internal error: URI must be in the form of gs://<bucket>/<path/to/object>"
    )
  }

  /// Parses an `http[s]://<host>/v0/b/<bucket>/o/<path>` URL string into a `StoragePath`.
  private static func path(httpURL urlString: String) throws -> StoragePath {
    guard let url = URL(string: urlString) else {
      throw StoragePathError.invalidURI(
        "Internal error: URL must be in the form of " +
          "http[s]://<host>/v0/b/<bucket>/o/<path/to/object>[?token=signed_url_params]"
      )
    }
    let pathComponents = url.pathComponents
    guard pathComponents.count >= 4,
          pathComponents[1] == "v0",
          pathComponents[2] == "b" else {
      throw StoragePathError.invalidURI(
        "Internal error: URL must be in the form of " +
          "http[s]://<host>/v0/b/<bucket>/o/<path/to/object>[?token=signed_url_params]"
      )
    }
    let bucketName = pathComponents[3]
    guard pathComponents.count > 4 else {
      return StoragePath(with: bucketName)
    }
    guard pathComponents[4] == "o" else {
      throw StoragePathError.invalidURI(
        "Internal error: URL must be in the form of " +
          "http[s]://<host>/v0/b/<bucket>/o/<path/to/object>[?token=signed_url_params]"
      )
    }
    guard pathComponents.count > 5 else {
      return StoragePath(with: bucketName)
    }
    let objectName = pathComponents[5...].joined(separator: "/")
    return StoragePath(with: bucketName, object: objectName)
  }

  /// Removes leading and trailing slashes and collapses consecutive slashes.
  private static func standardizedPath(_ string: String) -> String {
    string
      .split(separator: "/", omittingEmptySubsequences: true)
      .joined(separator: "/")
  }

  /// Returns a new `StoragePath` with `childPath` appended.
  package func child(_ childPath: String) -> StoragePath {
    let trimmed = StoragePath.standardizedPath(childPath)
    guard !trimmed.isEmpty else {
      return self
    }
    if let object, !object.isEmpty {
      return StoragePath(with: bucket, object: "\(object)/\(trimmed)")
    }
    return StoragePath(with: bucket, object: trimmed)
  }

  /// Returns the parent `StoragePath`, or `nil` if this path is at the root of the bucket.
  package func parent() -> StoragePath? {
    guard let object, !object.isEmpty else {
      return nil
    }
    let components = object.split(separator: "/", omittingEmptySubsequences: true)
    if components.count <= 1 {
      return StoragePath(with: bucket, object: "")
    }
    let parentObject = components.dropLast().joined(separator: "/")
    return StoragePath(with: bucket, object: parentObject)
  }

  /// Returns a `StoragePath` pointing to the root of `bucket`.
  package func root() -> StoragePath {
    StoragePath(with: bucket)
  }

  /// Returns the `gs://` URI representation of this path.
  package func stringValue() -> String {
    "gs://\(bucket)/\(object ?? "")"
  }
}
