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

import SwiftUI
import FirebaseRemoteConfig

@available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
internal class RemoteConfigValueObservable<T: Decodable>: ObservableObject {
  @Published private(set) var configValue: T

  private let key: String
  private let remoteConfig: RemoteConfig
  private var observation: RemoteConfigObsever?

  init(key: String, remoteConfig: RemoteConfig) {
    self.key = key
    self.remoteConfig = remoteConfig
    configValue = try! remoteConfig.configValue(forKey: key).decoded(asType: T.self)
    observation = RemoteConfigObsever(remoteConfig: remoteConfig,
                                      forKey: key) { [weak self] newValue, error in
      if let newValue = newValue {
        self?.configValue = newValue
      }
    }
  }

  deinit {
    self.observation?.dispose()
  }

  class RemoteConfigObsever: NSObject {
    private let observingKeyPath: String
    private var didRemoveObserver: Bool
    private let remoteConfig: RemoteConfig
    private let configValueKey: String
    private let handler: (T?, Error?) -> Void

    init(remoteConfig: RemoteConfig, forKey: String,
         handler: @escaping ((T?, Error?) -> Void)) {
      observingKeyPath = #keyPath(RemoteConfig.lastFetchTime)
      didRemoveObserver = false
      self.remoteConfig = remoteConfig
      configValueKey = forKey
      self.handler = handler

      super.init()

      remoteConfig.addObserver(self, forKeyPath: observingKeyPath, context: nil)
    }

    func dispose() {
      if didRemoveObserver { return }

      didRemoveObserver = true
      remoteConfig.removeObserver(self, forKeyPath: observingKeyPath, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
      guard change != nil, object != nil, keyPath == observingKeyPath else {
        return
      }

      do {
        let newValue = try remoteConfig.decoded(asType: T.self)
        handler(newValue, nil)
      } catch {
        handler(nil, error)
      }
    }
  }
}
