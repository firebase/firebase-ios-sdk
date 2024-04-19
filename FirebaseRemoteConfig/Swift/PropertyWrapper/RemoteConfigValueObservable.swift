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
import FirebaseCore
import SwiftUI

extension Notification.Name {
  // Listens to FirebaseRemoteConfig SDK if new configs are activated.
  static let onRemoteConfigActivated = Notification.Name("FIRRemoteConfigActivateNotification")
}

// Make sure this key is consistent with kFIRGoogleAppIDKey in FirebaseCore SDK
let FirebaseRemoteConfigAppNameKey = "FIRAppNameKey"

@available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
class RemoteConfigValueObservable<T: Decodable>: ObservableObject {
  @Published var configValue: T
  private let key: String
  private let remoteConfig: RemoteConfig
  private let fallbackValue: T

  init(key: String, fallbackValue: T) {
    self.key = key
    remoteConfig = RemoteConfig.remoteConfig()
    self.fallbackValue = fallbackValue
    // Initialize with fallback value
    configValue = fallbackValue
    // Check cached remote config value
    do {
      let configValue: RemoteConfigValue = remoteConfig[key]
      if configValue.source == .remote || configValue.source == .default {
        self.configValue = try remoteConfig[key].decoded()
      } else {
        self.configValue = fallbackValue
      }
    } catch {
      configValue = fallbackValue
    }
    NotificationCenter.default.addObserver(
      self, selector: #selector(configDidActivate), name: .onRemoteConfigActivated, object: nil
    )
  }

  @objc func configDidActivate(notification: NSNotification) {
    // This feature is only available in the default app.
    let appName = notification.userInfo?[FirebaseRemoteConfigAppNameKey] as? String
    if FirebaseApp.app()?.name != appName {
      return
    }
    do {
      let configValue: RemoteConfigValue = remoteConfig[key]
      if configValue.source == .remote {
        self.configValue = try remoteConfig[key].decoded()
      }
    } catch {
      // Suppresses a hard failure if decoding failed.
    }
  }
}
