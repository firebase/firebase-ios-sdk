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

/**
 * Class which represents the metadata on an object in Firebase Storage.
 *
 * This metadata is
 * returned on successful operations, and can be used to retrieve download URLs, content types,
 * and a Storage reference to the object in question. Full documentation can be found in the
 * [GCS documentation](https://cloud.google.com/storage/docs/json_api/v1/objects#resource)
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
  @objc public var cacheControl: String?
  /**
   * Content-Disposition of the object data.
   */
  @objc public var contentDisposition: String?

  /**
   * Content-Encoding of the object data.
   */
  @objc public var contentEncoding: String?

  /**
   * Content-Language of the object data.
   */
  @objc public var contentLanguage: String?

  /**
   * Content-Type of the object data.
   */
  @objc public var contentType: String?

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
  @objc public var customMetadata: [String: String]?

  /**
   * The version of the metadata for this object at this generation. Used
   * for preconditions and for detecting changes in metadata. A metageneration number is only
   * meaningful in the context of a particular generation of a particular object.
   */
  @objc public let metageneration: Int64

  /**
   * The name of this object, in gs://bucket/path/to/object.txt, this is object.txt.
   */
  @objc public internal(set) var name: String?

  /**
   * The full path of this object, in gs://bucket/path/to/object.txt, this is path/to/object.txt.
   */
  @objc public internal(set) var path: String?

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
   * Never used API
   */
  @available(*, deprecated) @objc public let storageReference: StorageReference? = nil

  /**
   * Creates a Dictionary from the contents of the metadata.
   * @return A Dictionary that represents the contents of the metadata.
   */
  @objc open func dictionaryRepresentation() -> [String: AnyHashable] {
    let stringFromDate = StorageMetadata.RFC3339StringFromDate
    return [
      "bucket": bucket,
      "cacheControl": cacheControl,
      "contentDisposition": contentDisposition,
      "contentEncoding": contentEncoding,
      "contentLanguage": contentLanguage,
      "contentType": contentType,
      "md5Hash": md5Hash,
      "size": size != 0 ? size : nil,
      "generation": generation != 0 ? "\(generation)" : nil,
      "metageneration": metageneration != 0 ? "\(metageneration)" : nil,
      "timeCreated": timeCreated.map(stringFromDate),
      "updated": updated.map(stringFromDate),
      "name": path,
    ].compactMapValues { $0 }.merging(["metadata": customMetadata]) { current, _ in current }
  }

  /**
   * Determines if the current metadata represents a "file".
   */
  @objc public var isFile: Bool {
    return fileType == .file
  }

  // TODO: Nothing in the implementation ever sets `.folder`.
  /**
   * Determines if the current metadata represents a "folder".
   */
  @objc public var isFolder: Bool {
    return fileType == .folder
  }

  // MARK: - Public Initializers

  /**
   * Creates an empty instance of StorageMetadata.
   * @return An empty instance of StorageMetadata.
   */
  @objc override public convenience init() {
    self.init(dictionary: [:])
  }

  /**
   * Creates an instance of StorageMetadata from the contents of a dictionary.
   * @return An instance of StorageMetadata that represents the contents of a dictionary.
   */
  @objc public init(dictionary: [String: AnyHashable]) {
    initialMetadata = dictionary
    bucket = dictionary["bucket"] as? String ?? ""
    cacheControl = dictionary["cacheControl"] as? String ?? nil
    contentDisposition = dictionary["contentDisposition"] as? String ?? nil
    contentEncoding = dictionary["contentEncoding"] as? String ?? nil
    contentLanguage = dictionary["contentLanguage"] as? String ?? nil
    contentType = dictionary["contentType"] as? String ?? nil
    customMetadata = dictionary["metadata"] as? [String: String] ?? nil
    size = StorageMetadata.intFromDictionaryValue(dictionary["size"])
    generation = StorageMetadata.intFromDictionaryValue(dictionary["generation"])
    metageneration = StorageMetadata.intFromDictionaryValue(dictionary["metageneration"])
    timeCreated = StorageMetadata.dateFromRFC3339String(dictionary["timeCreated"])
    updated = StorageMetadata.dateFromRFC3339String(dictionary["updated"])
    md5Hash = dictionary["md5Hash"] as? String ?? nil

    // GCS "name" is our path, our "name" is just the last path component of the path
    if let name = dictionary["name"] as? String {
      path = name
      self.name = (name as NSString).lastPathComponent
    }
    fileType = .unknown
  }

  // MARK: - NSObject overrides

  @objc override open func copy() -> Any {
    let clone = StorageMetadata(dictionary: dictionaryRepresentation())
    clone.initialMetadata = initialMetadata
    return clone
  }

  @objc override open func isEqual(_ object: Any?) -> Bool {
    guard let ref = object as? StorageMetadata else {
      return false
    }
    return ref.dictionaryRepresentation() == dictionaryRepresentation()
  }

  @objc override public var hash: Int {
    return (dictionaryRepresentation() as NSDictionary).hash
  }

  @objc override public var description: String {
    return "\(type(of: self)) \(dictionaryRepresentation())"
  }

  // MARK: - Internal APIs

  func updatedMetadata() -> [String: AnyHashable] {
    return remove(matchingMetadata: dictionaryRepresentation(), oldMetadata: initialMetadata)
  }

  enum StorageMetadataType {
    case unknown
    case file
    case folder
  }

  var fileType: StorageMetadataType

  // MARK: - Private APIs and data

  private var initialMetadata: [String: AnyHashable]

  private static func intFromDictionaryValue(_ value: Any?) -> Int64 {
    if let value = value as? Int { return Int64(value) }
    if let value = value as? Int64 { return value }
    if let value = value as? String { return Int64(value) ?? 0 }
    return 0
  }

  private static var dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable US_POSIX
    dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSSZZZZZ"
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    return dateFormatter
  }()

  private static func dateFromRFC3339String(_ value: Any?) -> Date? {
    if let stringValue = value as? String {
      return dateFormatter.date(from: stringValue) ?? nil
    }
    return nil
  }

  static func RFC3339StringFromDate(_ date: Date) -> String {
    return dateFormatter.string(from: date)
  }

  private func remove(matchingMetadata: [String: AnyHashable],
                      oldMetadata: [String: AnyHashable]) -> [String: AnyHashable] {
    var newMetadata = matchingMetadata
    for (key, oldValue) in oldMetadata {
      guard let newValue = newMetadata[key] else {
        // Adds 'NSNull' for entries that only exist in oldMetadata.
        newMetadata[key] = NSNull()
        continue
      }
      if let oldString = oldValue as? String,
         let newString = newValue as? String {
        if oldString == newString {
          newMetadata[key] = nil
        }
      } else if let oldDictionary = oldValue as? [String: AnyHashable],
                let newDictionary = newValue as? [String: AnyHashable] {
        let outDictionary = remove(matchingMetadata: newDictionary, oldMetadata: oldDictionary)
        if outDictionary.count == 0 {
          newMetadata[key] = nil
        } else {
          newMetadata[key] = outDictionary
        }
      }
    }
    return newMetadata
  }
}
