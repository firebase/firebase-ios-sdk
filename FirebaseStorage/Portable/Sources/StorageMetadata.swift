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
private import FirebaseCoreInternal

/// **[Experimental]** Metadata for an object in Cloud Storage for Firebase.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public final class StorageMetadata: Sendable {
  private let contentTypeLock: UnfairLock<String?>

  /// **[Experimental]** The name of the bucket containing this object.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public let bucket: String

  /// **[Experimental]** The full path of this object.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public let path: String?

  /// **[Experimental]** The short name of this object.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public let name: String?

  /// **[Experimental]** The Content-Type of the object data.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public var contentType: String? {
    get { contentTypeLock.withLock { $0 } }
    set { contentTypeLock.withLock { $0 = newValue } }
  }

  /// **[Experimental]** Creates an empty `StorageMetadata` instance.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public convenience init() {
    self.init(bucket: "", path: nil, name: nil, contentType: nil)
  }

  /// **[Experimental]** Creates a `StorageMetadata` instance from a dictionary of metadata keys
  /// and values.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameter dictionary: A dictionary of metadata attributes.
  public convenience init(dictionary: [String: Any]) {
    self.init(
      bucket: dictionary["bucket"] as? String ?? "",
      path: dictionary["name"] as? String,
      name: (dictionary["name"] as? String)?.split(separator: "/").last.map(String.init),
      contentType: dictionary["contentType"] as? String
    )
  }

  package init(bucket: String, path: String?, name: String?, contentType: String?) {
    self.bucket = bucket
    self.path = path
    self.name = name
    contentTypeLock = UnfairLock(contentType)
  }
}
