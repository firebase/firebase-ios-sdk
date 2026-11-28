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

import FirebaseCore
import FirebaseCoreTestHooks
import Foundation
import XCTest

/// Tests for `Timestamp`. They run unchanged against the Objective-C and Swift implementations of
/// FirebaseCore.
///
/// Ported from FirebaseCore/Tests/Unit/FIRTimestampTest.m, plus edge cases: negative seconds,
/// range validation, copying, equality and hashing, and date round trips.
final class TimestampTests: XCTestCase {
  /// Seconds from the Unix epoch to the reference date, 2001-01-01.
  private let secondsFromEpochToReferenceDate: Int64 = 978_307_200
  /// Midnight at the start of 0001-01-01, the earliest supported timestamp.
  private let minSeconds: Int64 = -62_135_596_800
  /// Midnight at the start of 10000-01-01, the first unsupported timestamp.
  private let maxSecondsExclusive: Int64 = 253_402_300_800

  // MARK: - Creating timestamps

  func testFromDate() {
    // Use a date whose fractional seconds have an exact representation, so no precision is lost.
    let date = Date(timeIntervalSinceReferenceDate: 1.5)

    let timestamp = Timestamp(date: date)

    XCTAssertEqual(timestamp.seconds, secondsFromEpochToReferenceDate + 1)
    XCTAssertEqual(timestamp.nanoseconds, 500_000_000)
    XCTAssertEqual(timestamp, Timestamp(seconds: secondsFromEpochToReferenceDate + 1,
                                        nanoseconds: 500_000_000))
  }

  func testFromDateBeforeEpoch() {
    // Nanoseconds are never negative: -1.5 seconds is -2 seconds plus 0.5 seconds.
    let timestamp = Timestamp(date: Date(timeIntervalSince1970: -1.5))
    XCTAssertEqual(timestamp.seconds, -2)
    XCTAssertEqual(timestamp.nanoseconds, 500_000_000)
  }

  func testNow() {
    let before = Date()
    let timestamp = Timestamp()
    let after = Date()
    XCTAssertGreaterThanOrEqual(timestamp.dateValue().timeIntervalSince1970,
                                before.timeIntervalSince1970 - 0.001)
    XCTAssertLessThanOrEqual(timestamp.dateValue().timeIntervalSince1970,
                             after.timeIntervalSince1970 + 0.001)
  }

  func testNegativeSecondsWithNanoseconds() {
    let timestamp = Timestamp(seconds: -1, nanoseconds: 999_999_999)
    XCTAssertEqual(timestamp.seconds, -1)
    XCTAssertEqual(timestamp.nanoseconds, 999_999_999)
    XCTAssertEqual(timestamp.dateValue().timeIntervalSince1970, -0.000000001, accuracy: 1e-9)
  }

  func testOutOfRangeValuesRaise() {
    let invalid: [(Int64, Int32)] = [
      (0, -1),
      (0, 1_000_000_000),
      (minSeconds - 1, 0),
      (maxSecondsExclusive, 0),
    ]
    for (seconds, nanoseconds) in invalid {
      let exception = CoreTestHooks.exceptionRaised {
        _ = Timestamp(seconds: seconds, nanoseconds: nanoseconds)
      }
      XCTAssertEqual(exception?.name.rawValue, "Invalid timestamp", "\(seconds) \(nanoseconds)")
    }

    // The limits themselves are valid.
    for (seconds, nanoseconds) in [(minSeconds, Int32(0)), (maxSecondsExclusive - 1, 999_999_999)] {
      let exception = CoreTestHooks.exceptionRaised {
        _ = Timestamp(seconds: seconds, nanoseconds: nanoseconds)
      }
      XCTAssertNil(exception, "\(seconds) \(nanoseconds)")
    }
  }

  // MARK: - Dates

  func testDateRoundTrip() {
    // Intervals whose fractions have exact binary representations.
    for interval in [0, 1.5, -1.25, 1_000_000.75, -62_135_596_800, 253_402_300_799.5] {
      let date = Date(timeIntervalSince1970: interval)
      XCTAssertEqual(Timestamp(date: date).dateValue(), date, "\(interval)")
    }

    let timestamp = Timestamp(seconds: 1_234_567_890, nanoseconds: 123_456_789)
    XCTAssertEqual(Timestamp(date: timestamp.dateValue()).seconds, timestamp.seconds)
    XCTAssertEqual(timestamp.dateValue().timeIntervalSince1970, 1_234_567_890.123_456_789,
                   accuracy: 1e-6)
  }

