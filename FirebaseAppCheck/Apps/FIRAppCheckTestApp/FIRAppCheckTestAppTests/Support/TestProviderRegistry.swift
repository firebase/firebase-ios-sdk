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

@testable import FIRAppCheckTestApp
import FirebaseAppCheck
import FirebaseCore
import Foundation

/// The single App Check provider factory for the whole test bundle, routing
/// each `FirebaseApp` to a provider registered under its name.
///
/// `AppCheck.setAppCheckProviderFactory` is process-global and last-writer-wins,
/// while the provider it vends is not created until the first token request.
/// Any test that installs its own factory therefore owns a window, stretching
/// from the call until its first fetch, in which another test can replace the
/// factory underneath it. Both tests then talk to the wrong provider.
///
/// That is not hypothetical: it is what happened here. `@Suite(.serialized)`
/// orders tests *within* a suite but Swift Testing still runs separate suites
/// concurrently, so two harnesses raced and one suite's call count landed on
/// the other's provider (0 where 1 was expected, 2 where 1 was expected).
///
/// Serializing everything would have hidden the race rather than removed it,
/// and would have serialized the suite against the Objective-C XCTest cases
/// too, which Swift Testing does not coordinate with at all. Keying on
/// `app.name` removes the shared mutable state instead: the global factory is
/// written once, and each test owns a distinct key.
@objc(AppCheckTestProviderRegistry)
public final class TestProviderRegistry: NSObject, AppCheckProviderFactory, @unchecked Sendable {
  @objc public static let shared = TestProviderRegistry()

  private let lock = NSRecursiveLock()
  private var providers: [String: any AppCheckProvider] = [:]
  private var isInstalled = false

  /// Makes the registry the process-wide factory. Safe to call repeatedly.
  ///
  /// Apps with no registered provider fall through to whatever the host app
  /// installed at launch, so the pre-existing tests that drive the default app
  /// through `AppDelegate` keep the provider they expect.
  ///
  /// The install happens while holding the lock. Setting the flag first and
  /// installing afterwards leaves a window in which a second caller sees
  /// "already installed", returns, and configures its app while the *previous*
  /// factory is still the live one, so that app silently gets the wrong
  /// provider. That window is small and the resulting failure looks like a
  /// flake in an unrelated test, which is exactly what it looked like here.
  @objc public func install() {
    lock.withLock {
      guard !isInstalled else { return }
      AppCheck.setAppCheckProviderFactory(self)
      isInstalled = true
    }
  }

  /// Binds `provider` to `appName`.
  ///
  /// Must happen before the app's first token request, since that is when the
  /// factory is consulted. Registering before `FirebaseApp.configure` is the
  /// safest ordering and the one the harness uses.
  @objc(register:forAppNamed:)
  public func register(_ provider: any AppCheckProvider, forAppNamed appName: String) {
    // One critical section, so the binding is visible to anything that can
    // observe the factory being installed. Requires a recursive lock.
    lock.withLock {
      install()
      providers[appName] = provider
    }
  }

  /// Drops the binding for `appName`.
  ///
  /// App names are unique per test, so a leaked entry cannot corrupt a later
  /// test, but it does pin the provider and everything it captured in memory
  /// for the lifetime of the run.
  @objc(unregisterAppNamed:)
  public func unregisterApp(named appName: String) {
    lock.withLock { _ = providers.removeValue(forKey: appName) }
  }

  // MARK: - AppCheckProviderFactory

  public func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
    if let registered = lock.withLock({ providers[app.name] }) {
      return registered
    }
    return AppDelegate.installedProviderFactory?.createProvider(with: app)
  }
}
