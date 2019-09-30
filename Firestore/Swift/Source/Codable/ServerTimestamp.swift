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

import FirebaseFirestore

#if swift(>=5.1)

  /// A marker protocol that indicates the type can be annotated with an
  /// `@ServerTimestamp` property wrapper. Only `Timestamp`, `Date`, and `NSDate`
  /// can be wrapped with `@ServerTimestamp`.
  public protocol ServerTimestampWrappable {}

  extension Date: ServerTimestampWrappable {}
  extension NSDate: ServerTimestampWrappable {}
  extension Timestamp: ServerTimestampWrappable {}

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
  public struct ServerTimestamp<Value>: Codable, Equatable
    where Value: ServerTimestampWrappable & Codable & Equatable {
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
        value = try decode(try container.decode(Timestamp.self))
      }
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      if let value = value {
        try container.encode(value)
      } else {
        try container.encode(FieldValue.serverTimestamp())
      }
    }

    private func decode(_ timestamp: Timestamp) throws -> Value {
      if Value.self == Timestamp.self {
        return timestamp as! Value
      } else if Value.self == Date.self {
        return timestamp.dateValue() as! Value
      } else if Value.self == NSDate.self {
        let interval = timestamp.dateValue().timeIntervalSince1970
        return NSDate(timeIntervalSince1970: interval) as! Value
      } else {
        let typeName = String(describing: Value.self)
        throw FirestoreDecodingError.decodingIsNotSupported(
          "Field is annotated with @ServerTimestamp but has type " +
            "\(typeName) instead of Timestamp, Date, or NSDate."
        )
      }
    }
  }

#endif // swift(>=5.1)

/// A compatibility version of `ServerTimestamp` that does not use property
/// wrappers, suitable for use in older versions of Swift.
///
/// Wraps a `Timestamp` field to mark that it should be populated with a server
/// timestamp. If a `Codable` object being written contains a `.pending` for an
/// `Swift4ServerTimestamp` field, it will be replaced with
/// `FieldValue.serverTimestamp()` as it is sent.
///
/// Example:
/// ```
/// struct CustomModel {
///   var ts: Swift4ServerTimestamp
/// }
/// ```
///
/// Then `CustomModel(ts: .pending)` will tell server to fill `ts` with current
/// timestamp.
@available(swift, deprecated: 5.1)
public enum Swift4ServerTimestamp: Codable, Equatable {
  /// When being read (decoded) from Firestore, NSNull values will be mapped to
  /// `pending`. When being written (encoded) to Firestore, `pending` means
  /// requesting server to set timestamp on the field (essentially setting value
  /// to FieldValue.serverTimestamp()).
  case pending

  /// When being read (decoded) from Firestore, non-nil Timestamp will be mapped
  /// to `resolved`. When being written (encoded) to Firestore,
  /// `resolved(stamp)` will set the field value to `stamp`.
  case resolved(Timestamp)

  /// Returns this value as an `Optional<Timestamp>`.
  ///
  /// If the server timestamp is still pending, the returned optional will be
  /// `.none`. Once resolved, the returned optional will be `.some` with the
  /// resolved timestamp.
  public var timestamp: Timestamp? {
    switch self {
    case .pending:
      return .none
    case let .resolved(timestamp):
      return .some(timestamp)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .pending
    } else {
      let value = try container.decode(Timestamp.self)
      self = .resolved(value)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .pending:
      try container.encode(FieldValue.serverTimestamp())
    case let .resolved(value: value):
      try container.encode(value)
    }
  }
}