  // MARK: - ISO 8601

  func testISO8601String() throws {
    let date = try makeUTCDate(year: 1912, month: 4, day: 14, hour: 23, minute: 40)
    let timestamp = Timestamp(seconds: Int64(date.timeIntervalSince1970), nanoseconds: 543_000_000)
    XCTAssertEqual(timestamp.iso8601String, "1912-04-14T23:40:00.543000000Z")
  }

  func testISO8601StringWithLowMilliseconds() throws {
    let date = try makeUTCDate(year: 1912, month: 4, day: 14, hour: 23, minute: 40)
    let timestamp = Timestamp(seconds: Int64(date.timeIntervalSince1970), nanoseconds: 7_000_000)
    XCTAssertEqual(timestamp.iso8601String, "1912-04-14T23:40:00.007000000Z")
  }

  func testISO8601StringWithLowNanoseconds() {
    let timestamp = Timestamp(seconds: 0, nanoseconds: 1)
    XCTAssertEqual(timestamp.iso8601String, "1970-01-01T00:00:00.000000001Z")
  }

  func testISO8601StringWithNegativeSeconds() {
    let timestamp = Timestamp(seconds: -1, nanoseconds: 999_999_999)
    XCTAssertEqual(timestamp.iso8601String, "1969-12-31T23:59:59.999999999Z")
  }

  // MARK: - Comparing, equality and copying

  func testCompare() {
    let timestamps = [
      Timestamp(seconds: 12344, nanoseconds: 999_999_999),
      Timestamp(seconds: 12345, nanoseconds: 0),
      Timestamp(seconds: 12345, nanoseconds: 1),
      Timestamp(seconds: 12345, nanoseconds: 99_999_999),
      Timestamp(seconds: 12345, nanoseconds: 100_000_000),
      Timestamp(seconds: 12345, nanoseconds: 100_000_001),
      Timestamp(seconds: 12346, nanoseconds: 0),
    ]
    for (earlier, later) in zip(timestamps, timestamps.dropFirst()) {
      XCTAssertEqual(earlier.compare(later), .orderedAscending)
      XCTAssertEqual(later.compare(earlier), .orderedDescending)
      XCTAssertEqual(earlier.compare(earlier), .orderedSame)
    }
  }

  func testEqualityAndHashAreConsistentWithCompare() {
    let timestamp = Timestamp(seconds: -12345, nanoseconds: 678)
    let same = Timestamp(seconds: -12345, nanoseconds: 678)
    XCTAssertFalse(timestamp === same)
    XCTAssertTrue(timestamp.isEqual(same))
    XCTAssertEqual(timestamp.compare(same), .orderedSame)
    XCTAssertEqual(timestamp.hash, same.hash)

    for other in [Timestamp(seconds: -12345, nanoseconds: 679),
                  Timestamp(seconds: -12344, nanoseconds: 678)] {
      XCTAssertFalse(timestamp.isEqual(other))
      XCTAssertNotEqual(timestamp.compare(other), .orderedSame)
    }
    XCTAssertFalse(timestamp.isEqual(NSNumber(value: 1)))
    XCTAssertFalse(timestamp.isEqual(nil))

    // Equal timestamps work as dictionary keys and set elements.
    let set: Set<Timestamp> = [timestamp, same]
    XCTAssertEqual(set.count, 1)
  }

  func testCopy() throws {
    let timestamp = Timestamp(seconds: 1, nanoseconds: 2)
    let copy = try XCTUnwrap(timestamp.copy() as? Timestamp)
    XCTAssertEqual(copy, timestamp)
    // Timestamps are immutable, so copying returns the same instance.
    XCTAssertTrue(copy === timestamp)
  }

  func testDescription() {
    XCTAssertEqual(Timestamp(seconds: -1, nanoseconds: 2).description,
                   "<FIRTimestamp: seconds=-1 nanoseconds=2>")
  }

  // MARK: - Helpers

  private func makeUTCDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) throws -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
    let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    return try XCTUnwrap(calendar.date(from: components))
  }
}
