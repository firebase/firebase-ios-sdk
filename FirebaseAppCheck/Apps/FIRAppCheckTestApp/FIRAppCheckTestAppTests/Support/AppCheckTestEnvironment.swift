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

/// Resolves App Check integration test configuration from the environment.
///
/// No secret is ever stored in source. The debug token is supplied at runtime
/// via the same environment variables the SDK itself reads, so the harness
/// needs no knowledge of its value.
enum AppCheckTestEnvironment {
  private static var environment: [String: String] {
    ProcessInfo.processInfo.environment
  }

  /// Returns a non-empty trimmed value for `key`, or `nil`.
  /// Checks process environment variables, UserDefaults (command line arguments),
  /// and parsed launch arguments.
  private static func value(_ key: String) -> String? {
    if let raw = environment[key] {
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    if let userDefaultValue = UserDefaults.standard.string(forKey: key) {
      let trimmed = userDefaultValue.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    // Parse launch arguments: "-<key> <value>" or "-<key>=<value>"
    let args = ProcessInfo.processInfo.arguments
    for (index, arg) in args.enumerated() {
      if arg == "-\(key)" || arg == "--\(key)" {
        if index + 1 < args.count {
          let next = args[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
          if !next.starts(with: "-"), !next.isEmpty {
            return next
          }
        }
      } else if arg.starts(with: "-\(key)=") || arg.starts(with: "--\(key)=") {
        let parts = arg.split(separator: "=", maxSplits: 1)
        if parts.count == 2 {
          let val = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
          if !val.isEmpty { return val }
        }
      }
    }
    return nil
  }

  // MARK: - Credentials

  /// The App Check debug token, resolved with the SDK's own precedence:
  /// `AppCheckDebugToken` first, then the legacy `FIRAAppCheckDebugToken`.
  static var debugToken: String? {
    value("AppCheckDebugToken") ?? value("FIRAAppCheckDebugToken")
  }

  /// Whether a debug token is available for live backend exchange.
  static var hasDebugToken: Bool { debugToken != nil }

  /// Path to a `GoogleService-Info.plist` for live backend tests.
  ///
  /// Defaults to the conventional in-repo location, which is gitignored.
  static var plistPath: String? {
    if let explicit = value("APP_CHECK_PLIST_PATH") { return explicit }
    return Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
  }

  /// Whether a real Firebase configuration is available.
  static var hasLiveCredentials: Bool {
    plistPath != nil && hasDebugToken
  }

  // MARK: - Hardware and backend capabilities

  /// Whether the tests are running on physical hardware.
  ///
  /// App Attest and DeviceCheck both require a real device; neither is
  /// available in the Simulator.
  static var isPhysicalDevice: Bool {
    #if targetEnvironment(simulator)
      return false
    #else
      return true
    #endif
  }

  /// Whether a valid DeviceCheck private key is registered with the App Check
  /// backend.
  ///
  /// This is opt-in rather than inferred. A revoked or missing key produces a
  /// backend rejection that is indistinguishable from an SDK regression, so
  /// DeviceCheck exchange tests stay disabled until this is set explicitly.
  static var hasDeviceCheckBackend: Bool {
    value("APP_CHECK_DEVICE_CHECK_READY") != nil
  }

  /// Whether the reCAPTCHA Enterprise SDK is linked and a site key is present.
  ///
  /// reCAPTCHA is iOS and visionOS only.
  ///
  /// Deliberately unprefixed: `AppDelegate` already reads this exact name, so
  /// a single variable has to configure both the app and the tests.
  static var recaptchaSiteKey: String? {
    value("RECAPTCHA_SITE_KEY")
  }
}
