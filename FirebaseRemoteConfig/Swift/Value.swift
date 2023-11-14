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

/// Implements subscript overloads to enable Remote Config values to be accessed
/// in a type-safe way directly from the current config.
public extension RemoteConfig {
  /// Return a typed RemoteConfigValue for a key.
  /// - Parameter key: A Remote Config key.
  /// - Returns: A typed RemoteConfigValue.
  subscript<T: Decodable>(decodedValue key: String) -> T? {
    return try? configValue(forKey: key).decoded()
  }

  /// Return a Dictionary for a RemoteConfig JSON key.
  /// - Parameter key: A Remote Config key.
  /// - Returns: A Dictionary representing a RemoteConfig JSON value.
  subscript(jsonValue key: String) -> [String: AnyHashable]? {
    guard let value = configValue(forKey: key).jsonValue as? [String: AnyHashable] else {
      // nil is the historical behavior for failing to extract JSON.
      return nil
    }
    return value
  }
}
