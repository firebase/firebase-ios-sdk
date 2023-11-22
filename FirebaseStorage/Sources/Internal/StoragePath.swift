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

enum StoragePathError: Error {
  case storagePathError(String)
}

/**
 * Represents a path in GCS, which can be represented as: gs://bucket/path/to/object
 * or http[s]://firebasestorage.googleapis.com/v0/b/bucket/o/path/to/object?token=<12345>
 * This class also includes helper methods to parse those URI/Ls, as well as to
 * add and remove path segments.
 */
class StoragePath: NSCopying, Equatable {
  // MARK: Class methods

  /**
   * Parses a generic string (representing some URI or URL) and returns the appropriate path.
   * @param string String which is parsed into a path.
   * @return Returns an instance of StoragePath.
   * @throws Throws an error if the string is not a valid gs:// URI or http[s]:// URL.
   */
  static func path(string: String) throws -> StoragePath {
    if string.hasPrefix("gs://") {
      // "gs://bucket/path/to/object"
      return try path(GSURI: string)
    } else if string.hasPrefix("http://") || string.hasPrefix("https://") {
      // "http[s]://firebasestorage.googleapis.com/bucket/path/to/object?signed_url_params"
      return try path(HTTPURL: string)
    } else {
      // Invalid scheme, throw an error!
      throw StoragePathError.storagePathError("Internal error: URL scheme must be one " +
        "of gs://, http://, or https://")
    }
  }

  /**
   * Parses a gs://bucket/path/to/object URI into a GCS path.
   * @param aURIString gs:// URI which is parsed into a path.
   * @return Returns an instance of StoragePath or nil if one can't be created.
   * @throws Throws an error if the string is not a valid gs:// URI.
   */
  static func path(GSURI aURIString: String) throws -> StoragePath {
    if aURIString.starts(with: "gs://") {
      let bucketObject = aURIString.dropFirst("gs://".count)
      if bucketObject.contains("/") {
        let splitStringArray = bucketObject.split(separator: "/", maxSplits: 1).map(String.init)
        let object = splitStringArray.count == 2 ? splitStringArray[1] : nil
        return StoragePath(with: splitStringArray[0], object: object)
      } else if bucketObject.count > 0 {
        return StoragePath(with: String(bucketObject))
      }
    }
    throw StoragePathError.storagePathError("Internal error: URI must be in the form of " +
      "gs://<bucket>/<path/to/object>")
  }

  /**
   * Parses a http[s]://firebasestorage.googleapis.com/v0/b/bucket/o/path/to/object...?token=<12345>
   * URL into a GCS path.
   * @param aURLString http[s]:// URL which is parsed into a path.
   * string which is parsed into a path.
   * @return Returns an instance of StoragePath or nil if one can't be created.
   * @throws Throws an error if the string is not a valid http[s]:// URL.
   */
  private static func path(HTTPURL aURLString: String) throws -> StoragePath {
    let httpsURL = URL(string: aURLString)
    let pathComponents = httpsURL?.pathComponents
    guard let pathComponents = pathComponents,
          pathComponents.count >= 4,
          pathComponents[1] == "v0",
          pathComponents[2] == "b" else {
      throw StoragePathError.storagePathError("Internal error: URL must be in the form of " +
        "http[s]://<host>/v0/b/<bucket>/o/<path/to/object>[?token=signed_url_params]")
    }
    let bucketName = pathComponents[3]

    guard pathComponents.count > 4 else {
      return StoragePath(with: bucketName)
    }
    // Construct object name
    var objectName = pathComponents[5]
    for i in 6 ..< pathComponents.count {
      objectName = "\(objectName)/\(pathComponents[i])"
    }
    return StoragePath(with: bucketName, object: objectName)
  }

  // Removes leading and trailing slashes, and compresses multiple slashes
  // to create a canonical representation.
  // Example: /foo//bar///baz//// -> foo/bar/baz
  private static func standardizedPathForString(_ string: String) -> String {
    var output = string
    while true {
      let newOutput = output.replacingOccurrences(of: "//", with: "/")
      if newOutput == output {
        break
      }
      output = newOutput
    }
    return output.trimmingCharacters(in: ["/"])
  }

  // MARK: - Internal Implementations

  /**
   * The GCS bucket in the path.
   */
  let bucket: String

  /**
   * The GCS object in the path.
   */
  let object: String?

  /**
   * Constructs an StoragePath object that represents the given bucket and object.
   * @param bucket The name of the bucket.
   * @param object The name of the object.
   * @return An instance of StoragePath representing the @a bucket and @a object.
   */
  init(with bucket: String,
       object: String? = nil) {
    self.bucket = bucket
    if let object = object {
      self.object = StoragePath.standardizedPathForString(object)
    } else {
      self.object = nil
    }
  }

  static func == (lhs: StoragePath, rhs: StoragePath) -> Bool {
    return lhs.bucket == rhs.bucket && lhs.object == rhs.object
  }

  func copy(with zone: NSZone? = nil) -> Any {
    return StoragePath(with: bucket, object: object)
  }

  /**
   * Creates a new path based off of the current path and a string appended to it.
   * Note that all slashes are compressed to a single slash, and leading and trailing slashes
   * are removed.
   * @param path String to append to the current path.
   * @return Returns a new instance of StoragePath with the new path appended.
   */
  func child(_ path: String) -> StoragePath {
    if path.count == 0 {
      return copy() as! StoragePath
    }
    var childObject: String
    if let object = object as? NSString {
      childObject = object.appendingPathComponent(path)
    } else {
      childObject = path
    }
    return StoragePath(with: bucket, object: childObject)
  }

  /**
   * Creates a new path based off of the current path with the last path segment removed.
   * @return Returns a new instance of StoragePath pointing to the parent path,
   * or nil if the current path points to the root.
   */
  func parent() -> StoragePath? {
    guard let object = object,
          object.count > 0 else {
      return nil
    }
    let parentObject = (object as NSString).deletingLastPathComponent
    return StoragePath(with: bucket, object: parentObject)
  }

  /**
   * Creates a new path based off of the root of the bucket.
   * @return Returns a new instance of StoragePath pointing to the root of the bucket.
   */
  func root() -> StoragePath {
    return StoragePath(with: bucket)
  }

  /**
   * Returns a GS URI representing the current path.
   * @return Returns a gs://bucket/path/to/object URI representing the current path.
   */
  func stringValue() -> String {
    return "gs://\(bucket)/\(object ?? "")"
  }
}
