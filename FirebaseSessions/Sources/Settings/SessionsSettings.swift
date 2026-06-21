//
// Copyright 2022 Google LLC
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

import Foundation

/// Class that manages the configs related to the settings library
class SessionsSettings: SettingsProtocol {
  private let appInfo: ApplicationInfoProtocol
  private let installations: InstallationsProtocol
  private let sdkDefaults: SDKDefaultSettings
  private let localOverrides: LocalOverrideSettings
  private let remoteSettings: RemoteSettings

  convenience init(appInfo: ApplicationInfoProtocol, installations: InstallationsProtocol) {
    self.init(appInfo: appInfo,
              installations: installations,
              sdkDefaults: SDKDefaultSettings(),
              localOverrides: LocalOverrideSettings(),
              remoteSettings: RemoteSettings(appInfo: appInfo,
                                             downloader: SettingsDownloader(appInfo: appInfo,
                                                                            installations: installations)))
  }

  init(appInfo: ApplicationInfoProtocol,
       installations: InstallationsProtocol,
       sdkDefaults: SDKDefaultSettings,
       localOverrides: LocalOverrideSettings,
       remoteSettings: RemoteSettings) {
    self.appInfo = appInfo
    self.installations = installations
    self.sdkDefaults = sdkDefaults
    self.localOverrides = localOverrides
    self.remoteSettings = remoteSettings
  }

  var sessionsEnabled: Bool {
    // Order of precedence LocalOverrides > Remote Settings > SDK Defaults
    if let sessionEnabled = localOverrides.sessionsEnabled {
      return sessionEnabled
    } else if let sessionEnabled = remoteSettings.sessionsEnabled {
      return sessionEnabled
    }
    return sdkDefaults.sessionsEnabled!
  }

  var sessionTimeout: TimeInterval {
    // Order of precedence LocalOverrides > Remote Settings > SDK Defaults
    if let sessionTimeout = localOverrides.sessionTimeout {
      return sessionTimeout
    } else if let sessionTimeout = remoteSettings.sessionTimeout {
      return sessionTimeout
    }
    return sdkDefaults.sessionTimeout!
  }

  var samplingRate: Double {
    // Order of precedence LocalOverrides > Remote Settings > SDK Defaults
    if let samplingRate = localOverrides.samplingRate {
      return samplingRate
    } else if let samplingRate = remoteSettings.samplingRate {
      return samplingRate
    }
    return sdkDefaults.samplingRate!
  }

  func updateSettings() {
    // Update the settings for all the settings providers
    sdkDefaults.updateSettings()
    remoteSettings.updateSettings()
    localOverrides.updateSettings()
  }
}
