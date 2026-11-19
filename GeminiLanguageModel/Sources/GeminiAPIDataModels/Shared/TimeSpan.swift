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

/// A signed, fixed-length span of time with nanosecond resolution.
///
/// This is the Swift representation of a
/// [`google.protobuf.Duration`](https://protobuf.dev/reference/protobuf/google.protobuf/#duration),
/// which is serialized in JSON as a decimal number of seconds with an `s` suffix (e.g., `"1.5s"`,
/// `"-0.000000001s"`). Properties with `format: google-duration` in the API specification are
/// generated with this type.
package struct TimeSpan: Sendable, Equatable, Hashable {
  /// The number of nanoseconds in one second.
  private static let nanosPerSecond: Int64 = 1_000_000_000

  /// Signed seconds of the span of time.
  ///
  /// Must be from -315,576,000,000 to +315,576,000,000 inclusive (10,000 years).
  package let seconds: Int64

  /// Signed fractions of a second at nanosecond resolution of the span of time.
  ///
  /// Spans of less than one second are represented with `0` `seconds` and a positive or negative
  /// `nanos`. For spans of one second or more, a non-zero `nanos` has the same sign as `seconds`.
  /// Must be from -999,999,999 to +999,999,999 inclusive.
  package let nanos: Int32

  /// The span of time as a `TimeInterval` (seconds).
  package var timeInterval: TimeInterval {
    TimeInterval(seconds) + TimeInterval(nanos) / TimeInterval(Self.nanosPerSecond)
  }

  /// The span of time as a `Duration`.
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  package var duration: Duration {
    .seconds(seconds) + .nanoseconds(nanos)
  }

  /// The canonical JSON string representation (e.g., `"1.500s"`).
  ///
  /// Fractional seconds are rendered with 3, 6, or 9 digits as needed, matching the protobuf JSON
  /// mapping.
  package var stringValue: String {
    let isNegative = seconds < 0 || nanos < 0
    let sign = isNegative ? "-" : ""
    let wholeSeconds = seconds.magnitude
    let fraction = nanos.magnitude
    guard fraction != 0 else {
      return "\(sign)\(wholeSeconds)s"
    }
    var digits = String(fraction)
    digits = String(repeating: "0", count: 9 - digits.count) + digits
    while digits.hasSuffix("000") {
      digits.removeLast(3)
    }
    return "\(sign)\(wholeSeconds).\(digits)s"
  }

  /// Creates a span of time from its components, normalizing them.
  ///
  /// The components are normalized so that `nanos` is within ±999,999,999 and has the same sign as
  /// `seconds` (whole seconds are carried out of `nanos`, and mixed signs are resolved). For
  /// example, `TimeSpan(seconds: 1, nanos: 1_500_000_000)` is `2.5s` and
  /// `TimeSpan(seconds: 1, nanos: -500_000_000)` is `0.5s`.
  ///
  /// - Parameters:
  ///   - seconds: Signed seconds of the span of time.
  ///   - nanos: Signed fractions of a second at nanosecond resolution; defaults to `0`.
  package init(seconds: Int64, nanos: Int32 = 0) {
    let totalNanos = Int64(nanos)
    var normalizedSeconds = seconds + totalNanos / Self.nanosPerSecond
    var normalizedNanos = totalNanos % Self.nanosPerSecond
    if normalizedSeconds > 0, normalizedNanos < 0 {
      normalizedSeconds -= 1
      normalizedNanos += Self.nanosPerSecond
    } else if normalizedSeconds < 0, normalizedNanos > 0 {
      normalizedSeconds += 1
      normalizedNanos -= Self.nanosPerSecond
    }
    self.seconds = normalizedSeconds
    self.nanos = Int32(normalizedNanos)
  }

  /// Creates a span of time by parsing a protobuf JSON duration string.
  ///
  /// Accepts an optional leading `-`, a whole number of ASCII decimal digits for the seconds, an
  /// optional fraction of ASCII decimal digits (digits beyond the ninth are truncated), and a
  /// trailing `s` (which is tolerated if missing). Returns `nil` for any other input, including
  /// exponent notation, non-ASCII digits, or a leading `+`.
  ///
  /// - Parameter string: The duration string (e.g., `"120.000000123s"`).
  package init?(_ string: String) {
    var text = Substring(string)
    if text.last == "s" {
      text.removeLast()
    }

    let isNegative = text.first == "-"
    if isNegative {
      text.removeFirst()
    }

    let components = text.split(separator: ".", omittingEmptySubsequences: false)
    guard components.count <= 2, let wholeText = components.first, !wholeText.isEmpty else {
      return nil
    }
    let fractionText = components.count == 2 ? components[1] : ""

    // Only allow ASCII digits (0-9) so that values such as "1.5e10s", which floating-point parsers
    // would otherwise accept, are rejected. `isASCII` also rejects non-ASCII numerics (e.g.,
    // Arabic-Indic digits or vulgar fractions) and digits followed by combining marks.
    guard wholeText.allSatisfy(Self.isASCIIDigit), fractionText.allSatisfy(Self.isASCIIDigit) else {
      return nil
    }
    guard let wholeSeconds = Int64(wholeText) else {
      return nil
    }

    let paddedFraction =
      String(fractionText.prefix(9))
      + String(repeating: "0", count: max(0, 9 - fractionText.count))
    guard let fractionNanos = Int32(paddedFraction) else {
      return nil
    }

    self.init(
      seconds: isNegative ? -wholeSeconds : wholeSeconds,
      nanos: isNegative ? -fractionNanos : fractionNanos
    )
  }

  private static func isASCIIDigit(_ character: Character) -> Bool {
    character.isASCII && character.isNumber
  }
}

// MARK: - Codable Conformance

extension TimeSpan: Codable {
  package init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let text = try container.decode(String.self)
    guard let timeSpan = TimeSpan(text) else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid duration string: \(text)"
      )
    }
    self = timeSpan
  }

  package func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(stringValue)
  }
}
