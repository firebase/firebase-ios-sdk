/*
 * Copyright 2021 Google LLC
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

import Foundation
#if SWIFT_PACKAGE
  @_exported import FirebaseRemoteConfigInternal
#endif // SWIFT_PACKAGE
import FirebaseSharedSwift

public enum RemoteConfigValueCodableError: Error {
  case unsupportedType(String)
}

public extension RemoteConfigValue {
  /// Extracts a RemoteConfigValue JSON-encoded object and decodes it to the requested type.
  ///
  /// - Parameter asType: The type to decode the JSON-object to
  func decoded<Value: Decodable>(asType: Value.Type = Value.self) throws -> Value {
    if asType == Date.self {
      throw RemoteConfigValueCodableError
        .unsupportedType("Date type is not currently supported for " +
          " Remote Config Value decoding. Please file a feature request")
    }
    return try FirebaseDataDecoder()
      .decode(Value.self, from: FirebaseRemoteConfigValueDecoderHelper(value: self))
  }
}

public enum RemoteConfigCodableError: Error {
  case invalidSetDefaultsInput(String)
}

public extension RemoteConfig {
  /// Decodes the given type from the respective Remote Config values.
  ///
  /// - Parameter asType: The type to decode to.
  /// - Throws: An error if the decoding fails.
  /// - Returns: The decoded value; otherwise, an error if one occurred.
  func decoded<Value: Decodable>(asType: Value.Type = Value.self) throws -> Value {
    try decoded(asType: asType, decoder: FirebaseDataDecoder())
  }

  /// Decodes the given type from the respective Remote Config values.
  /// - Parameters:
  ///   - asType: The type to decode to.
  ///   - decoder: The encoder to use to decode the given type.
  /// - Throws: An error if the decoding fails.
  /// - Returns: The decoded value; otherwise, an error if one occurred.
  func decoded<Value: Decodable>(asType: Value.Type = Value.self,
                                 decoder: FirebaseDataDecoder) throws -> Value {
    let keys = allKeys(from: RemoteConfigSource.default) + allKeys(from: RemoteConfigSource.remote)
    let config = keys.reduce(into: [String: FirebaseRemoteConfigValueDecoderHelper]()) {
      $0[$1] = FirebaseRemoteConfigValueDecoderHelper(value: configValue(forKey: $1))
    }
    return try decoder.decode(Value.self, from: config)
  }

  /// Sets config defaults from an encodable struct.
  ///
  /// - Parameter value: The object to use to set the defaults.
  /// - Throws: An error if the encoding fails.
  func setDefaults<Value: Encodable>(from value: Value) throws {
    try setDefaults(from: value, encoder: FirebaseDataEncoder())
  }

  /// Sets config defaults from an encodable struct.
  /// - Parameters:
  ///   - value: The object to use to set the defaults.
  ///   - encoder: The encoder to use to encode the given object.
  /// - Throws: An error if the encoding fails.
  func setDefaults<Value: Encodable>(from value: Value,
                                     encoder: FirebaseDataEncoder) throws {
    guard let encoded = try encoder.encode(value) as? [String: NSObject] else {
      throw RemoteConfigCodableError.invalidSetDefaultsInput(
        "The setDefaults input: \(value), must be a Struct that encodes to a Dictionary"
      )
    }
    setDefaults(encoded)
  }
}
