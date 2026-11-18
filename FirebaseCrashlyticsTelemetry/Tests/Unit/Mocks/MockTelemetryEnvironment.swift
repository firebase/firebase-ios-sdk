// Copyright 2026 Google LLC
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

@testable import FirebaseCrashlyticsTelemetry

struct MockTelemetryEnvironment: TelemetryEnvironmentInfo {
  var bundleIdentifier: String? = "com.example.testapp"
  var appVersion: String? = "2.1.0"
  var appBuildId: String? = "42"
  var sdkVersion: String = "13.0.0"
  var osName: String? = "ios"
  var osVersion: String? = "18.2"
  var deviceManufacturer: String? = "Apple"
  var deviceModelIdentifier: String? = "iPhone16,2"
  var deviceArch: String? = "arm64"
  var deviceCores: Int = 6
  var deviceRamBytes: Int = 8_589_934_592
  var isSimulator: Bool = true
}
