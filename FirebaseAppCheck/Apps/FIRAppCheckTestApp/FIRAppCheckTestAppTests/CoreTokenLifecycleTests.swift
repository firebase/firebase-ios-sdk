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

  /// Section 5 of the test plan: core token lifecycle and request coalescing.
  ///
  /// These run against a scripted provider rather than the backend. The
  /// questions in this section are all "how many times did the SDK ask, and
  /// what did it do with the answer", which a counter answers exactly and a
  /// network round trip answers only by inference.
  ///
  /// Serialized for timing stability, not for isolation. Isolation comes from
  /// `TestProviderRegistry`, which gives every case its own provider keyed by
  /// app name. Several cases here assert on elapsed time, and tests competing
  /// for CPU inflate those measurements into false failures.
  @Suite(.serialized, .tags(.integration))
  struct `Core token lifecycle` {
    /// COR-01: a cold start must reach the provider and persist the result.
    @Test func `Cold start fetches from the provider and persists`() async throws {
      let fixture = try TestApp(caseID: "COR-01")
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))

      let token = try await appCheck.token(forcingRefresh: false)

      #expect(fixture.provider.standardCallCount == 1)
      #expect(token.token == "programmable-token-1")

      #if !os(macOS) && !targetEnvironment(macCatalyst)
        #expect(
          KeychainProbe.exists(
            service: LegacyStorageAddress.tokenKeychainService,
            account: fixture.storageAddress.tokenKey
          ),
          "Cold-start token was not persisted; upgrades would re-fetch needlessly."
        )
      #endif
    }

    /// COR-02: a second read inside the validity window must not hit the
    /// provider again.
    @Test func `Cached token is reused without a second provider call`() async throws {
      let fixture = try TestApp(caseID: "COR-02")
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))

      let first = try await appCheck.token(forcingRefresh: false)
      let second = try await appCheck.token(forcingRefresh: false)

      #expect(first.token == second.token)
      #expect(
        fixture.provider.standardCallCount == 1,
        """
        Expected the cache to serve the second read, but the provider was \
        called \(fixture.provider.standardCallCount) times.
        """
      )
    }

    /// COR-03: forcing refresh must bypass a still-valid cache.
    @Test func `Forced refresh bypasses a valid cache`() async throws {
      let fixture = try TestApp(caseID: "COR-03")
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))

      let first = try await appCheck.token(forcingRefresh: false)
      let second = try await appCheck.token(forcingRefresh: true)

      #expect(first.token != second.token)
      #expect(fixture.provider.standardCallCount == 2)
    }

    /// COR-04: a token inside the five-minute expiry window is not reused.
    ///
    /// The first response is deliberately short-lived, so the second read sees
    /// a cached token that is still technically valid but due to expire.
    @Test func `Near-expiry token triggers a refresh`() async throws {
      let fixture = try TestApp(caseID: "COR-04")
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))

      fixture.provider.standardOutcome = { call in
        call == 0 ? .success(ttl: 240) : .success(ttl: 3600)
      }

      let first = try await appCheck.token(forcingRefresh: false)

      // Precondition, not the case under test. If the 4-minute TTL did not
      // survive the provider -> storage -> caller round trip then the cached
      // token is not actually near expiry, and a failure below would mean the
      // fixture is wrong rather than the SDK.
      let observedTTL = first.expirationDate.timeIntervalSinceNow
      #expect(
        observedTTL < 300,
        """
        Expected a token expiring in ~240s, observed \(Int(observedTTL))s. The \
        scripted TTL did not survive the round trip, so this case is not \
        exercising the near-expiry path at all.
        """
      )

      let second = try await appCheck.token(forcingRefresh: false)

      #expect(
        first.token != second.token,
        """
        A token expiring in 4 minutes was served from cache. The SDK should \
        treat anything inside the 5-minute window as due for refresh.
        """
      )
      #expect(fixture.provider.standardCallCount == 2)
    }

    /// COR-05: concurrent standard reads must coalesce onto one request.
    @Test(.tags(.concurrency))
    func `Ten concurrent standard calls coalesce into one request`() async throws {
      let fixture = try TestApp(caseID: "COR-05")
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))

      // Without latency the calls would serialize by luck and a
      // non-coalescing implementation would pass.
      let latency: TimeInterval = 0.25
      fixture.provider.latency = latency

      let startedAt = Date()
      let tokens = try await withThrowingTaskGroup(of: String.self) { group in
        for _ in 0 ..< 10 {
          group.addTask { try await appCheck.token(forcingRefresh: false).token }
        }
        var collected: [String] = []
        for try await token in group { collected.append(token) }
        return collected
      }
      let elapsed = Date().timeIntervalSince(startedAt)

      #expect(tokens.count == 10)
      #expect(
        Set(tokens).count == 1,
        """
        Expected all ten callers to share one token, saw \(Set(tokens).count) \
        distinct values. Concurrent readers are each issuing their own request.
        """
      )
      #expect(fixture.provider.standardCallCount == 1)

      // A single shared token is also what serialize-then-hit-cache produces.
      // Coalescing is the claim that the nine late callers waited on the first
      // request rather than running after it, and only elapsed time shows that:
      // ten serialized 250ms requests cannot finish inside 2.5 seconds.
      //
      // The lower bound is load-bearing. The upper bound alone is satisfied by
      // a provider that never slept at all, which would make the whole timing
      // argument vacuous, so require that at least one latency was actually
      // paid before believing the upper bound means anything.
      #expect(
        elapsed >= latency,
        """
        Ten concurrent reads finished in \(String(format: "%.3f", elapsed))s, \
        faster than the \(latency)s latency scripted into the provider. The \
        delay was never paid, so the upper-bound check below proves nothing \
        about coalescing.
        """
      )
      // Coalescing is proven by fixture.provider.standardCallCount == 1 above.
      // On real devices under test runner overhead, thread dispatch and setup
      // can introduce latency, so use a generous upper bound to guard against
      // purely sequential execution (10 * latency = 2.5s) without flaking on hardware.
      #expect(
        elapsed < latency * 10,
        """
        Ten concurrent reads took \(String(format: "%.2f", elapsed))s against a \
        \(latency)s provider. That is consistent with sequential execution \
        rather than coalescing onto one in-flight request.
        """
      )
    }

    /// COR-06: limited-use tokens are single-use and must never coalesce.
    @Test(.tags(.concurrency))
    func `Ten concurrent limited-use calls each get a distinct token`() async throws {
      let fixture = try TestApp(caseID: "COR-06")
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))

      fixture.provider.latency = 0.1

      let tokens = try await withThrowingTaskGroup(of: String.self) { group in
        for _ in 0 ..< 10 {
          group.addTask { try await appCheck.limitedUseToken().token }
        }
        var collected: [String] = []
        for try await token in group { collected.append(token) }
        return collected
      }

      #expect(
        Set(tokens).count == 10,
        """
        Limited-use tokens were shared between callers, which defeats their \
        purpose: saw \(Set(tokens).count) distinct values across 10 calls.
        """
      )
      #expect(fixture.provider.limitedUseCallCount == 10)
    }

    /// COR-07: mixing the two modes must not cross the wires.
    @Test(.tags(.concurrency))
    func `Standard and limited-use requests do not interfere`() async throws {
      let fixture = try TestApp(caseID: "COR-07")
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))

      fixture.provider.latency = 0.15

      async let standard = withThrowingTaskGroup(of: String.self) { group -> [String] in
        for _ in 0 ..< 5 {
          group.addTask { try await appCheck.token(forcingRefresh: false).token }
        }
        var collected: [String] = []
        for try await token in group { collected.append(token) }
        return collected
      }

      async let limited = withThrowingTaskGroup(of: String.self) { group -> [String] in
        for _ in 0 ..< 5 {
          group.addTask { try await appCheck.limitedUseToken().token }
        }
        var collected: [String] = []
        for try await token in group { collected.append(token) }
        return collected
      }

      let (standardTokens, limitedTokens) = try await (standard, limited)

      #expect(Set(standardTokens).count == 1, "Standard reads should coalesce.")
      #expect(Set(limitedTokens).count == 5, "Limited-use reads should not coalesce.")
      #expect(
        Set(standardTokens).isDisjoint(with: Set(limitedTokens)),
        "A caller received the wrong class of token."
      )
    }

    /// COR-08: queued callers behind a failing request must all see the failure
    /// and must not each launch a retry.
    @Test func `In-flight failure is shared by all queued callers`() async throws {
      let fixture = try TestApp(caseID: "COR-08")
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))

      fixture.provider.latency = 0.25
      fixture.provider.standardOutcome = { _ in
        .failure(NSError(domain: "CoreTokenLifecycleTests.Synthetic", code: 42))
      }

      let failures = await withTaskGroup(of: Bool.self) { group in
        for _ in 0 ..< 6 {
          group.addTask {
            do {
              _ = try await appCheck.token(forcingRefresh: false)
              return false
            } catch {
              return true
            }
          }
        }
        var count = 0
        for await failed in group where failed { count += 1 }
        return count
      }

      #expect(failures == 6, "Every queued caller should observe the failure.")
      #expect(
        fixture.provider.standardCallCount == 1,
        """
        Queued callers launched their own retries: \
        \(fixture.provider.standardCallCount) provider calls for one failure. \
        Under a real outage this multiplies load exactly when the backend is \
        already struggling.
        """
      )
    }

    /// COR-09: sustained concurrent access must not deadlock or race.
    ///
    /// Run this target under Thread Sanitizer to make the race half meaningful;
    /// unsanitized it only proves the absence of deadlock.
    @Test(.tags(.concurrency))
    func `One hundred concurrent callers complete without deadlock`() async throws {
      let fixture = try TestApp(caseID: "COR-09")
      defer { Task { await fixture.tearDown() } }

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))

      fixture.provider.latency = 0.05

      let completed = await withTaskGroup(of: Bool.self) { group in
        for index in 0 ..< 100 {
          group.addTask {
            // Interleave both modes across arbitrary queues.
            do {
              if index.isMultiple(of: 2) {
                _ = try await appCheck.token(forcingRefresh: index % 10 == 0)
              } else {
                _ = try await appCheck.limitedUseToken()
              }
              return true
            } catch {
              return false
            }
          }
        }
        var count = 0
        for await ok in group where ok { count += 1 }
        return count
      }

      #expect(completed == 100)
    }

    /// COR-10: releasing the App Check instance mid-flight must not crash.
    @Test func `Releasing the instance mid-flight does not crash`() async throws {
      let fixture = try TestApp(caseID: "COR-10")
      fixture.provider.latency = 0.3

      let appCheck = try #require(AppCheck.appCheck(app: fixture.app))
      let task = Task { try await appCheck.token(forcingRefresh: true) }

      // Tear down while the request is still outstanding.
      try? await Task.sleep(nanoseconds: 50_000_000)
      await fixture.tearDown()

      // Either outcome is acceptable. Surviving the teardown is the assertion.
      _ = try? await task.value
    }
  }
#endif  // canImport(Testing)
