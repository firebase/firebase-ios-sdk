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

/// Computes how long to wait between the attempts of an operation that keeps failing, within a
/// limit on the operation's total time.
///
/// The first retry waits `initialInterval`, which is a random time from 1 to 2 seconds by
/// default. Each later retry waits twice as long as the one before, up to `maxInterval`. No retry
/// starts later than `maxRetryTime` after the backoff was created, so create the backoff when the
/// operation starts.
public struct RetryBackoff: Sendable {
  /// The time, in seconds, after the backoff was created when the last retry may start.
  public let maxRetryTime: TimeInterval

  /// The longest wait, in seconds, before a retry.
  public let maxInterval: TimeInterval

  /// The wait, in seconds, before the first retry.
  public let initialInterval: TimeInterval

  /// The number of retries that `nextDelay(suggestedDelay:)` has allowed.
  public private(set) var retryCount = 0

  private let uptime: @Sendable () -> TimeInterval
  private let startTime: TimeInterval
  private var lastInterval: TimeInterval = 0

  /// Creates a backoff whose clock starts now.
  ///
  /// - Parameters:
  ///   - maxRetryTime: The time, in seconds, from now when the last retry may start.
  ///   - maxInterval: The longest wait, in seconds, before a retry.
  ///   - initialInterval: The wait, in seconds, before the first retry.
  public init(maxRetryTime: TimeInterval,
              maxInterval: TimeInterval = .infinity,
              initialInterval: TimeInterval = RetryBackoff.randomInitialInterval()) {
    self.init(
      maxRetryTime: maxRetryTime,
      maxInterval: maxInterval,
      initialInterval: initialInterval,
      uptime: { ProcessInfo.processInfo.systemUptime }
    )
  }

  /// Creates a backoff that reads the time from `uptime`. For tests.
  init(maxRetryTime: TimeInterval,
       maxInterval: TimeInterval,
       initialInterval: TimeInterval,
       uptime: @escaping @Sendable () -> TimeInterval) {
    self.maxRetryTime = maxRetryTime
    self.maxInterval = maxInterval
    self.initialInterval = initialInterval
    self.uptime = uptime
    startTime = uptime()
  }

  /// The time, in seconds, since the backoff was created.
  public var elapsedTime: TimeInterval {
    uptime() - startTime
  }

  /// Returns a random time of at least 1 and less than 2 seconds.
  public static func randomInitialInterval() -> TimeInterval {
    1 + Double.random(in: 0 ..< 1)
  }

  /// Returns how long to wait before the next retry, or `nil` if the retry wouldn't start within
  /// `maxRetryTime` of the backoff's creation.
  ///
  /// - Parameter suggestedDelay: A wait that the server asked for, for example in a `Retry-After`
  ///   header. It replaces the computed wait, and is still limited to `maxInterval`. Later waits
  ///   double from it.
  public mutating func nextDelay(suggestedDelay: TimeInterval? = nil) -> TimeInterval? {
    let exponentialDelay = max(lastInterval * 2, initialInterval)
    let delay = min(max(suggestedDelay ?? exponentialDelay, 0), maxInterval)
    guard elapsedTime + delay <= maxRetryTime else {
      return nil
    }
    lastInterval = delay
    retryCount += 1
    return delay
  }

  /// Returns the wait that the `Retry-After` header of `response` asks for, or `nil` if the
  /// response has no such header or its value isn't a number of seconds or an HTTP date.
  ///
  /// - Parameters:
  ///   - response: The response to read.
  ///   - now: The time to measure an HTTP date from.
  public static func retryAfterDelay(of response: HTTPURLResponse,
                                     now: Date = Date()) -> TimeInterval? {
    guard let value = response.value(forHTTPHeaderField: "Retry-After")?
      .trimmingCharacters(in: .whitespaces) else {
      return nil
    }
    if let seconds = Int(value) {
      return TimeInterval(max(seconds, 0))
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "GMT")
    formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
    guard let date = formatter.date(from: value) else {
      return nil
    }
    return max(date.timeIntervalSince(now), 0)
  }
}
