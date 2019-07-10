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

/// Wraps around a `Optional` such that it explicitly sets the corresponding document field
/// to Null, instead of not setting the field at all.
///
/// When encoded into a Firestore document by `Firestore.Encoder`, an `Optional` field with
/// `nil` value will be skipped, so the resulting document simply will not have the field.
///
/// When setting the field to `Null` instead of skipping it is desired, `ExplicitNull` can be
/// used instead of `Optional`.
public enum ExplicitNull<Wrapped> {
  case none
  case some(Wrapped)

  /// Create a `ExplicitNull` object from `Optional`.
  public init(_ optional: Wrapped?) {
    switch optional {
    case .none:
      self = .none
    case let .some(wrapped):
      self = .some(wrapped)
    }
  }

  /// Get the `Optional` representation of `ExplicitNull`.
  public var value: Wrapped? {
    switch self {
    case .none:
      return .none
    case let .some(wrapped):
      return .some(wrapped)
    }
  }
}

extension ExplicitNull: Equatable where Wrapped: Equatable {}

extension ExplicitNull: Encodable where Wrapped: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .none:
      try container.encodeNil()
    case let .some(wrapped):
      try container.encode(wrapped)
    }
  }
}

extension ExplicitNull: Decodable where Wrapped: Decodable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .none
    } else {
      self = .some(try container.decode(Wrapped.self))
    }
  }
}
