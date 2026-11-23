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

import OpenTelemetryApi

extension SemanticConventions.Device {
  /// The architecture of the device CPU (e.g., `"arm64"`, `"x86_64"`).
  static let crashlyticsArch = "device.arch"

  /// The number of CPU cores on the device.
  static let crashlyticsCores = "device.cores"

  /// The amount of physical RAM on the device, in bytes.
  static let crashlyticsRam = "device.ram"

  /// Whether the application is running in a simulator.
  static let crashlyticsSimulator = "device.simulator"
}
