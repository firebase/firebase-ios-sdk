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
 * A protocol describing the encodable properties of a Decimal128Value.
 *
 * Note: this protocol exists as a workaround for the Swift compiler: if the Decimal128Value class
 * was extended directly to conform to Codable, the methods implementing the protocol would be need
 * to be marked required but that can't be done in an extension. Declaring the extension on the
 * protocol sidesteps this issue.
 */
private protocol CodableDecimal128Value: Codable {
  var value: String { get }

  init(_ value: String)
}

/** The keys in a Decimal128Value. Must match the properties of Decimal128Value. */
private enum Decimal128ValueKeys: String, CodingKey {
  case value
}

/**
 * An extension of Decimal128Value that implements the behavior of the Codable protocol.
 *
 * Note: this is implemented manually here because the Swift compiler can't synthesize these methods
 * when declaring an extension to conform to Codable.
 */
extension CodableDecimal128Value {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: Decimal128ValueKeys.self)
    let value = try container.decode(String.self, forKey: .value)
    self.init(value)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: Decimal128ValueKeys.self)
    try container.encode(value, forKey: .value)
  }
}

/** Extends Decimal128Value to conform to Codable. */
extension FirebaseFirestore.Decimal128Value: FirebaseFirestore.CodableDecimal128Value {}
