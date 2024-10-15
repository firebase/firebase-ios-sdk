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

@testable import FirebaseVertexAI

final class ProtoDateTests: XCTestCase {
  let decoder = JSONDecoder()

  // A full date, with non-zero year, month, and day values.
  func testProtoDate_fullDate_dateComponents() {
    let year = 2024
    let month = 12
    let day = 31
    let protoDate = ProtoDate(year: year, month: month, day: day)

    let dateComponents = protoDate.dateComponents

    XCTAssertTrue(dateComponents.isValidDate)
    XCTAssertEqual(dateComponents.year, year)
    XCTAssertEqual(dateComponents.month, month)
    XCTAssertEqual(dateComponents.day, day)
  }

  // A month and day value, with a zero year, such as an anniversary.
  func testProtoDate_monthDay_dateComponents() {
    let month = 7
    let day = 1
    let protoDate = ProtoDate(year: nil, month: month, day: day)

    let dateComponents = protoDate.dateComponents

    XCTAssertTrue(dateComponents.isValidDate)
    XCTAssertNil(dateComponents.year)
    XCTAssertEqual(dateComponents.month, month)
    XCTAssertEqual(dateComponents.day, day)
  }

  // A year on its own, with zero month and day values.
  func testProtoDate_yearOnly_dateComponents() {
    let year = 2024
    let protoDate = ProtoDate(year: year, month: nil, day: nil)

    let dateComponents = protoDate.dateComponents

    XCTAssertTrue(dateComponents.isValidDate)
    XCTAssertEqual(dateComponents.year, year)
    XCTAssertNil(dateComponents.month)
    XCTAssertNil(dateComponents.day)
  }

  // A year and month value, with a zero day, such as a credit card expiration date
  func testProtoDate_yearMonth_dateComponents() {
    let year = 2024
    let month = 08
    let protoDate = ProtoDate(year: year, month: month, day: nil)

    let dateComponents = protoDate.dateComponents

    XCTAssertTrue(dateComponents.isValidDate)
    XCTAssertEqual(protoDate.year, year)
    XCTAssertEqual(protoDate.month, month)
    XCTAssertEqual(protoDate.day, nil)
  }

  func testProtoDate_asDate() throws {
    let protoDate = ProtoDate(year: 2024, month: 12, day: 31)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let expectedDate = try XCTUnwrap(dateFormatter.date(from: "2024-12-31"))

    let date = try XCTUnwrap(protoDate.dateComponents.date)

    XCTAssertEqual(date, expectedDate)
  }

  func testDecodeProtoDate() throws {
    let json = """
    {
      "year" : 2024,
      "month" : 12,
      "day" : 31
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let protoDate = try decoder.decode(ProtoDate.self, from: jsonData)

    XCTAssertEqual(protoDate.year, 2024)
    XCTAssertEqual(protoDate.month, 12)
    XCTAssertEqual(protoDate.day, 31)
  }

  func testDecodeProtoDate_emptyDate_throws() throws {
    let json = "{}"
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    do {
      _ = try decoder.decode(ProtoDate.self, from: jsonData)
    } catch DecodingError.dataCorrupted {
      return
    }
    XCTFail("Expected a DecodingError.")
  }
}
