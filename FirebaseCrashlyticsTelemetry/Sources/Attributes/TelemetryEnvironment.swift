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

internal import FirebaseCore
import Foundation

/// Provides host application and SDK metadata used to populate OpenTelemetry resource and scope
/// attributes.
protocol TelemetryEnvironmentInfo: Sendable {
  /// The application's bundle identifier (e.g., `com.example.app`).
  var bundleIdentifier: String? { get }

  /// The human-readable app version string (`CFBundleShortVersionString`).
  var appVersion: String? { get }

  /// The app build identifier (`CFBundleVersion`).
  var appBuildId: String? { get }

  /// The Firebase SDK version string.
  var sdkVersion: String { get }
}

/// Default runtime implementation of `TelemetryEnvironmentInfo`.
struct TelemetryEnvironment: TelemetryEnvironmentInfo {
  let bundleIdentifier: String?
  let appVersion: String?
  let appBuildId: String?
  let sdkVersion: String

  init(bundle: Bundle = .main) {
    bundleIdentifier = bundle.bundleIdentifier
    appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
    appBuildId = bundle.infoDictionary?["CFBundleVersion"] as? String
    sdkVersion = FirebaseVersion()
  }
}
