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

/// APIs that needs to be implemented by any settings provider
protocol SettingsProvider {
  // API to update the settings
  func updateSettings()

  // API to check if the settings are stale
  func isSettingsStale() -> Bool

  // Config to show if sessions is enabled
  var sessionsEnabled: Bool? { get }

  // Config showing the sampling rate for sessions

  var samplingRate: Double? { get }

  // Background timeout config value before which a new session is generated
  var sessionTimeout: TimeInterval? { get }
}
