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
///   var ts: ServerTimestamp = .pending
/// }
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

/// Wraps around FieldValue.increment(_ i: Int64) to support modeling Int64
/// typed fields with one type.
///
/// Example:
/// struct CustomModel {
///   var intValue: IncrementableInt
/// }
public enum IncrementableInt: Codable, Equatable, Hashable, ExpressibleByIntegerLiteral {
  /// When being written (encoded), `.increment(i)` will be mapped to
  /// `FieldValue.increment(i)`, which requests the server to increment the value
  /// of the field by `i`.
  /// Reading (decoding) will never create a `.increment`.
  case increment(Int64)

  /// When being written (encoded), `.value(i)` will set the field value to `i`.
  /// When being read (decoded), Integer field value `i` will be mapped to `.value(i)`.
  case value(Int64)

  public init(integerLiteral value: Int64) {
    self = .value(value)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(Int64.self)
    self = .value(value)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case let .increment(value):
      try container.encode(FieldValue.increment(value))
    case let .value(value):
      try container.encode(value)
    }
  }
}

/// Wraps around FieldValue.increment(_ i: Double) to support modeling Double
/// typed fields with one type.
///
/// Example:
/// struct CustomModel {
///   var doubleValue: IncrementableDouble
/// }
public enum IncrementableDouble: Codable, Equatable, Hashable, ExpressibleByFloatLiteral {
  public typealias FloatLiteralType = Double

  /// When being written (encoded), `.increment(d)` will be mapped to
  /// `FieldValue.increment(d)`, which requests the server to increment the value
  /// of the field by `d`.
  /// Reading (decoding) will never create a `.increment`.
  case increment(Double)

  /// When being written (encoded), `.value(d)` will set the field value to `d`.
  /// When being read (decoded), Integer field value `d` will be mapped to `.value(d)`.
  case value(Double)

  public init(floatLiteral value: Double) {
    self = .value(value)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(Double.self)
    self = .value(value)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case let .increment(value):
      try container.encode(FieldValue.increment(value))
    case let .value(value):
      try container.encode(value)
    }
  }
}

/// Wraps around `FieldValue.arrayUnion` and `FieldValue.arrayRemove` to support
/// modeling array fields that can be changed without sending the entire new array.
///
/// Example:
/// struct CustomModel {
///   var array: OperatableArray<String>
/// }
/// then sending CustomModel(array: OperatableArray<String>.union("a")) to
/// firestore will add "a" to the array-typed field.
public enum OperatableArray<T>: Codable, Equatable where T: Codable, T: Equatable {
  /// When being written (encoded), it is mapped to `FieldValue.arrayUnion` which
  /// adds the values to the value of the target field.
  /// Reading (decoding) should never create a `.union`.
  case union([T])

  /// When being written (encoded), it is mapped to `FieldValue.arrayRemove` which
  /// removes the values to the value of the target field.
  /// Reading (decoding) should never create a `.remove`.
  case remove([T])

  /// When being written (encoded), `.value(arr)` will set the field value to `arr`.
  /// When being read (decoded), array field value `arr` will be mapped to `.value(arr)`.
  case value([T])

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode([T].self)
    self = .value(value)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case let .union(value):
      try container.encode(FieldValue.arrayUnion(value))
    case let .remove(value):
      try container.encode(FieldValue.arrayRemove(value))
    case let .value(value):
      try container.encode(value)
    }
  }
}
