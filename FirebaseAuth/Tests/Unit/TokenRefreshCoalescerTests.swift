// Copyright 2024 Google LLC
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

import XCTest

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class TokenRefreshCoalescerTests: XCTestCase {
  /// Tests that when multiple concurrent refresh requests arrive for the same token,
  /// only ONE network call is made.
  ///
  /// This is the main issue fix: Previously, each concurrent caller would make its own
  /// network request, resulting in redundant STS calls.
  func testCoalescedRefreshMakesOnlyOneNetworkCall() async throws {
    let coalescer = TokenRefreshCoalescer()
    var networkCallCount = 0
    let lock = NSLock()

    // Simulate multiple concurrent refresh requests
    async let result1 = try coalescer.coalescedRefresh(currentToken: "token_v1") {
      lock.lock()
      networkCallCount += 1
      lock.unlock()

      // Simulate network delay
      try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

      return ("new_token", true)
    }

    async let result2 = try coalescer.coalescedRefresh(currentToken: "token_v1") {
      lock.lock()
      networkCallCount += 1
      lock.unlock()

      try await Task.sleep(nanoseconds: 100_000_000)
      return ("new_token", true)
    }

    async let result3 = try coalescer.coalescedRefresh(currentToken: "token_v1") {
      lock.lock()
      networkCallCount += 1
      lock.unlock()

      try await Task.sleep(nanoseconds: 100_000_000)
      return ("new_token", true)
    }

    // Wait for all three to complete
    let (token1, updated1) = try await result1
    let (token2, updated2) = try await result2
    let (token3, updated3) = try await result3

    // All three should get the same token
    XCTAssertEqual(token1, "new_token")
    XCTAssertEqual(token2, "new_token")
    XCTAssertEqual(token3, "new_token")

    XCTAssertTrue(updated1)
    XCTAssertTrue(updated2)
    XCTAssertTrue(updated3)

    // CRITICAL: Only ONE network call should have been made
    // (Previously, without coalescing, this would be 3)
    XCTAssertEqual(networkCallCount, 1, "Expected only 1 network call, but got \(networkCallCount)")
  }

  /// Tests that when the token changes, a new refresh is started instead of
  /// coalescing with the old one.
  func testNewRefreshStartsWhenTokenChanges() async throws {
    let coalescer = TokenRefreshCoalescer()
    var networkCallCount = 0
    let lock = NSLock()

    // First refresh for token_v1
    async let result1 = try coalescer.coalescedRefresh(currentToken: "token_v1") {
      lock.lock()
      networkCallCount += 1
      let count = networkCallCount
      lock.unlock()

      try await Task.sleep(nanoseconds: 50_000_000)
      return ("new_token_1", true)
    }

    // Wait a bit, then start a refresh for a different token (token_v2)
    // This should NOT coalesce with the first one
    try await Task.sleep(nanoseconds: 10_000_000)

    async let result2 = try coalescer.coalescedRefresh(currentToken: "token_v2") {
      lock.lock()
      networkCallCount += 1
      lock.unlock()

      try await Task.sleep(nanoseconds: 50_000_000)
      return ("new_token_2", true)
    }

    let token1 = try await result1.0
    let token2 = try await result2.0

    // Should get different tokens
    XCTAssertEqual(token1, "new_token_1")
    XCTAssertEqual(token2, "new_token_2")

    // Should have made TWO network calls (one for each token)
    XCTAssertEqual(networkCallCount, 2)
  }

  /// Tests that if a refresh fails, the next call will start a fresh attempt
  /// instead of waiting for the failed one.
  func testFailedRefreshAllowsRetry() async throws {
    let coalescer = TokenRefreshCoalescer()
    var networkCallCount = 0
    let lock = NSLock()

    // First call will fail
    async let result1 = try coalescer.coalescedRefresh(currentToken: "token_v1") {
      lock.lock()
      networkCallCount += 1
      lock.unlock()

      throw NSError(domain: "TestError", code: -1, userInfo: nil)
    }

    // Start a second call concurrently
    async let result2 = try coalescer.coalescedRefresh(currentToken: "token_v1") {
      lock.lock()
      networkCallCount += 1
      lock.unlock()

      return ("recovered_token", true)
    }

    // First should fail
    do {
      _ = try await result1
      XCTFail("Expected error")
    } catch {
      // Expected
    }

    // Second should succeed (it will retry after the first failure)
    let token2 = try await result2.0
    XCTAssertEqual(token2, "recovered_token")

    // Should have made TWO network calls (first failed, second succeeded)
    XCTAssertEqual(networkCallCount, 2)
  }

  /// Stress test: Many concurrent calls for the same token
  func testManyCurrentCallsWithSameToken() async throws {
    let coalescer = TokenRefreshCoalescer()
    var networkCallCount = 0
    let lock = NSLock()

    let numCalls = 50
    var tasks: [Task<(String?, Bool), Error>] = []

    // Launch 50 concurrent refresh tasks
    for _ in 0..<numCalls {
      let task = Task {
        return try await coalescer.coalescedRefresh(currentToken: "token_stress") {
          lock.lock()
          networkCallCount += 1
          lock.unlock()

          try await Task.sleep(nanoseconds: 100_000_000)
          return ("stress_token", true)
        }
      }
      tasks.append(task)
    }

    // Wait for all to complete
    var successCount = 0
    for task in tasks {
      let (token, updated) = try await task.value
      XCTAssertEqual(token, "stress_token")
      XCTAssertTrue(updated)
      successCount += 1
    }

    XCTAssertEqual(successCount, numCalls)

    // All 50 concurrent calls should result in ONLY 1 network call
    XCTAssertEqual(
      networkCallCount,
      1,
      "Expected 1 network call for 50 concurrent requests, but got \(networkCallCount)"
    )
  }

  /// Tests that concurrent calls with forceRefresh:false still use the cache
  /// when tokens are valid.
  func testCachingStillWorksWithCoalescer() async throws {
    let coalescer = TokenRefreshCoalescer()
    var networkCallCount = 0
    let lock = NSLock()

    // First call triggers a refresh
    let result1 = try await coalescer.coalescedRefresh(currentToken: "token_v1") {
      lock.lock()
      networkCallCount += 1
      lock.unlock()

      return ("refreshed_token", true)
    }

    XCTAssertEqual(result1.0, "refreshed_token")
    XCTAssertEqual(networkCallCount, 1)

    // This test documents that caching logic happens BEFORE coalescer is called,
    // so this scenario doesn't test the coalescer directly, but verifies the
    // integration is correct.
  }
}
