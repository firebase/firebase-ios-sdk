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

/** Extends FieldValue to conform to Encodable. */
extension FieldValue: Encodable {
  /// Encoding a FieldValue will throw by default unless the encoder implementation
  /// explicitly handles it, which is what FirestoreEncoder does.
  public func encode(to encoder: Encoder) throws {
    throw FirestoreEncodingError.encodingIsNotSupported
  }
}

/** Swift enums providing alternatives to direct usages of FieldValue. */

/// Wraps around Timestamp and FieldValue.serverTimestamp to support modeling
/// timestamps in custom classes.
///
/// Example:
/// struct CustomModel {
///   var ts: ServerTimestamp
/// }
/// Then `CustomModel(ts: .pending)` will tell server to fill `ts` with current
/// timestamp.
public enum ServerTimestamp: Codable, Equatable {
  /// When being read (decoded) from Firestore, NSNull values will be mapped to `pending`.
  /// When being written (encoded) to Firestore, `pending` means requesting server to
  /// set timestamp on the field (essentially setting value
  /// to FieldValue.serverTimestamp()).
  case pending

  /// When being read (decoded) from Firestore, non-nil Timestamp will be mapped to
  /// `resolved`.
  /// When being written (encoded) to Firestore, `resolved(stamp)` will set the field
  /// value to `stamp`.
  case resolved(Timestamp)

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
