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

import FirebaseRemoteConfig
import SwiftUI

extension Notification.Name {
  // Listens to FirebaseRemoteConfig SDK if new configs are activated.
  static let onRemoteConfigChanged = Notification.Name("FIRRemoteConfigChangeNotification")
}

@available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
internal class RemoteConfigValueObservable<T: Decodable>: ObservableObject {
  @Published var configValue: T
  private let key: String
  private let remoteConfig: RemoteConfig
  private let fallbackValue: T

  init(key: String, fallbackValue: T) {
    self.key = key
    self.remoteConfig = RemoteConfig.remoteConfig()
    self.fallbackValue = fallbackValue
    // Initialize with fallback value
    self.configValue = fallbackValue
    // Check cached remote config value
    do {
      let configValue: RemoteConfigValue = self.remoteConfig[key]
      if configValue.source == .remote || configValue.source == .default {
        self.configValue = try self.remoteConfig[key].decoded()
      } else {
        self.configValue = fallbackValue
      }
    } catch {
      self.configValue = fallbackValue
    }
    NotificationCenter.default.addObserver(
      self, selector: #selector(configDidActivated), name: .onRemoteConfigChanged, object: nil)
  }

  @objc func configDidActivated() {
    do {
      let configValue: RemoteConfigValue = self.remoteConfig[self.key]
      if configValue.source == .remote {
        self.configValue = try self.remoteConfig[self.key].decoded()
      }
    } catch {
    }
  }
}
