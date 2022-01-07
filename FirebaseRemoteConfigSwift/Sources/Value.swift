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

/// Implements subscript overloads to enable Remote Config values to be accessed
/// in a type-safe way directly from the current config.
public extension RemoteConfig {
  subscript(stringValue key: String) -> String {
    guard let value = configValue(forKey: key).stringValue else {
      // An empty string is the historical behavior for an non-existent key.
      return ""
    }
    return value
  }

  subscript(intValue key: String) -> Int {
    return configValue(forKey: key).numberValue.intValue
  }

  subscript(uintValue key: String) -> UInt {
    return configValue(forKey: key).numberValue.uintValue
  }

  subscript(numberValue key: String) -> NSNumber {
    return configValue(forKey: key).numberValue
  }

  subscript(floatValue key: String) -> Float {
    return configValue(forKey: key).numberValue.floatValue
  }

  subscript(doubleValue key: String) -> Double {
    return configValue(forKey: key).numberValue.doubleValue
  }

  subscript(boolValue key: String) -> Bool {
    return configValue(forKey: key).boolValue
  }

  subscript(dataValue key: String) -> Data {
    return configValue(forKey: key).dataValue
  }

  subscript(jsonValue key: String) -> [String: AnyHashable]? {
    guard let value = configValue(forKey: key).jsonValue as? [String: AnyHashable] else {
      // nil is the historical behavior for failing to extract JSON.
      return nil
    }
    return value
  }
}
