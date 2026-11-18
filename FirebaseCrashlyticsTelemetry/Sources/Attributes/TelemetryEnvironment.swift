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

#if SWIFT_PACKAGE
  internal import GoogleUtilities_Environment
#else
  internal import GoogleUtilities
#endif // SWIFT_PACKAGE

/// Provides host application, device, OS, and SDK metadata used to populate OpenTelemetry resource
/// and scope attributes.
protocol TelemetryEnvironmentInfo: Sendable {
  /// The application's bundle identifier (e.g., `com.example.app`).
  var bundleIdentifier: String? { get }

  /// The human-readable app version string (`CFBundleShortVersionString`).
  var appVersion: String? { get }

  /// The app build identifier (`CFBundleVersion`).
  var appBuildId: String? { get }

  /// The Firebase SDK version string.
  var sdkVersion: String { get }

  /// The Apple operating system platform name (e.g., `"ios"`, `"ipados"`, `"macos"`).
  var osName: String? { get }

  /// The operating system version string (e.g., `"18.0"`).
  var osVersion: String? { get }

  /// The device manufacturer name (e.g., `"Apple"`).
  var deviceManufacturer: String? { get }

  /// The hardware model identifier (e.g., `"iPhone15,3"`).
  var deviceModelIdentifier: String? { get }

  /// The CPU architecture (e.g., `"arm64"`, `"x86_64"`).
  var deviceArch: String? { get }

  /// The number of CPU cores on the device.
  var deviceCores: Int { get }

  /// The total physical RAM on the device, in bytes.
  var deviceRamBytes: Int { get }

  /// Whether the app is running in a simulator.
  var isSimulator: Bool { get }
}

/// Default runtime implementation of `TelemetryEnvironmentInfo`.
struct TelemetryEnvironment: TelemetryEnvironmentInfo {
  let bundleIdentifier: String?
  let appVersion: String?
  let appBuildId: String?
  let sdkVersion: String
  let osName: String?
  let osVersion: String?
  let deviceManufacturer: String?
  let deviceModelIdentifier: String?
  let deviceArch: String?
  let deviceCores: Int
  let deviceRamBytes: Int
  let isSimulator: Bool

  init(bundle: Bundle = .main, processInfo: ProcessInfo = .processInfo) {
    bundleIdentifier = bundle.bundleIdentifier
    appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
    appBuildId = bundle.infoDictionary?["CFBundleVersion"] as? String
    sdkVersion = FirebaseVersion()
    osName = GULAppEnvironmentUtil.appleDevicePlatform()
    osVersion = GULAppEnvironmentUtil.systemVersion()
    deviceManufacturer = "Apple"
    deviceModelIdentifier = GULAppEnvironmentUtil.deviceSimulatorModel()
    deviceArch = Self.currentDeviceArch()
    deviceCores = processInfo.processorCount
    deviceRamBytes = Int(clamping: processInfo.physicalMemory)
    isSimulator = GULAppEnvironmentUtil.isSimulator()
  }

  private static func currentDeviceArch() -> String? {
    #if arch(arm64)
      return "arm64"
    #elseif arch(x86_64)
      return "x86_64"
    #elseif arch(arm)
      return "arm"
    #elseif arch(i386)
      return "i386"
    #else
      return nil
    #endif
  }
}
