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

@testable import FirebaseCoreInternal
import XCTest

class RetryBackoffTests: XCTestCase {
  private let clock = FakeUptime()

  // MARK: - Delays

  func testDelaysDoubleFromTheInitialInterval() {
    var backoff = makeBackoff(maxRetryTime: 1000, initialInterval: 1.5)

    XCTAssertEqual(waitForRetries(&backoff, count: 4), [1.5, 3, 6, 12])
    XCTAssertEqual(backoff.retryCount, 4)
  }

  func testDelaysStopGrowingAtTheMaxInterval() {
    var backoff = makeBackoff(maxRetryTime: 1000, maxInterval: 5, initialInterval: 1.5)

    XCTAssertEqual(waitForRetries(&backoff, count: 4), [1.5, 3, 5, 5])
  }

  func testNoRetryStartsAfterTheMaxRetryTime() {
    var backoff = makeBackoff(maxRetryTime: 10, initialInterval: 1)

    // The retries start 1, 3, and 7 seconds in. The next one would start 15 seconds in.
    XCTAssertEqual(waitForRetries(&backoff, count: 3), [1, 2, 4])
    XCTAssertNil(backoff.nextDelay())
    XCTAssertEqual(backoff.retryCount, 3)
  }

  func testTimeSpentOnAttemptsCountsTowardTheMaxRetryTime() {
    var backoff = makeBackoff(maxRetryTime: 120, initialInterval: 1.5)

    // The first attempt took almost the whole time, for example until it timed out.
    clock.advance(by: 119)

    XCTAssertNil(backoff.nextDelay())
    XCTAssertEqual(backoff.retryCount, 0)
  }

  func testRetryThatStartsAtTheMaxRetryTimeIsAllowed() {
    var backoff = makeBackoff(maxRetryTime: 10, initialInterval: 2)
    clock.advance(by: 8)

    XCTAssertEqual(backoff.nextDelay(), 2)
  }

  func testZeroMaxRetryTimeAllowsNoRetries() {
    var backoff = makeBackoff(maxRetryTime: 0, initialInterval: 1)

    XCTAssertNil(backoff.nextDelay())
  }

  func testSuggestedDelayReplacesTheComputedDelay() {
    var backoff = makeBackoff(maxRetryTime: 1000, initialInterval: 1.5)

    XCTAssertEqual(backoff.nextDelay(suggestedDelay: 10), 10)
    // Later delays double from the suggested delay.
    XCTAssertEqual(backoff.nextDelay(), 20)
  }

  func testSuggestedDelayIsLimitedToTheMaxInterval() {
    var backoff = makeBackoff(maxRetryTime: 1000, maxInterval: 5, initialInterval: 1.5)

    XCTAssertEqual(backoff.nextDelay(suggestedDelay: 30), 5)
  }

  func testSuggestedDelayMustFitInTheMaxRetryTime() {
    var backoff = makeBackoff(maxRetryTime: 10, initialInterval: 1.5)

    XCTAssertNil(backoff.nextDelay(suggestedDelay: 11))
    XCTAssertEqual(backoff.retryCount, 0)
  }

  func testElapsedTime() {
    let backoff = makeBackoff(maxRetryTime: 10, initialInterval: 1)

    clock.advance(by: 2.5)

    XCTAssertEqual(backoff.elapsedTime, 2.5)
  }

  func testRandomInitialIntervalIsFromOneToTwoSeconds() {
    for _ in 0 ..< 100 {
      let interval = RetryBackoff.randomInitialInterval()
      XCTAssertGreaterThanOrEqual(interval, 1)
      XCTAssertLessThan(interval, 2)
    }
  }

  func testPublicInitializerMeasuresElapsedTimeFromNow() {
    let backoff = RetryBackoff(maxRetryTime: 10)

    XCTAssertGreaterThanOrEqual(backoff.initialInterval, 1)
    XCTAssertLessThan(backoff.initialInterval, 2)
    XCTAssertEqual(backoff.maxInterval, .infinity)
    XCTAssertGreaterThanOrEqual(backoff.elapsedTime, 0)
    XCTAssertLessThan(backoff.elapsedTime, 1)
  }

  // MARK: - Retry-After

  func testRetryAfterInSeconds() {
    XCTAssertEqual(RetryBackoff.retryAfterDelay(of: response(retryAfter: "120")), 120)
    XCTAssertEqual(RetryBackoff.retryAfterDelay(of: response(retryAfter: " 0 ")), 0)
  }

  func testRetryAfterAsAnHTTPDate() {
    // Wed, 21 Oct 2015 07:27:30 GMT
    let now = Date(timeIntervalSince1970: 1_445_412_450)

    let delay = RetryBackoff.retryAfterDelay(
      of: response(retryAfter: "Wed, 21 Oct 2015 07:28:00 GMT"), now: now
    )

    XCTAssertEqual(delay, 30)
  }

  func testRetryAfterInThePastMeansNoDelay() {
    let now = Date(timeIntervalSince1970: 1_445_412_480 + 60)

    XCTAssertEqual(RetryBackoff.retryAfterDelay(
      of: response(retryAfter: "Wed, 21 Oct 2015 07:28:00 GMT"), now: now
    ), 0)
    XCTAssertEqual(RetryBackoff.retryAfterDelay(of: response(retryAfter: "-5")), 0)
  }

  func testMissingOrUnreadableRetryAfter() {
    XCTAssertNil(RetryBackoff.retryAfterDelay(of: response(retryAfter: nil)))
    XCTAssertNil(RetryBackoff.retryAfterDelay(of: response(retryAfter: "soon")))
  }

  // MARK: - Helpers

  private func makeBackoff(maxRetryTime: TimeInterval,
                           maxInterval: TimeInterval = .infinity,
                           initialInterval: TimeInterval) -> RetryBackoff {
    let clock = self.clock
    return RetryBackoff(maxRetryTime: maxRetryTime, maxInterval: maxInterval,
                        initialInterval: initialInterval, uptime: { clock.now })
  }

  /// Asks `backoff` for `count` delays, waiting for each one, and returns them.
  private func waitForRetries(_ backoff: inout RetryBackoff, count: Int,
                              file: StaticString = #filePath,
                              line: UInt = #line) -> [TimeInterval] {
    var delays: [TimeInterval] = []
    for _ in 0 ..< count {
      guard let delay = backoff.nextDelay() else {
        XCTFail("Expected another retry", file: file, line: line)
        break
      }
      delays.append(delay)
      clock.advance(by: delay)
    }
    return delays
  }

  private func response(retryAfter: String?) -> HTTPURLResponse {
    HTTPURLResponse(
      url: URL(string: "https://example.com")!,
      statusCode: 503,
      httpVersion: "HTTP/1.1",
      headerFields: retryAfter.map { ["Retry-After": $0] }
    )!
  }
}

/// A clock that only moves when the test advances it.
private final class FakeUptime: Sendable {
  private let time = UnfairLock<TimeInterval>(1000)

  var now: TimeInterval {
    time.value()
  }

  func advance(by interval: TimeInterval) {
    time.withLock { $0 += interval }
  }
}
