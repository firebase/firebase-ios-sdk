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

#if canImport(Testing)
  import FirebaseAppCheck
  import FirebaseCore
  import Foundation
  import Testing

  /// Values that are part of the shipped contract, pinned to literals.
  ///
  /// Every assertion here compares an SDK symbol against a hard-coded literal
  /// rather than against another SDK symbol. That distinction is the entire
  /// point of the file. Writing
  ///
  /// ```swift
  /// #expect(error.domain == AppCheckErrorDomain)
  /// ```
  ///
  /// passes on every version, including one that renamed the domain, because
  /// both sides move together. Only a literal can catch drift.
  ///
  /// These strings escape the SDK and are matched by code we do not control:
  /// error domains compared in customer `if` statements, notification names
  /// registered by string, `userInfo` keys read out of a dictionary, and
  /// numeric error codes recorded in analytics. Renaming any of them is a
  /// breaking change that no compiler will report, on either side.
  ///
  /// Run this suite against a different Firebase version to get a behavioural
  /// diff; see `VERSION_DIFFING.md` next to this file.
  @Suite(.tags(.interop))
  struct `Public API contract` {
    // MARK: - Errors

    @Test func `Error domain string is unchanged`() {
      #expect(
        AppCheckErrorDomain == "com.firebase.appCheck",
        """
        The public error domain changed. Any app matching on the old string \
        stops recognising App Check errors, and does so silently.
        """
      )
    }

    /// The internal App Check Core domain must *not* be what callers see.
    ///
    /// v12 rewrote App Check Core in Swift, and the natural failure mode of
    /// that rewrite is an untranslated error escaping with the core domain.
    @Test func `The internal core domain is not the public domain`() {
      #expect(AppCheckErrorDomain != "com.google.app_check_core")
    }

    @Test func `Error code raw values are unchanged`() {
      // Persisted in customers' analytics and switched on in shipped apps.
      // Renumbering silently reclassifies every previously recorded error.
      #expect(AppCheckErrorCode.unknown.rawValue == 0)
      #expect(AppCheckErrorCode.serverUnreachable.rawValue == 1)
      #expect(AppCheckErrorCode.invalidConfiguration.rawValue == 2)
      #expect(AppCheckErrorCode.keychain.rawValue == 3)
      #expect(AppCheckErrorCode.unsupported.rawValue == 4)
    }

    // MARK: - Notifications

    @Test func `Token change notification name is unchanged`() {
      #expect(
        Notification.Name.AppCheckTokenDidChange.rawValue
          == "FIRAppCheckAppCheckTokenDidChangeNotification",
        """
        Observers registered by raw string, which is common in Objective-C and \
        in cross-platform wrappers, stop firing.
        """
      )
    }

    @Test func `Notification userInfo keys are unchanged`() {
      #expect(AppCheckTokenNotificationKey == "FIRAppCheckTokenNotificationKey")
      #expect(AppCheckAppNameNotificationKey == "FIRAppCheckAppNameNotificationKey")
    }

    // MARK: - Undocumented keys the SDK still reads

    /// The auto-refresh opt-out is keyed by an undocumented UserDefaults name.
    ///
    /// This is asserted behaviourally rather than by reading a constant,
    /// because the constant is private to `FIRAppCheckSettings`. Seeding the
    /// key and observing that App Check honours it is the only way to detect a
    /// rename from outside the SDK.
    ///
    /// It matters twice over. Apps disable auto-refresh this way across
    /// launches, since the public setter persists to exactly this key. And
    /// this test suite depends on it: suppressing auto-refresh before App
    /// Check is constructed is the only reliable way to stop a launch-time
    /// token fetch, so a silent rename would make many cases here flaky rather
    /// than failing.
    @Test func `Auto refresh opt-out key format is still honoured`() async throws {
      let appName = "Contract-AutoRefreshKey-\(UUID().uuidString.prefix(8))"
      let key = "FIRAppCheckTokenAutoRefreshEnabled_\(appName)"

      UserDefaults.standard.set(false, forKey: key)
      defer { UserDefaults.standard.removeObject(forKey: key) }

      let options = FirebaseOptions(
        googleAppID: "1:123456789:ios:abc123",
        gcmSenderID: "123456789"
      )
      options.projectID = "appcheck-harness"
      options.apiKey = "harness-api-key"
      FirebaseApp.configure(name: appName, options: options)

      let app = try #require(FirebaseApp.app(name: appName))
      defer {
        Task { await withCheckedContinuation { c in app.delete { _ in c.resume() } } }
      }

      let appCheck = try #require(AppCheck.appCheck(app: app))

      #expect(
        appCheck.isTokenAutoRefreshEnabled == false,
        """
        App Check ignored a seeded \(key). Either the UserDefaults key format \
        changed or the resolution order did. Apps that disabled auto-refresh \
        on a previous launch will silently start refreshing again.
        """
      )
    }
  }
#endif  // canImport(Testing)
