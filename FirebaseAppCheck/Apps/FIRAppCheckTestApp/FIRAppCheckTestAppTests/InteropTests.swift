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

  /// Section 8 of the v12 E2E plan: the Swift/Objective-C boundary.
  ///
  /// v12 rewrote App Check Core in Swift while `FirebaseAppCheck` stayed
  /// Objective-C, so every value a caller sees now crosses a language boundary
  /// that did not exist in v11. These cases pin the three things that boundary
  /// can silently change: the type a value arrives as, the error domain it is
  /// reported in, and the queue it is delivered on.
  ///
  /// Isolation comes from `TestProviderRegistry`, which keys providers by app
  /// name, so these cases do not contend for a process-global factory.
  /// Serialization is retained only to keep notification observers from
  /// overlapping, since `NotificationCenter.default` genuinely is shared.
  @Suite(.serialized, .tags(.interop))
  struct `Language interoperability` {
    /// INT-02: the async/await entry point returns a non-optional token.
    ///
    /// The completion-handler API vends `(AppCheckToken?, Error?)`, a shape
    /// that permits the nonsensical "both nil" and "both non-nil" cases. The
    /// async projection is only worth having if it collapses that into a
    /// non-optional return or a throw, so check that it does.
    @Test
    func `Async token request returns a non-optional token`() async throws {
      let fixture = try TestApp(caseID: "INT-02")
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))

      let token = try await appCheck.token(forcingRefresh: false)

      // Deliberately not `#require`: the compiler already guarantees
      // non-optionality here, and that guarantee is the assertion. What is
      // worth checking is that a real value came across, not a bridged empty.
      #expect(!token.token.isEmpty)
      #expect(token.expirationDate > Date())
      #expect(fixture.provider.standardCallCount == 1)
    }

    /// INT-02 (failure half): a provider throw must surface as a Swift throw.
    @Test
    func `Async token request throws when the provider fails`() async throws {
      let fixture = try TestApp(caseID: "INT-02-throw")
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))

      fixture.provider.standardOutcome = { _ in
        .failure(NSError(domain: "InteropTests.Synthetic", code: 42))
      }

      await #expect(throws: (any Error).self) {
        _ = try await appCheck.token(forcingRefresh: false)
      }
    }

    /// INT-03/INT-04: which domain and code does a Swift caller actually see?
    ///
    /// The plan predicted `com.google.app_check_core`, the App Check Core
    /// domain. That is wrong for this layer: `FIRAppCheckErrorUtil` translates
    /// core errors into `com.firebase.appCheck` before they reach a caller, so
    /// the core domain is an implementation detail a Firebase user never sees.
    /// The core domain remains correct for direct `AppCheckCore` consumers.
    @Test
    func `Provider errors are translated into the Firebase error domain`() async throws {
      let fixture = try TestApp(caseID: "INT-03")
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))

      let synthetic = NSError(domain: "InteropTests.Synthetic", code: 42)
      fixture.provider.standardOutcome = { _ in .failure(synthetic) }

      do {
        _ = try await appCheck.token(forcingRefresh: false)
        Issue.record("Expected the scripted provider failure to propagate.")
      } catch {
        let nsError = error as NSError
        #expect(
          nsError.domain == AppCheckErrorDomain,
          """
          Expected the public domain \(AppCheckErrorDomain), saw \
          \(nsError.domain). An untranslated error is leaking the internal \
          domain to callers.
          """
        )
        #expect(nsError.code == AppCheckErrorCode.unknown.rawValue)

        // The original must be preserved. Translation that discards the cause
        // makes provider bugs undiagnosable from a crash report.
        let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        #expect(underlying?.domain == synthetic.domain)
        #expect(underlying?.code == synthetic.code)
      }
    }

    /// INT-04 `[DECISION]`: can Swift catch the typed enum, or only `NSError`?
    ///
    /// `FIRAppCheckErrorCode` is declared with `NS_ERROR_ENUM`, which is what
    /// makes `catch AppCheckErrorCode.unsupported` legal Swift. Whether it
    /// actually matches depends on the error surviving translation with its
    /// code intact, so drive a core-domain error through the mapping and try
    /// the typed catch.
    @Test
    func `A core error code is catchable as a typed Swift enum case`() async throws {
      let fixture = try TestApp(caseID: "INT-04")
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))

      // Code 4 is GACAppCheckErrorCodeUnsupported, which maps to
      // FIRAppCheckErrorCodeUnsupported.
      fixture.provider.standardOutcome = { _ in
        .failure(NSError(domain: "com.google.app_check_core", code: 4))
      }

      do {
        _ = try await appCheck.token(forcingRefresh: false)
        Issue.record("Expected the scripted provider failure to propagate.")
      } catch AppCheckErrorCode.unsupported {
        // The documented outcome: the typed catch matches.
      } catch {
        let nsError = error as NSError
        Issue.record(
          """
          Typed catch did not match. Swift callers must fall back to inspecting \
          NSError. Saw domain \(nsError.domain), code \(nsError.code).
          """
        )
      }
    }

    /// INT-05 `[DECISION]`: which queue runs the completion handler?
    ///
    /// v11 resolved completions on the main queue, so UI code written against
    /// it updates views directly from the block. If v12 moved that to a
    /// background queue the change is silent at compile time and shows up as a
    /// Main Thread Checker violation in someone else's app.
    @Test
    func `Completion handlers are delivered on the main thread`() async throws {
      let fixture = try TestApp(caseID: "INT-05")
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))

      let wasMainThread = await withCheckedContinuation { continuation in
        appCheck.token(forcingRefresh: false) { _, _ in
          continuation.resume(returning: Thread.isMainThread)
        }
      }

      #expect(
        wasMainThread,
        """
        The completion handler ran off the main thread. v11 delivered on the \
        main queue, so this is a silent source break for callers that touch \
        UIKit from the block.
        """
      )
    }

    /// INT-06 `[DECISION]`: the token-change notification's queue and payload.
    ///
    /// Firebase surfaces refreshes as a `NotificationCenter` post rather than
    /// the core's `GACAppCheckTokenDelegate`. Two things are worth pinning: it
    /// arrives on the main queue (v11 parity), and the `userInfo` keys carry
    /// what their names say.
    @Test
    func `Token change notifications arrive on the main thread`() async throws {
      let fixture = try TestApp(caseID: "INT-06")
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))

      let observed = Observation()
      let observer = NotificationCenter.default.addObserver(
        forName: .AppCheckTokenDidChange,
        object: nil,
        queue: nil
      ) { notification in
        observed.record(
          isMainThread: Thread.isMainThread,
          userInfo: notification.userInfo
        )
      }
      defer { NotificationCenter.default.removeObserver(observer) }

      let token = try await appCheck.token(forcingRefresh: false)

      // The post happens on the main queue after the fetch resolves, so it may
      // not have landed by the time the await returns.
      try await waitUntil { observed.didFire }

      #expect(observed.wasMainThread == true)

      // The header's doc comments for these two keys are swapped relative to
      // the implementation in FIRAppCheck.m. Assert the implementation, which
      // is the shipped contract, so a future doc fix does not "fix" the code.
      #expect(observed.userInfo?[AppCheckTokenNotificationKey] as? String == token.token)
      #expect(
        observed.userInfo?[AppCheckAppNameNotificationKey] as? String == fixture.app.name
      )
    }

    // MARK: - Helpers

    /// Collects what a notification observer saw, across threads.
    private final class Observation: @unchecked Sendable {
      private let lock = NSLock()
      private var _wasMainThread: Bool?
      private var _userInfo: [AnyHashable: Any]?

      var didFire: Bool { lock.withLock { _wasMainThread != nil } }
      var wasMainThread: Bool? { lock.withLock { _wasMainThread } }
      var userInfo: [AnyHashable: Any]? { lock.withLock { _userInfo } }

      func record(isMainThread: Bool, userInfo: [AnyHashable: Any]?) {
        lock.withLock {
          _wasMainThread = isMainThread
          _userInfo = userInfo
        }
      }
    }

    /// Polls `condition` until it holds or the budget expires.
    ///
    /// The budget exists so a regression fails as a timeout with a message
    /// rather than hanging the whole suite.
    private func waitUntil(
      timeout: TimeInterval = 2.0,
      _ condition: @Sendable () -> Bool
    ) async throws {
      let deadline = Date().addingTimeInterval(timeout)
      while !condition() {
        if Date() >= deadline {
          Issue.record("Timed out after \(timeout)s waiting for the notification.")
          return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
      }
    }
  }
#endif  // canImport(Testing) && !os(macOS) && !targetEnvironment(macCatalyst)
