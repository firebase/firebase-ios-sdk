/*
 * Copyright 2025 Google
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
 * A protocol describing the encodable properties of an BsonTimestamp.
 *
 * Note: this protocol exists as a workaround for the Swift compiler: if the BsonTimestamp class
 * was extended directly to conform to Codable, the methods implementing the protocol would be need
 * to be marked required but that can't be done in an extension. Declaring the extension on the
 * protocol sidesteps this issue.
 */
private protocol CodableBsonTimestamp: Codable {
  var seconds: UInt32 { get }
  var increment: UInt32 { get }

  init(seconds: UInt32, increment: UInt32)
}

/** The keys in an BsonTimestamp. Must match the properties of CodableBsonTimestamp. */
private enum BsonTimestampKeys: String, CodingKey {
  case seconds
  case increment
}

/**
 * An extension of BsonTimestamp that implements the behavior of the Codable protocol.
 *
 * Note: this is implemented manually here because the Swift compiler can't synthesize these methods
 * when declaring an extension to conform to Codable.
 */
extension CodableBsonTimestamp {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: BsonTimestampKeys.self)
    let seconds = try container.decode(UInt32.self, forKey: .seconds)
    let increment = try container.decode(UInt32.self, forKey: .increment)
    self.init(seconds: seconds, increment: increment)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: BsonTimestampKeys.self)
    try container.encode(seconds, forKey: .seconds)
    try container.encode(increment, forKey: .increment)
  }
}

/** Extends BsonTimestamp to conform to Codable. */
extension FirebaseFirestore.BsonTimestamp: FirebaseFirestore.CodableBsonTimestamp {}
