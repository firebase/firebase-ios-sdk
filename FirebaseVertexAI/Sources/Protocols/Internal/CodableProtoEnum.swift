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

/// A type that represents a Protocol Buffer raw enum value.
protocol ProtoEnum {
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

  /// Returns the raw string value of the enum.
  var rawValue: String { get }

  /// Create a new instance of the specified type from a raw enum value.
  init(rawValue: String)

  /// Creates a new instance from the ``Kind``'s raw value.
  ///
  /// > Important: A default implementation is provided.
  init(kind: Kind)
}

/// A type that can be decoded from a Protocol Buffer raw enum value.
///
/// Protobuf enums are represented as strings in JSON. A default `Decodable` implementation is
/// provided when conforming to this type.
protocol DecodableProtoEnum: ProtoEnum, Decodable {
  /// Returns the ``VertexLog/MessageCode`` associated with unrecognized (unknown) enum values.
  static var unrecognizedValueMessageCode: VertexLog.MessageCode { get }

  /// Creates a new instance by decoding from the given decoder.
  ///
  /// > Important: A default implementation is provided.
  init(from decoder: any Decoder) throws
}

/// A type that can be encoded as a Protocol Buffer enum value.
///
/// Protobuf enums are represented as strings in JSON. A default `Encodable` implementation is
/// provided when conforming to this type.
protocol EncodableProtoEnum: ProtoEnum, Encodable {
  /// Encodes this value into the given encoder.
  ///
  /// > Important: A default implementation is provided.
  func encode(to encoder: any Encoder) throws
}

/// A type that can be decoded and encoded from a Protocol Buffer raw enum value.
///
/// See ``ProtoEnum``, ``DecodableProtoEnum`` and ``EncodableProtoEnum`` for more details.
protocol CodableProtoEnum: DecodableProtoEnum, EncodableProtoEnum {}

// MARK: - Default Implementations

// Default implementation of `init(kind: Kind)` for types conforming to `ProtoEnum`.
extension ProtoEnum {
  init(kind: Kind) {
    self = Self(rawValue: kind.rawValue)
  }
}

// Default `Decodable` implementation for types conforming to `DecodableProtoEnum`.
extension DecodableProtoEnum {
  // Note: Initializer 'init(from:)' must be declared public because it matches a requirement in
  // public protocol 'Decodable'.
  public init(from decoder: Decoder) throws {
    let rawValue = try decoder.singleValueContainer().decode(String.self)

    self = Self(rawValue: rawValue)

    if Kind(rawValue: rawValue) == nil {
      VertexLog.error(
        code: Self.unrecognizedValueMessageCode,
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

// Default `Encodable` implementation for types conforming to `EncodableProtoEnum`.
extension EncodableProtoEnum {
  // Note: Method 'encode(to:)' must be declared public because it matches a requirement in public
  // protocol 'Encodable'.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
