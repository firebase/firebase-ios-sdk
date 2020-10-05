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

import FirebaseDatabase

#if compiler(>=5.1)
  /// A property wrapper that marks an `Optional<Date>` field to be
  /// populated with a server timestamp. If a `Codable` object being written
  /// contains a `nil` for an `@ServerTimestamp`-annotated field, it will be
  /// replaced with `ServerValue.timestamp()` as it is sent.
  ///
  /// Example:
  /// ```
  /// struct CustomModel {
  ///   @ServerTimestamp var ts: Date?
  /// }
  /// ```
  ///
  /// Then writing `CustomModel(ts: nil)` will tell server to fill `ts` with
  /// current timestamp.
  @propertyWrapper
  public struct ServerTimestamp: Codable, Equatable, Hashable {
    var value: Date?

    public init(wrappedValue value: Date?) {
      self.value = value
    }

    public var wrappedValue: Date? {
      get { value }
      set { value = newValue }
    }

    // MARK: Codable

    public init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if container.decodeNil() {
        value = nil
      } else {
        let msecs = try container.decode(Int.self)
        value = Date(timeIntervalSince1970: TimeInterval(msecs) / 1000)
      }
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      if let value = value {
        let interval = value.timeIntervalSince1970
        try container.encode(Int(interval * 1000))
      } else if let dictionary = ServerValue.timestamp() as? [String: String] {
        try container.encode(dictionary)
      } else {
        throw Database.EncodingError.internalError
      }
    }
  }
#endif // compiler(>=5.1)

/// A compatibility version of `ServerTimestamp` that does not use property
/// wrappers, suitable for use in older versions of Swift.
///
/// Wraps a `Date` field to mark that it should be populated with a server
/// timestamp. If a `Codable` object being written contains a `.pending` for an
/// `Swift4ServerTimestamp` field, it will be replaced with
/// `ServerValue.timestamp()` as it is sent.
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
  case resolved(Date)

  /// Returns this value as an `Optional<Timestamp>`.
  ///
  /// If the server timestamp is still pending, the returned optional will be
  /// `.none`. Once resolved, the returned optional will be `.some` with the
  /// resolved timestamp.
  public var timestamp: Date? {
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
      let msecs = try container.decode(Int.self)
      let value = Date(timeIntervalSince1970: TimeInterval(msecs) / 1000)
      self = .resolved(value)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .pending:
      if let dictionary = ServerValue.timestamp() as? [String: String] {
        try container.encode(dictionary)
      } else {
        throw Database.EncodingError.internalError
      }
    case let .resolved(value: value):
      let interval = value.timeIntervalSince1970
      try container.encode(Int(interval * 1000))
    }
  }
}
