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
import FirebaseRemoteConfig
import FirebaseSharedSwift

public enum RemoteConfigCodableError: Error {
  case jsonValueError
}

public extension RemoteConfigValue {
  /// Extracts a RemoteConfigValue JSON-encoded object and decodes it to the requested type
  ///
  /// - Parameter valueType: The type to decode the JSON-object to
  /// - Parameter decoder: The decoder instance to use to run the encoding.
  func decoded<Value: Decodable>(asType: Value.Type = Value.self,
                                 decoder: FirebaseDataDecoder = FirebaseDataDecoder()) throws
    -> Value {
    guard let jsonValue = self.jsonValue else {
      throw RemoteConfigCodableError.jsonValueError
    }
    return try decoder.decode(Value.self, from: jsonValue)
  }
}

public extension RemoteConfig {
  /// Sets config defaults from an encodable struct.
  ///
  /// - Parameter value: The object to use to set the defaults.
  func setDefaults<Value: Encodable>(from value: Value,
                                     encoder: FirebaseDataEncoder = FirebaseDataEncoder()) throws {
    let encoded = try encoder.encode(value) as! [String: NSObject]
    setDefaults(encoded)
  }
}
