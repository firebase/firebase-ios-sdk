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

/// Class that manages the local overrides configs related to the library.
class LocalOverrideSettings: SettingsProvider {
  // This will disable Sessions SDK Events, but not Settings requests.
  // If any apps use this flag to disable the Firebase Sessions SDK,
  // keep in mind this may break metrics future features with products like
  // FirePerf and Crashlytics. As a result, we would recommend apps
  // use another way to disable data collection (like disabling it via
  // the product public data collection APIs themselves).
  // This flag is internal and may break in the future.
  static let PlistKey_sessions_enabled = "FirebaseSessionsEnabled"
  static let PlistKey_sessions_timeout = "FirebaseSessionsTimeout"
  static let PlistKey_sessions_samplingRate = "FirebaseSessionsSampingRate"

  var sessionsEnabled: Bool? {
    let session_enabled = plistValueForConfig(configName: LocalOverrideSettings
      .PlistKey_sessions_enabled) as? Bool
    if session_enabled != nil {
      return Bool(session_enabled!)
    }
    return nil
  }

  var sessionTimeout: TimeInterval? {
    let timeout = plistValueForConfig(configName: LocalOverrideSettings
      .PlistKey_sessions_timeout) as? Double
    if timeout != nil {
      return Double(timeout!)
    }
    return nil
  }

  var samplingRate: Double? {
    let rate = plistValueForConfig(configName: LocalOverrideSettings
      .PlistKey_sessions_samplingRate) as? Double
    if rate != nil {
      return Double(rate!)
    }
    return nil
  }

  private func plistValueForConfig(configName: String) -> Any? {
    return Bundle.main.infoDictionary?[configName]
  }
}

typealias LocalOverrideSettingsProvider = LocalOverrideSettings
extension LocalOverrideSettingsProvider {
  func updateSettings() {
    // Nothing to be done since there is nothing to be updated.
  }

  func isSettingsStale() -> Bool {
    // Settings are never stale since all of these are local settings from Plist
    return false
  }
}
