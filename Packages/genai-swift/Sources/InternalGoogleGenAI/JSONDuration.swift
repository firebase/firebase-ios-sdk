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

public import Foundation

/// Represents a signed, fixed-length span of time represented
/// as a count of seconds and fractions of seconds at nanosecond
/// resolution.
///
/// This represents a
/// [`google.protobuf.duration`](https://protobuf.dev/reference/protobuf/google.protobuf/#duration).
public struct ProtobufDuration: Sendable, Equatable, Hashable {
  /// Signed seconds of the span of time.
  ///
  /// Must be from -315,576,000,000 to +315,576,000,000 inclusive.
  ///
  /// Note: these bounds are computed from:
  /// 60 sec/min * 60 min/hr * 24 hr/day * 365.25 days/year * 10000 years
  public let seconds: Int64

  /// Signed fractions of a second at nanosecond resolution of the span of time.
  ///
  /// Durations less than one second are represented with a 0
  /// `seconds` field and a positive or negative `nanos` field.
  ///
  /// For durations of one second or more, a non-zero value for the `nanos` field must be
  /// of the same sign as the `seconds` field. Must be from -999,999,999
  /// to +999,999,999 inclusive.
  public let nanos: Int32

  /// Returns a `TimeInterval` representation of the `ProtoDuration`.
  public var timeInterval: TimeInterval {
    return TimeInterval(seconds) + TimeInterval(nanos) / 1_000_000_000
  }
}

// MARK: - Codable Conformance

extension ProtobufDuration: Decodable {
  public init(from decoder: any Decoder) throws {
    var text = try decoder.singleValueContainer().decode(String.self)
    guard text.last == "s" else {
      throw DecodingError.dataCorrupted(.init(
        codingPath: [],
        debugDescription: "Missing 's' at end of proto duration: \(text)."
      ))
    }
    text.removeLast()

    let seconds: String
    let nanoseconds: String

    let maybeSplit = text.split(separator: ".")
    if maybeSplit.count > 2 {
      throw DecodingError.dataCorrupted(.init(
        codingPath: [],
        debugDescription: """
        Invalid protobuf duration; too many decimal places (expected only 1): \(maybeSplit).
        """
      ))
    }

    if maybeSplit.count == 2 {
      seconds = String(maybeSplit[0])
      nanoseconds = String(maybeSplit[1])
    } else {
      seconds = text
      nanoseconds = "0"
    }

    guard let secs = Int64(seconds) else {
      throw DecodingError.dataCorrupted(.init(
        codingPath: [],
        debugDescription: "Invalid proto duration seconds: \(text)"
      ))
    }

    guard let fractionalSeconds = Double("0.\(nanoseconds)") else {
      throw DecodingError.dataCorrupted(.init(
        codingPath: [],
        debugDescription: "Invalid proto duration nanoseconds: \(text)"
      ))
    }

    self.seconds = secs
    nanos = Int32(fractionalSeconds * 1_000_000_000)
  }
}

extension ProtobufDuration: Encodable {}
