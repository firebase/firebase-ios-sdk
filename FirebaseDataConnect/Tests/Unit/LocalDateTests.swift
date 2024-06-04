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

@testable import FirebaseDataConnect
import Foundation

final class LocalDateTests: XCTestCase {
  override func setUpWithError() throws {}

  override func tearDownWithError() throws {}

  func testEqualityWithDifferentCreationMethods() throws {
    let ldString = try LocalDate(localDateString: "2024-05-14")
    let ldComponents = try LocalDate(year: 2024, month: 5, day: 14)

    XCTAssertEqual(ldString, ldComponents)
  }

  func testEqualitySameDayInstances() throws {

    let calendar = Calendar(identifier: .gregorian)
    let dc = DateComponents(calendar: calendar, year: 2024, month: 6, day: 1, hour: 6, minute: 5)

    let date = calendar.date(from: dc)!

    let ld1 = LocalDate(date: date)

    let date2 = date.addingTimeInterval(72.0) //add 60 seconds. Should be same day
    let ld2 = LocalDate(date: date2)

    XCTAssertEqual(ld1, ld2)
  }

  func testLessThan() throws {
    let ldLower = try LocalDate(localDateString: "2023-12-29")
    let ldHigher = try LocalDate(localDateString: "2024-02-01")

    XCTAssertTrue(ldLower < ldHigher)
  }

  func testInvalidLessThan() throws {
    let ldLower = try LocalDate(localDateString: "2023-12-29")
    let ldHigher = try LocalDate(localDateString: "2024-02-01")

    XCTAssertFalse(ldLower > ldHigher)
  }

  func testInvalidDateComponents() throws {
    XCTAssertThrowsError(try LocalDate(year: 2024, month: 13, day: 45))
  }

  func testEncodingDecodingJSON() throws {
    let ld = try LocalDate(year: 2024, month: 05, day: 14)

    let jsonEncoder = JSONEncoder()
    let jsonData = try jsonEncoder.encode(ld)

    let jsonDecoder = JSONDecoder()
    let decodedLocalDate = try jsonDecoder.decode(LocalDate.self, from: jsonData)

    XCTAssertEqual(ld, decodedLocalDate)
  }
}
