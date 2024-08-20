/*
 * Copyright 2019 Google LLC
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

@_exported import class FirebaseCore.Timestamp

/// A type that can initialize itself from a Firestore Timestamp, which makes
/// it suitable for use with the `@ServerTimestamp` property wrapper.
///
/// Firestore includes extensions that make `Timestamp` and `Date` conform to
/// `ServerTimestampWrappable`.
public protocol ServerTimestampWrappable {
  /// Creates a new instance by converting from the given `Timestamp`.
  ///
  /// - Parameter timestamp: The timestamp from which to convert.
  static func wrap(_ timestamp: Timestamp) throws -> Self

  /// Converts this value into a Firestore `Timestamp`.
  ///
  /// - Returns: A `Timestamp` representation of this value.
  static func unwrap(_ value: Self) throws -> Timestamp
}

extension Date: ServerTimestampWrappable {
  public static func wrap(_ timestamp: Timestamp) throws -> Self {
    return timestamp.dateValue()
  }

  public static func unwrap(_ value: Self) throws -> Timestamp {
    return Timestamp(date: value)
  }
}

extension Timestamp: ServerTimestampWrappable {
  public static func wrap(_ timestamp: Timestamp) throws -> Self {
    return timestamp as! Self
  }

  public static func unwrap(_ value: Timestamp) throws -> Timestamp {
    return value
  }
}

/// A property wrapper that marks an `Optional<Timestamp>` field to be
/// populated with a server timestamp. If a `Codable` object being written
/// contains a `nil` for an `@ServerTimestamp`-annotated field, it will be
/// replaced with `FieldValue.serverTimestamp()` as it is sent.
///
/// Example:
/// ```
/// struct CustomModel {
///   @ServerTimestamp var ts: Timestamp?
/// }
/// ```
///
/// Then writing `CustomModel(ts: nil)` will tell server to fill `ts` with
/// current timestamp.
@propertyWrapper
public struct ServerTimestamp<Value>: Codable
  where Value: ServerTimestampWrappable & Codable {
  var value: Value?

  public init(wrappedValue value: Value?) {
    self.value = value
  }

  public var wrappedValue: Value? {
    get { value }
    set { value = newValue }
  }

  // MARK: Codable

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      value = nil
    } else {
      value = try Value.wrap(container.decode(Timestamp.self))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    if let value {
      try container.encode(Value.unwrap(value))
    } else {
      try container.encode(FieldValue.serverTimestamp())
    }
  }
}

extension ServerTimestamp: Equatable where Value: Equatable {}

extension ServerTimestamp: Hashable where Value: Hashable {}
