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

/// Storage addresses as defined by App Check v11, transcribed from the
/// `11.3.2` tag of `google/app-check`.
///
/// These values are deliberately hardcoded rather than derived from the
/// AppCheckCore implementation. Deriving them would make the comparison
/// circular and unable to detect drift. They encode the frozen on-disk
/// contract that shipped to users.
///
/// Provenance, all at tag `11.3.2`:
/// - `GACAppCheck.m`: `app_check_token.%@.%@`
/// - `GACAppCheckStorage.m`: service `com.google.app_check_core.token_storage`
/// - `GACAppAttestArtifactStorage.m`: `app_check_app_attest_artifact.%@`
/// - `GACAppAttestKeyIDStorage.m`: `app_attest_keyID.%@`
/// - `GACAppAttestProvider.m`: key suffix `%@.%@` of service and resource
///
/// A drift in any of these relocates stored state without breaking decoding,
/// which silently orphans every existing user's cache. The decoder still
/// works; it is simply reading from an address nothing was ever written to.
enum LegacyStorageAddress {
  // MARK: - Frozen constants

  /// Keychain service for the App Check token.
  static let tokenKeychainService = "com.google.app_check_core.token_storage"

  /// Keychain service for the App Attest artifact.
  static let artifactKeychainService = "com.firebase.app_check.app_attest_artifact_storage"

  /// `UserDefaults` suite holding the App Attest key ID.
  static let keyIDSuiteName = "com.firebase.GACAppAttestKeyIDStorage"

  /// App Check error domain.
  static let errorDomain = "com.google.app_check_core"

  // MARK: - Derived addresses

  /// Composes the service name for a Firebase app.
  ///
  /// `FIRAppCheck.m`: `[NSString stringWithFormat:@"FirebaseApp:%@", app.name]`
  static func serviceName(appName: String) -> String {
    "FirebaseApp:\(appName)"
  }

  /// Composes the resource name for a Firebase app.
  ///
  /// `FIRAppCheck.m`: `projects/%@/apps/%@` of project ID and Google app ID.
  static func resourceName(projectID: String, googleAppID: String) -> String {
    "projects/\(projectID)/apps/\(googleAppID)"
  }

  /// Composes the App Attest storage key suffix.
  ///
  /// `GACAppAttestProvider.m`: `%@.%@` of service and resource names.
  static func keySuffix(serviceName: String, resourceName: String) -> String {
    "\(serviceName).\(resourceName)"
  }

  /// Keychain account for the cached App Check token.
  static func tokenKey(serviceName: String, resourceName: String) -> String {
    "app_check_token.\(serviceName).\(resourceName)"
  }

  /// Keychain account for the App Attest artifact.
  static func artifactKey(keySuffix: String) -> String {
    "app_check_app_attest_artifact.\(keySuffix)"
  }

  /// `UserDefaults` key for the App Attest key ID, within ``keyIDSuiteName``.
  static func keyIDKey(keySuffix: String) -> String {
    "app_attest_keyID.\(keySuffix)"
  }

  // MARK: - Convenience

  /// Every address a single Firebase app configuration maps to.
  struct Resolved: Sendable {
    let serviceName: String
    let resourceName: String
    let keySuffix: String
    let tokenKey: String
    let artifactKey: String
    let keyIDKey: String
  }

  /// Resolves all storage addresses for a Firebase app configuration.
  static func resolve(appName: String,
                      projectID: String,
                      googleAppID: String) -> Resolved {
    let service = serviceName(appName: appName)
    let resource = resourceName(projectID: projectID, googleAppID: googleAppID)
    let suffix = keySuffix(serviceName: service, resourceName: resource)

    return Resolved(
      serviceName: service,
      resourceName: resource,
      keySuffix: suffix,
      tokenKey: tokenKey(serviceName: service, resourceName: resource),
      artifactKey: artifactKey(keySuffix: suffix),
      keyIDKey: keyIDKey(keySuffix: suffix)
    )
  }
}
