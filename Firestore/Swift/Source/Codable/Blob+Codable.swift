/*
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE

/**
 * A protocol describing the encodable properties of a Blob.
 *
 * Note: this protocol exists as a workaround for the Swift compiler: if the Blob class
 * was extended directly to conform to Codable, the methods implementing the protocol would be need
 * to be marked required but that can't be done in an extension. Declaring the extension on the
 * protocol sidesteps this issue.
 */
private protocol CodableBlob: Codable {
  var subtype: UInt8 { get }
  var bytes: Data { get }

  init(bytes: Data)
  init(bsonBinary: Data, subtype: UInt8)
}

/** The keys in a Blob. Must match the properties of CodableBlob. */
private enum BlobKeys: String, CodingKey {
  case subtype
  case bytes
}

extension CodableBlob {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: BlobKeys.self)
    let subtype = try container.decode(UInt8.self, forKey: .subtype)
    let bytes = try container.decode(Data.self, forKey: .bytes)
    if subtype != 0 {
      self.init(bsonBinary: bytes, subtype: subtype)
    } else {
      self.init(bytes: bytes)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: BlobKeys.self)
    try container.encode(subtype, forKey: .subtype)
    try container.encode(bytes, forKey: .bytes)
  }
}

/** Extends Blob to conform to Codable. */
extension FirebaseFirestore.Blob: FirebaseFirestore.CodableBlob {}
