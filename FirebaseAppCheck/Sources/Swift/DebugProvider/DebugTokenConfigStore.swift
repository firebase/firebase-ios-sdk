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

#if SWIFT_PACKAGE
  import FirebaseAppCheck
#endif // SWIFT_PACKAGE

internal import FirebaseCoreExtension

/// Reads App Check debug tokens provisioned by the Firebase CLI
/// (`firebase appcheck:debugtokens:create`) from the Firebase CLI config store on the host
/// machine of a Simulator.
enum DebugTokenConfigStore {
  /// The path of the config store file, relative to the home directory.
  static let relativePath = ".config/configstore/firebase-appcheck.json"

  private static let simulatorHostHomeEnvironmentKey = "SIMULATOR_HOST_HOME"
  private static let tokensKey = "tokens"

  /// Returns the debug token provisioned for a Google App ID, if any. Always returns `nil` when
  /// not running in a Simulator.
  static func debugToken(forGoogleAppID googleAppID: String,
                         environment: [String: String] = ProcessInfo.processInfo
                           .environment) -> String? {
    #if targetEnvironment(simulator)
      guard let hostHome = environment[simulatorHostHomeEnvironmentKey], !hostHome.isEmpty,
            !googleAppID.isEmpty else {
        return nil
      }

      let fileURL = URL(fileURLWithPath: hostHome, isDirectory: true)
        .appendingPathComponent(relativePath, isDirectory: false)
      let data: Data
      do {
        data = try Data(contentsOf: fileURL)
      } catch {
        if !isMissingConfigStoreError(error) {
          AppCheckLogger.log(
            .warning,
            .debugTokenConfigStoreUnreadable,
            "Failed to read App Check debug tokens from ~/\(relativePath): "
              + error.localizedDescription
          )
        }
        return nil
      }

      let json: Any
      do {
        json = try JSONSerialization.jsonObject(with: data)
      } catch {
        logUnparsableConfigStore(error.localizedDescription)
        return nil
      }
      guard let configStore = json as? [String: Any] else {
        logUnparsableConfigStore("expected a JSON object")
        return nil
      }

      guard let tokensValue = configStore[tokensKey] else {
        return nil
      }
      guard let tokens = tokensValue as? [String: Any] else {
        logUnparsableConfigStore("`\(tokensKey)` is not a JSON object")
        return nil
      }

      guard let token = tokens[googleAppID] as? String, !token.isEmpty else {
        return nil
      }
      return token
    #else
      return nil
    #endif // targetEnvironment(simulator)
  }

  private static func logUnparsableConfigStore(_ reason: String) {
    AppCheckLogger.log(
      .warning,
      .debugTokenConfigStoreUnreadable,
      "Failed to parse App Check debug tokens from ~/\(relativePath): \(reason)"
    )
  }

  /// Returns whether an error reading the config store means that it doesn't exist, which isn't
  /// worth a warning.
  static func isMissingConfigStoreError(_ error: Error?) -> Bool {
    guard let error = error as NSError? else {
      return false
    }
    if error.domain == NSCocoaErrorDomain, error.code == NSFileReadNoSuchFileError {
      return true
    }
    guard let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError else {
      return false
    }
    return underlyingError.domain == NSPOSIXErrorDomain && underlyingError.code == Int(ENOTDIR)
  }
}
