/*
 * Copyright 2019 Google
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

/// Wraps an `Optional` field in a `Codable` object such that when the field
/// has a `nil` value it will encode to a null value in Firestore. Normally,
/// optional fields are omitted from the encoded document.
///
/// This is useful for ensuring a field is present in a Firestore document,
/// even when there is no associated value.
@propertyWrapper
public struct ExplicitNull<Value> {
  var value: Value?

  public init(wrappedValue value: Value?) {
    self.value = value
  }

  public var wrappedValue: Value? {
    get { value }
    set { value = newValue }
  }
}

extension ExplicitNull: Equatable where Value: Equatable {}

extension ExplicitNull: Hashable where Value: Hashable {}

extension ExplicitNull: Encodable where Value: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    if let value = value {
      try container.encode(value)
    } else {
      try container.encodeNil()
    }
  }
}

extension ExplicitNull: Decodable where Value: Decodable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      value = nil
    } else {
      value = try container.decode(Value.self)
    }
  }
}
