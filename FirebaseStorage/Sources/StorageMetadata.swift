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
 * Class which represents the metadata on an object in Firebase Storage. This metadata is
 * returned on successful operations, and can be used to retrieve download URLs, content types,
 * and a Storage reference to the object in question. Full documentation can be found at the GCS
 * Objects#resource docs.
 * @see https://cloud.google.com/storage/docs/json_api/v1/objects#resource
 */
@objc(FIRStorageMetadata) open class StorageMetadata: NSObject {
  // MARK: - Public APIs

  /**
   * The name of the bucket containing this object.
   */
  @objc public let bucket: String

  /**
   * Cache-Control directive for the object data.
   */
  @objc public var cacheControl: String? {
    get {
      return impl.cacheControl
    }
    set(newValue) {
      impl.cacheControl = newValue
    }
  }

  /**
   * Content-Disposition of the object data.
   */
  @objc public var contentDisposition: String? {
    get {
      return impl.contentDisposition
    }
    set(newValue) {
      impl.contentDisposition = newValue
    }
  }

  /**
   * Content-Encoding of the object data.
   */
  @objc public var contentEncoding: String? {
    get {
      return impl.contentEncoding
    }
    set(newValue) {
      impl.contentEncoding = newValue
    }
  }

  /**
   * Content-Language of the object data.
   */
  @objc public var contentLanguage: String? {
    get {
      return impl.contentLanguage
    }
    set(newValue) {
      impl.contentLanguage = newValue
    }
  }

  /**
   * Content-Type of the object data.
   */
  @objc public var contentType: String? {
    get {
      return impl.contentType
    }
    set(newValue) {
      impl.contentType = newValue
    }
  }

  /**
   * MD5 hash of the data; encoded using base64.
   */
  @objc public let md5Hash: String?

  /**
   * The content generation of this object. Used for object versioning.
   */
  @objc public let generation: Int64

  /**
   * User-provided metadata, in key/value pairs.
   */
  @objc public var customMetadata: [String: String]? {
    get {
      return impl.customMetadata
    }
    set(newValue) {
      impl.customMetadata = newValue
    }
  }

  /**
   * The version of the metadata for this object at this generation. Used
   * for preconditions and for detecting changes in metadata. A metageneration number is only
   * meaningful in the context of a particular generation of a particular object.
   */
  @objc public let metageneration: Int64

  /**
   * The name of this object, in gs://bucket/path/to/object.txt, this is object.txt.
   */
  @objc public let name: String?

  /**
   * The full path of this object, in gs://bucket/path/to/object.txt, this is path/to/object.txt.
   */
  @objc public let path: String?

  /**
   * Content-Length of the data in bytes.
   */
  @objc public let size: Int64

  /**
   * The creation time of the object in RFC 3339 format.
   */
  @objc public let timeCreated: Date?

  /**
   * The modification time of the object metadata in RFC 3339 format.
   */
  @objc public let updated: Date?

  /**
   * A reference to the object in Firebase Storage.
   */
  @objc public let storageReference: StorageReference?

  /**
   * Creates a Dictionary from the contents of the metadata.
   * @return A Dictionary that represents the contents of the metadata.
   */
  @objc open func dictionaryRepresentation() -> [String: Any] {
    return impl.dictionaryRepresentation()
  }

  /**
   * Determines if the current metadata represents a "file".
   */
  @objc public let isFile: Bool

  /**
   * Determines if the current metadata represents a "folder".
   */
  @objc public let isFolder: Bool

  // MARK: - Public Initializers

  @objc override public convenience init() {
    self.init(impl: FIRIMPLStorageMetadata(dictionary: [:])!)
  }

  /**
   * Creates an instance of StorageMetadata from the contents of a dictionary.
   * @return An instance of StorageMetadata that represents the contents of a dictionary.
   */
  @objc public convenience init(dictionary: [String: Any]) {
    self.init(impl: FIRIMPLStorageMetadata(dictionary: dictionary)!)
  }

  // MARK: - NSObject overrides

  @objc override open func copy() -> Any {
    return StorageMetadata(impl: impl.copy() as! FIRIMPLStorageMetadata)
  }

  @objc override open func isEqual(_ object: Any?) -> Bool {
    guard let ref = object as? StorageMetadata else {
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

  internal let impl: FIRIMPLStorageMetadata

  internal init(impl: FIRIMPLStorageMetadata) {
    self.impl = impl
    bucket = impl.bucket
    md5Hash = impl.md5Hash
    generation = impl.generation
    metageneration = impl.metageneration
    name = impl.name
    path = impl.path
    size = impl.size
    timeCreated = impl.timeCreated
    updated = impl.updated
    if let ref = impl.storageReference {
      storageReference = StorageReference(ref)
    } else {
      storageReference = nil
    }
    isFile = impl.isFile
    isFolder = impl.isFolder
  }
}
