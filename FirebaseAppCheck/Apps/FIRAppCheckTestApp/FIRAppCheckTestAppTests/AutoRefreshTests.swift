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

#if canImport(Testing) && !os(macOS) && !targetEnvironment(macCatalyst)
  import FirebaseAppCheck
  import FirebaseCore
  import Foundation
  import Testing

  /// Section 6 of the v12 E2E plan: Token auto-refresh procedures.
  ///
  /// Tests auto-refresh configuration, delegate/notification delivery,
  /// and disabling behavior.
  @Suite(.serialized, .tags(.integration))
  struct `Auto-refresh tests` {
    /// REF-02: Verifies that AppCheckTokenDidChange notification is posted
    /// when auto-refresh is active.
    @Test func `Token update notification fires when auto-refresh is enabled`() async throws {
      let fixture = try TestApp(caseID: "REF-02", autoRefresh: true)
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))
      #expect(appCheck.isTokenAutoRefreshEnabled == true)

      let expectation = NotificationExpectation()
      let observer = NotificationCenter.default.addObserver(
        forName: .AppCheckTokenDidChange,
        object: nil,
        queue: .main
      ) { notification in
        if let appName = notification.userInfo?[AppCheckAppNameNotificationKey] as? String,
           appName == fixture.name {
          expectation.fulfill()
        }
      }
      defer { NotificationCenter.default.removeObserver(observer) }

      // Fetch initial token
      let token = try await appCheck.token(forcingRefresh: false)
      #expect(!token.token.isEmpty)

      // Wait briefly for main queue notification delivery if scheduled
      try await expectation.waitForNotification(timeout: 1.0)
      #expect(expectation.wasFulfilled, "Token update notification should fire for the configured app.")
    }

    /// REF-03: When auto-refresh is explicitly disabled, `isTokenAutoRefreshEnabled`
    /// is false and background periodic refresh does not trigger.
    @Test func `Auto-refresh disabled property state is respected`() throws {
      let fixture = try TestApp(caseID: "REF-03", autoRefresh: false)
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))
      #expect(appCheck.isTokenAutoRefreshEnabled == false)
    }

    private final class NotificationExpectation: @unchecked Sendable {
      private let lock = NSLock()
      private var fulfilled = false

      var wasFulfilled: Bool {
        lock.withLock { fulfilled }
      }

      func fulfill() {
        lock.withLock { fulfilled = true }
      }

      func waitForNotification(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
          if wasFulfilled { return }
          try await Task.sleep(nanoseconds: 20_000_000)
        }
      }
    }
  }
#endif  // canImport(Testing) && !os(macOS) && !targetEnvironment(macCatalyst)
