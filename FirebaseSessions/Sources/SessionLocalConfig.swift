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

/// Protoco defining the loval override values for the SDK settings.
protocol SessionLocalConfigProtocol {
  /// Session enabled flag value.
  var sessionEnabled: Bool? { get }

  /// Session timeout flag value.
  var sessionTimeout: TimeInterval? { get }

  /// Session timeout flag value.
  var sessionSamplingRate: Double? { get }
}

/// Class that manages the local overrides configs related to the library.
class SessionLocalConfig: SessionLocalConfigProtocol {
  static let PlistKey_sessions_enabled = "FirebaseSessionsEnabled"
  static let PlistKey_sessions_timeout = "FirebaseSessionsTimeout"
  static let PlistKey_sessions_samplingRate = "FirebaseSessionsSampingRate"

  var sessionEnabled: Bool? {
    return plistValueForConfig(configName: SessionLocalConfig.PlistKey_sessions_enabled) as? Bool
  }

  var sessionTimeout: TimeInterval? {
    return
      plistValueForConfig(configName: SessionLocalConfig.PlistKey_sessions_timeout) as? TimeInterval
  }

  var sessionSamplingRate: Double? {
    return
      plistValueForConfig(configName: SessionLocalConfig.PlistKey_sessions_samplingRate) as? Double
  }

  private func plistValueForConfig(configName: String) -> Any? {
    return Bundle.main.value(forKey: configName)
  }
}
