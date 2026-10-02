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

/// A disposable `FirebaseApp` for a single test case, with a scripted provider
/// already bound to it.
///
/// This deliberately stops short of creating the `AppCheck` instance. Tests
/// call `AppCheck.appCheck(app:)`, set `isTokenAutoRefreshEnabled`, and call
/// `token(forcingRefresh:)` for themselves, so the sequence of public API calls
/// is visible in the test body and can be read against the App Check
/// documentation line by line. Wrapping those calls would save a line or two
/// per case at the cost of the exact thing a reviewer of a port needs to see.
///
/// What this *does* own is the scaffolding that is not App Check API and that
/// no reader learns anything from: a unique app name, binding the provider,
/// suppressing the launch-time refresh, and cleanup.
struct TestApp {
  /// The `FirebaseApp` name, unique per instance.
  ///
  /// App Check caches tokens in the Keychain under an address derived from the
  /// app name and project, so two cases sharing a name also share a cache and
  /// one case's cold start becomes another's warm read, with ordering deciding
  /// whether either passes.
  let name: String

  let app: FirebaseApp
  let provider: ProgrammableProvider

  /// The Keychain address matching this app, for direct-probe assertions.
  let storageAddress: LegacyStorageAddress.Resolved

  private static let projectID = "appcheck-harness"
  /// Must be hex after the `ios:` segment; `FirebaseApp.configure` validates it.
  private static let googleAppID = "1:123456789:ios:abc123"

  /// The UserDefaults key `FIRAppCheckSettings` reads auto-refresh from.
  ///
  /// Mirrors a constant that is private to `FIRAppCheckSettings.m`
  /// (`kFIRAppCheckTokenAutoRefreshEnabledUserDefaultsPrefix` plus the app
  /// name). `Public API contract` asserts behaviourally that App Check still
  /// honours this format, so a rename surfaces as one clear failure there
  /// rather than as flakiness spread across every case here.
  static func autoRefreshDefaultsKey(appName: String) -> String {
    "FIRAppCheckTokenAutoRefreshEnabled_\(appName)"
  }

  /// Configures a fresh `FirebaseApp` whose App Check provider is scripted.
  ///
  /// - Parameters:
  ///   - caseID: Plan case identifier, used in the app name so a failure in
  ///     the log points at the case that produced it.
  ///   - autoRefresh: Whether the SDK's background refresh timer is armed.
  ///     Defaults to `false` so a timer cannot fire mid-assertion and change a
  ///     call count underneath the test.
  init(caseID: String, autoRefresh: Bool = false) throws {
    let appName = "AppCheckTest-\(caseID)-\(UUID().uuidString.prefix(8))"

    let provider = ProgrammableProvider()
    // Bind the provider to this app's name rather than installing a global
    // factory. A global install is only correct if nothing else installs one
    // before the first token request, and concurrent suites do exactly that.
    TestProviderRegistry.shared.register(provider, forAppNamed: appName)

    // Settle auto-refresh *before* configuring, not after.
    //
    // App Check is built during `FirebaseApp.configure`, and
    // `AppCheckCoreTokenRefresher` schedules a refresh the moment it is
    // constructed with auto-refresh on: the initial result has status `.never`,
    // whose next refresh date is `Date()`, already in the past, so a provider
    // call is dispatched straight onto the refresh queue.
    //
    // That call races the test body, and when it wins, the provider answers
    // with its *default* outcome and caches the result. A test that then
    // scripts a 240s TTL reads back 3600s; one that scripts a failure reads a
    // cached success; one that sets a latency measures nothing. Each run fails
    // a different case, which reads as flakiness rather than as a fixture bug.
    //
    // `FIRAppCheckSettings` consults UserDefaults first, ahead of the
    // Info.plist key and the app's `isDataCollectionDefaultEnabled`, so seeding
    // that key is the only hook that lands early enough. Assigning
    // `isTokenAutoRefreshEnabled`, or clearing data collection, after
    // `AppCheck.appCheck(app:)` is already too late.
    UserDefaults.standard.set(
      autoRefresh,
      forKey: Self.autoRefreshDefaultsKey(appName: appName)
    )

    let options = FirebaseOptions(
      googleAppID: Self.googleAppID,
      gcmSenderID: "123456789"
    )
    options.projectID = Self.projectID
    options.apiKey = "harness-api-key"
    FirebaseApp.configure(name: appName, options: options)

    guard let app = FirebaseApp.app(name: appName) else {
      throw TestAppError.configurationFailed(appName)
    }

    name = appName
    self.app = app
    self.provider = provider
    storageAddress = LegacyStorageAddress.resolve(
      appName: appName,
      projectID: Self.projectID,
      googleAppID: Self.googleAppID
    )
  }

  /// Removes the app, its provider binding, and any token it cached.
  ///
  /// Keychain items outlive the process, so skipping this would let one run
  /// seed the next and silently convert a cold-start case into a cache hit.
  func tearDown() async {
    TestProviderRegistry.shared.unregisterApp(named: name)
    UserDefaults.standard.removeObject(
      forKey: Self.autoRefreshDefaultsKey(appName: name)
    )
    KeychainProbe.remove(
      service: LegacyStorageAddress.tokenKeychainService,
      account: storageAddress.tokenKey
    )
    await withCheckedContinuation { continuation in
      app.delete { _ in continuation.resume() }
    }
  }

  enum TestAppError: Error, CustomStringConvertible {
    case configurationFailed(String)

    var description: String {
      switch self {
      case let .configurationFailed(name):
        "FirebaseApp.configure did not produce an app named \(name)."
      }
    }
  }
}
