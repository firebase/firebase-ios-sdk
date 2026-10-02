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

import FirebaseAppCheck
import FirebaseCore
import Foundation

/// A disposable `FirebaseApp` backed by the real `GoogleService-Info.plist`,
/// for tests that construct a provider directly and talk to the live backend.
///
/// Counterpart to `TestApp`, which uses fake options and a scripted provider.
/// Here the provider under test is built by the test body itself
/// (`DeviceCheckProvider(app:)`, `AppAttestProvider(app:)`, ...), so the only
/// job of this type is to give it a correctly configured app and stay out of
/// the way:
///
/// - Options come from the plist, so no project identifiers live in source.
/// - Auto-refresh is seeded off *before* configure. Otherwise the `AppCheck`
///   instance created during configure immediately asks the installed factory
///   for a provider and starts a real token exchange in the background. That
///   traffic is unrelated to the test, and `app.delete` cancelling it shows
///   up as `I-FAA004002` noise.
/// - An `UnexpectedProvider` is bound to the app name, so if anything does ask
///   App Check itself for a token, it fails loudly instead of silently falling
///   back to the host app's debug factory.
struct LiveApp {
  let name: String
  let app: FirebaseApp

  /// - Parameter caseID: Plan case identifier, used in the app name so a
  ///   failure in the log points at the case that produced it.
  init(caseID: String) throws {
    guard let path = AppCheckTestEnvironment.plistPath,
          let options = FirebaseOptions(contentsOfFile: path) else {
      throw LiveAppError.missingPlist
    }

    let appName = "AppCheckTest-\(caseID)-\(UUID().uuidString.prefix(8))"

    TestProviderRegistry.shared.register(
      UnexpectedProvider(appName: appName),
      forAppNamed: appName
    )
    UserDefaults.standard.set(
      false,
      forKey: TestApp.autoRefreshDefaultsKey(appName: appName)
    )

    FirebaseApp.configure(name: appName, options: options)
    guard let app = FirebaseApp.app(name: appName) else {
      throw LiveAppError.configurationFailed(appName)
    }

    name = appName
    self.app = app
  }

  /// Removes the app, its provider binding, and its auto-refresh override.
  func tearDown() async {
    TestProviderRegistry.shared.unregisterApp(named: name)
    UserDefaults.standard.removeObject(
      forKey: TestApp.autoRefreshDefaultsKey(appName: name)
    )
    await withCheckedContinuation { continuation in
      app.delete { _ in continuation.resume() }
    }
  }

  enum LiveAppError: Error, CustomStringConvertible {
    case missingPlist
    case configurationFailed(String)

    var description: String {
      switch self {
      case .missingPlist:
        "No usable GoogleService-Info.plist. Add one to the app target or set "
          + "APP_CHECK_PLIST_PATH; see E2E_TESTING.md."
      case let .configurationFailed(name):
        "FirebaseApp.configure did not produce an app named \(name)."
      }
    }
  }
}

/// Bound to every `LiveApp` so that a token request routed through App Check,
/// rather than through the provider the test constructed, fails with a clear
/// message.
private final class UnexpectedProvider: NSObject, AppCheckProvider, @unchecked Sendable {
  private let appName: String

  init(appName: String) {
    self.appName = appName
  }

  func getToken() async throws -> AppCheckToken {
    throw unexpected()
  }

  func getLimitedUseToken() async throws -> AppCheckToken {
    throw unexpected()
  }

  private func unexpected() -> NSError {
    NSError(
      domain: "FIRAppCheckTestApp.LiveApp",
      code: -1,
      userInfo: [
        NSLocalizedDescriptionKey:
          "App Check requested a token for \(appName) through its factory. "
          + "Live provider tests must call the provider they construct directly.",
      ]
    )
  }
}
