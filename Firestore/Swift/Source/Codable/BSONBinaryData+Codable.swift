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
 * A protocol describing the encodable properties of an BSONBinaryData.
 *
 * Note: this protocol exists as a workaround for the Swift compiler: if the BSONBinaryData class
 * was extended directly to conform to Codable, the methods implementing the protocol would be need
 * to be marked required but that can't be done in an extension. Declaring the extension on the
 * protocol sidesteps this issue.
 */
private protocol CodableBSONBinaryData: Codable {
  var subtype: UInt8 { get }
  var data: Data { get }

  init(subtype: UInt8, data: Data)
}

/** The keys in an BSONBinaryData. Must match the properties of CodableBSONBinaryData. */
private enum BSONBinaryDataKeys: String, CodingKey {
  case subtype
  case data
}

/**
 * An extension of BSONBinaryData that implements the behavior of the Codable protocol.
 *
 * Note: this is implemented manually here because the Swift compiler can't synthesize these methods
 * when declaring an extension to conform to Codable.
 */
extension CodableBSONBinaryData {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: BSONBinaryDataKeys.self)
    let subtype = try container.decode(UInt8.self, forKey: .subtype)
    let data = try container.decode(Data.self, forKey: .data)
    self.init(subtype: subtype, data: data)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: BSONBinaryDataKeys.self)
    try container.encode(subtype, forKey: .subtype)
    try container.encode(data, forKey: .data)
  }
}

/** Extends BSONBinaryData to conform to Codable. */
extension FirebaseFirestore.BSONBinaryData: FirebaseFirestore.CodableBSONBinaryData {}
