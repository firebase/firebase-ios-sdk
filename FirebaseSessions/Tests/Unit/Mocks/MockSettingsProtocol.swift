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

@testable import FirebaseSessions
import Foundation

class MockSettingsProtocol: SettingsProtocol {
  var updateSettingsCalled = false

  func updateSettings() {
    updateSettingsCalled = true
  }

  var sessionsEnabled: Bool = true

  var samplingRate: Double = 1.0

  var sessionTimeout: TimeInterval = 30 * 60
}
