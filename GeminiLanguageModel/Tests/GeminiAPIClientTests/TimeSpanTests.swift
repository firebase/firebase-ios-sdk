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
import GeminiAPIDataModels
import Testing

@Suite("TimeSpan Tests")
struct TimeSpanTests {
  private func decode(_ durationString: String) throws -> TimeSpan {
    try JSONDecoder().decode(TimeSpan.self, from: Data("\"\(durationString)\"".utf8))
  }

  private func encode(_ timeSpan: TimeSpan) throws -> String {
    try #require(String(data: JSONEncoder().encode(timeSpan), encoding: .utf8))
  }

  // MARK: - Parsing

  @Test
  func parseStandardDuration() throws {
    let timeSpan = try #require(TimeSpan("120.000000123s"))

    #expect(timeSpan.seconds == 120)
    #expect(timeSpan.nanos == 123)
    #expect(abs(timeSpan.timeInterval - 120.000000123) < 1e-9)
  }

  @Test
  func parseWithoutNanoseconds() throws {
    let timeSpan = try #require(TimeSpan("120s"))

    #expect(timeSpan.seconds == 120)
    #expect(timeSpan.nanos == 0)
    #expect(timeSpan.timeInterval == 120)
  }

  @Test
  func parseMaxNanosecondDigits() throws {
    let timeSpan = try #require(TimeSpan("15.123456789s"))

    #expect(timeSpan.seconds == 15)
    #expect(timeSpan.nanos == 123_456_789)
  }

  @Test
  func parseMilliseconds() throws {
    let timeSpan = try #require(TimeSpan("15.123s"))

    #expect(timeSpan.seconds == 15)
    #expect(timeSpan.nanos == 123_000_000)
  }

  @Test
  func parseWithoutSuffix() throws {
    let timeSpan = try #require(TimeSpan("123.456"))

    #expect(timeSpan.seconds == 123)
    #expect(timeSpan.nanos == 456_000_000)
  }

  @Test
  func parseNegativeDuration() throws {
    let timeSpan = try #require(TimeSpan("-1.5s"))

    #expect(timeSpan.seconds == -1)
    #expect(timeSpan.nanos == -500_000_000)
    #expect(timeSpan.timeInterval == -1.5)
  }

  @Test
  func parseNegativeSubSecondDuration() throws {
    let timeSpan = try #require(TimeSpan("-0.25s"))

    #expect(timeSpan.seconds == 0)
    #expect(timeSpan.nanos == -250_000_000)
    #expect(timeSpan.timeInterval == -0.25)
  }

  @Test
  func parseTruncatesBeyondNanosecondPrecision() throws {
    let timeSpan = try #require(TimeSpan("1.1234567899s"))

    #expect(timeSpan.nanos == 123_456_789)
  }

  @Test
  func parseEmptyFraction() throws {
    let timeSpan = try #require(TimeSpan("1.s"))

    #expect(timeSpan == TimeSpan(seconds: 1))
  }

  @Test(arguments: [
    "invalid.123s", "123.invalid", "123.45.67", "", "s", "-s", ".5s", "1.5e10s", "1.1E300s",
    "0.9e+10s", "1.\u{0663}s", "1.\u{00BD}s", "1.\u{00B2}s", "1.1\u{0301}s", "+1s", "1,5s",
  ])
  func parseRejectsInvalidStrings(durationString: String) {
    #expect(TimeSpan(durationString) == nil)
  }

  // MARK: - Normalization

  @Test(arguments: [
    (TimeSpan(seconds: 0, nanos: 1_000_000_000), TimeSpan(seconds: 1)),
    (TimeSpan(seconds: 1, nanos: 1_500_000_000), TimeSpan(seconds: 2, nanos: 500_000_000)),
    (TimeSpan(seconds: 0, nanos: -1_500_000_000), TimeSpan(seconds: -1, nanos: -500_000_000)),
    (TimeSpan(seconds: 1, nanos: -500_000_000), TimeSpan(seconds: 0, nanos: 500_000_000)),
    (TimeSpan(seconds: -1, nanos: 500_000_000), TimeSpan(seconds: 0, nanos: -500_000_000)),
    (TimeSpan(seconds: 2, nanos: -1), TimeSpan(seconds: 1, nanos: 999_999_999)),
  ])
  func componentsAreNormalized(timeSpan: TimeSpan, expected: TimeSpan) {
    #expect(timeSpan.seconds == expected.seconds)
    #expect(timeSpan.nanos == expected.nanos)
  }

  @Test
  func normalizedStringValueDoesNotTrap() {
    #expect(TimeSpan(seconds: 0, nanos: 1_000_000_000).stringValue == "1s")
    #expect(TimeSpan(seconds: 1, nanos: -5).stringValue == "0.999999995s")
  }

  // MARK: - String Representation

  @Test(arguments: [
    (TimeSpan(seconds: 120), "120s"),
    (TimeSpan(seconds: 1, nanos: 500_000_000), "1.500s"),
    (TimeSpan(seconds: 15, nanos: 123_000_000), "15.123s"),
    (TimeSpan(seconds: 15, nanos: 123_456_000), "15.123456s"),
    (TimeSpan(seconds: 15, nanos: 123_456_789), "15.123456789s"),
    (TimeSpan(seconds: 120, nanos: 123), "120.000000123s"),
    (TimeSpan(seconds: -1, nanos: -500_000_000), "-1.500s"),
    (TimeSpan(seconds: 0, nanos: -250_000_000), "-0.250s"),
    (TimeSpan(seconds: 0), "0s"),
  ])
  func stringValue(timeSpan: TimeSpan, expected: String) {
    #expect(timeSpan.stringValue == expected)
  }

  @Test
  func stringValueRoundTrips() throws {
    let original = TimeSpan(seconds: 3, nanos: 7)

    let parsed = try #require(TimeSpan(original.stringValue))

    #expect(parsed == original)
  }

  // MARK: - Duration

  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  @Test
  func durationConversion() {
    let timeSpan = TimeSpan(seconds: 2, nanos: 500_000_000)

    #expect(timeSpan.duration == .milliseconds(2500))
  }

  // MARK: - Codable

  @Test
  func decodeFromJSONString() throws {
    let timeSpan = try decode("45.5s")

    #expect(timeSpan == TimeSpan(seconds: 45, nanos: 500_000_000))
  }

  @Test
  func decodeInvalidStringThrowsDataCorrupted() {
    #expect(throws: DecodingError.self) {
      try decode("123.45.67")
    }
  }

  @Test
  func encodeToJSONString() throws {
    let json = try encode(TimeSpan(seconds: 45, nanos: 500_000_000))

    #expect(json == "\"45.500s\"")
  }
}
