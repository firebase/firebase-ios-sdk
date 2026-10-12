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
  private enum PlistKey: String {
    /// This will disable Sessions SDK Events, but not Settings requests.
    /// If any apps use this flag to disable the Firebase Sessions SDK,
    /// keep in mind this may break metrics future features with products like
    /// FirePerf and Crashlytics. As a result, we would recommend apps
    /// use another way to disable data collection (like disabling it via
    /// the product public data collection APIs themselves).
    /// This flag is internal and may break in the future.
    case sessionsEnabled = "FirebaseSessionsEnabled"
    case sessionsTimeout = "FirebaseSessionsTimeout"
    case sessionsSamplingRate = "FirebaseSessionsSampingRate"
  }

  var sessionsEnabled: Bool? {
    let isEnabled = plistValue(for: .sessionsEnabled)
    return isEnabled as? Bool
  }

  var sessionTimeout: TimeInterval? {
    let timeout = plistValue(for: .sessionsTimeout)
    return timeout as? Double
  }

  var samplingRate: Double? {
    let rate = plistValue(for: .sessionsSamplingRate)
    return rate as? Double
  }

  private func plistValue(for key: PlistKey) -> Any? {
    return Bundle.main.infoDictionary?[key.rawValue]
  }

  func updateSettings() {
    // Nothing to be done since there is nothing to be updated.
  }

  func isSettingsStale() -> Bool {
    // Settings are never stale since all of these are local settings from Plist
    return false
  }
}
