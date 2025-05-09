/*
 * Copyright 2024 Google LLC
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

public extension FieldValue {
  /// Creates a new `VectorValue` constructed with a copy of the given array of Doubles.
  /// - Parameter array: An array of Doubles.
  /// - Returns: A new `VectorValue` constructed with a copy of the given array of Doubles.
  static func vector(_ array: [Double]) -> VectorValue {
    let nsNumbers = array.map { double in
      NSNumber(value: double)
    }
    return FieldValue.__vector(with: nsNumbers)
  }

  /// Creates a new `VectorValue` constructed with a copy of the given array of Floats.
  /// - Parameter array: An array of Floats.
  /// - Returns: A new `VectorValue` constructed with a copy of the given array of Floats.
  static func vector(_ array: [Float]) -> VectorValue {
    let nsNumbers = array.map { float in
      NSNumber(value: float)
    }
    return FieldValue.__vector(with: nsNumbers)
  }

  /// Returns a `MinKey` instance.
  /// - Returns: A `MinKey` instance.
  static func minKey() -> MinKey {
    return FieldValue.__minKey()
  }

  /// Returns a `MaxKey` instance.
  /// - Returns: A `MaxKey` instance.
  static func maxKey() -> MaxKey {
    return FieldValue.__maxKey()
  }

  /// Creates a new `RegexValue` constructed with the given pattern and options.
  /// - Parameter pattern: The pattern of the regular expression.
  /// - Parameter options: The options of the regular expression.
  /// - Returns: A new `RegexValue` constructed with the given pattern and options.
  static func regex(pattern: String, options: String) -> RegexValue {
    return FieldValue.__regex(withPattern: pattern, options: options)
  }

  /// Creates a new `Int32Value` with the given signed 32-bit integer value.
  /// - Parameter value: The 32-bit number to be used for constructing the Int32Value.
  /// - Returns: A new `Int32Value` instance.
  static func int32(_ value: Int32) -> Int32Value {
    return FieldValue.__int32(withValue: value)
  }

  /// Creates a new `BsonObjectId` with the given value.
  /// - Parameter value: The 24-character hex string representation of the ObjectId.
  /// - Returns: A new `BsonObjectId` instance constructed with the given value.
  static func bsonObjectId(_ value: String) -> BsonObjectId {
    return FieldValue.__bsonObjectId(withValue: value)
  }

  /// Creates a new `BsonTimestamp` with the given values.
  /// @param seconds The underlying unsigned 32-bit integer for seconds.
  /// @param increment The underlying unsigned 32-bit integer for increment.
  /// @return A new `BsonTimestamp` instance constructed with the given values.
  static func bsonTimestamp(seconds: UInt32, increment: UInt32) -> BsonTimestamp {
    return FieldValue.__bsonTimestamp(withSeconds: seconds, increment: increment)
  }

  /// Creates a new `BsonBinaryData` object with the given subtype and data.
  /// @param subtype The subtype of the data.
  /// @param data The binary data.
  /// @return A new `BsonBinaryData` instance constructed with the given values.
  static func bsonBinaryData(subtype: UInt8, data: Data) -> BsonBinaryData {
    return FieldValue.__bsonBinaryData(withSubtype: subtype, data: data)
  }
}
