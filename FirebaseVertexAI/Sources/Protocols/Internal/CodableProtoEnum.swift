// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// A type that can be decoded from a Protocol Buffer raw enum value.
///
/// Protobuf enums are represented as strings in JSON. A default `Decodable` implementation is
/// provided when conforming to this type.
protocol DecodableProtoEnum: Decodable, Sendable, Equatable, Hashable {
  /// The type representing the valid values for the protobuf enum.
  ///
  /// > Important: This type must conform to `RawRepresentable` with the `RawValue == String`.
  ///
  /// This is typically a Swift enum, e.g.:
  /// ```
  /// enum Kind: String {
  ///   case north = "WIND_DIRECTION_NORTH"
  ///   case south = "WIND_DIRECTION_SOUTH"
  ///   case east = "WIND_DIRECTION_EAST"
  ///   case west = "WIND_DIRECTION_WEST"
  /// }
  /// ```
  associatedtype Kind: RawRepresentable<String>

  /// Returns the ``VertexLog/MessageCode`` associated with unrecognized (unknown) enum values.
  var unrecognizedValueMessageCode: VertexLog.MessageCode { get }

  /// Create a new instance of the specified type from a raw enum value.
  init(rawValue: String)

  /// Creates a new instance from the ``Kind``'s raw value.
  ///
  /// > Important: A default implementation is provided.
  init(kind: Kind)

  /// Creates a new instance by decoding from the given decoder.
  ///
  /// > Important: A default implementation is provided.
  init(from decoder: Decoder) throws
}

/// Default `Decodable` implementation for types conforming to `DecodableProtoEnum`.
extension DecodableProtoEnum {
  // Note: Initializer 'init(from:)' must be declared public because it matches a requirement in
  // public protocol 'Decodable'.
  public init(from decoder: Decoder) throws {
    let rawValue = try decoder.singleValueContainer().decode(String.self)

    self = Self(rawValue: rawValue)

    if Kind(rawValue: rawValue) == nil {
      VertexLog.error(
        code: unrecognizedValueMessageCode,
        """
        Unrecognized \(Self.self) with value "\(rawValue)":
        - Check for updates to the SDK as support for "\(rawValue)" may have been added; see \
        release notes at https://firebase.google.com/support/release-notes/ios
        - Search for "\(rawValue)" in the Firebase Apple SDK Issue Tracker at \
        https://github.com/firebase/firebase-ios-sdk/issues and file a Bug Report if none found
        """
      )
    }
  }
}

/// Default implementation of `init(kind: Kind)` for types conforming to `DecodableProtoEnum`.
extension DecodableProtoEnum {
  init(kind: Kind) {
    self = Self(rawValue: kind.rawValue)
  }
}

/// A type that can be decoded and encoded from a Protocol Buffer raw enum value.
///
/// See ``DecodableProtoEnum`` for more details.
protocol CodableProtoEnum: DecodableProtoEnum, Encodable {}
