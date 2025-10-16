// Copyright 2025 Google LLC
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

@testable import FirebaseAILogic

final class ProtoDurationTests: XCTestCase {
  let decoder = JSONDecoder()

  private func decodeProtoDuration(_ jsonString: String) throws -> ProtoDuration {
    let escapedString = "\"\(jsonString)\""
    let jsonData = try XCTUnwrap(escapedString.data(using: .utf8))

    return try decoder.decode(ProtoDuration.self, from: jsonData)
  }

  private func expectDecodeFailure(_ jsonString: String) throws -> DecodingError.Context? {
    do {
      let _ = try decodeProtoDuration(jsonString)
      XCTFail("Expected decoding to fail")
      return nil
    } catch {
      let decodingError = try XCTUnwrap(error as? DecodingError)
      guard case let .dataCorrupted(dataCorrupted) = decodingError else {
        XCTFail("Error was not a data corrupted error")
        return nil
      }

      return dataCorrupted
    }
  }

  func testDecodeProtoDuration_standardDuration() throws {
    let duration = try decodeProtoDuration("120.000000123s")
    XCTAssertEqual(duration.seconds, 120)
    XCTAssertEqual(duration.nanos, 123)

    XCTAssertEqual(duration.timeInterval, 120.000000123, accuracy: 1e-9)
  }

  func testDecodeProtoDuration_withoutNanoseconds() throws {
    let duration = try decodeProtoDuration("120s")
    XCTAssertEqual(duration.seconds, 120)
    XCTAssertEqual(duration.nanos, 0)

    XCTAssertEqual(duration.timeInterval, 120, accuracy: 1e-9)
  }

  func testDecodeProtoDuration_maxNanosecondDigits() throws {
    let duration = try decodeProtoDuration("15.123456789s")
    XCTAssertEqual(duration.seconds, 15)
    XCTAssertEqual(duration.nanos, 123_456_789)

    XCTAssertEqual(duration.timeInterval, 15.123456789, accuracy: 1e-9)
  }

  func testDecodeProtoDuration_withMilliseconds() throws {
    let duration = try decodeProtoDuration("15.123s")
    XCTAssertEqual(duration.seconds, 15)
    XCTAssertEqual(duration.nanos, 123_000_000)

    XCTAssertEqual(duration.timeInterval, 15.123, accuracy: 1e-9)
  }

  func testDecodeProtoDuration_invalidSeconds() throws {
    guard let error = try expectDecodeFailure("invalid.123s") else { return }
    XCTAssertContains(error.debugDescription, "Invalid proto duration seconds")
  }

  func testDecodeProtoDuration_invalidNanoseconds() throws {
    guard let error = try expectDecodeFailure("123.invalid") else { return }
    XCTAssertContains(error.debugDescription, "Invalid proto duration nanoseconds")
  }

  func testDecodeProtoDuration_tooManyDecimals() throws {
    guard let error = try expectDecodeFailure("123.45.67") else { return }
    XCTAssertContains(error.debugDescription, "Invalid proto duration string")
  }

  func testDecodeProtoDuration_withoutSuffix() throws {
    let duration = try decodeProtoDuration("123.456")
    XCTAssertEqual(duration.seconds, 123)
    XCTAssertEqual(duration.nanos, 456_000_000)

    XCTAssertEqual(duration.timeInterval, 123.456, accuracy: 1e-9)
  }
}
