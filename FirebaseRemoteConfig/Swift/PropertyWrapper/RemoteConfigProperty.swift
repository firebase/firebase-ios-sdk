/*
 * Copyright 2022 Google LLC
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

#if SWIFT_PACKAGE
  @_exported import FirebaseRemoteConfigInternal
#endif // SWIFT_PACKAGE

import SwiftUI

/// A property wrapper that listens to a Remote Config value.
@available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
@propertyWrapper
public struct RemoteConfigProperty<T: Decodable>: DynamicProperty {
  @StateObject private var configValueObserver: RemoteConfigValueObservable<T>

  /// Remote Config key name for this property
  public let key: String

  public var wrappedValue: T {
    configValueObserver.configValue
  }

  /// Creates an instance by providing a config key.
  ///
  /// - Parameter key: key name
  /// - Parameter fallback: The value to fall back to if the key doesn't exist in remote or default
  /// configs
  public init(key: String, fallback: T) {
    self.key = key

    _configValueObserver = StateObject(
      wrappedValue: RemoteConfigValueObservable<T>(
        key: key,
        fallbackValue: fallback
      )
    )
  }
}
