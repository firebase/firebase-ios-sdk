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

import FirebaseCore
@testable import FirebaseDataConnect

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final class IntegrationTests: XCTestCase {
  class func setupFirebaseApp() {
    if FirebaseApp.app() == nil {
      let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                    gcmSenderID: "00000000000000000-00000000000-000000000")
      options.projectID = "fdc-test"
      FirebaseApp.configure(options: options)
    }
  }

  override class func setUp() {
    setupFirebaseApp()
    DataConnect.kitchenSinkClient.useEmulator(port: 3628)
  }

  override func setUp(completion: @escaping ((any Error)?) -> Void) {
    Task {
      do {
        try await ProjectConfigurator.shared.configureProject()
        completion(nil)
      } catch {
        completion(error)
      }
    }
  }

  // test to confirm that we can assign an explicit UUID
  func testSpecifiedUUID() async throws {
    let specifiedUUID = UUID()
    let result = try await DataConnect.kitchenSinkClient.createTestIdMutationRef(id: specifiedUUID)
      .execute()
    XCTAssertEqual(result.data.testId_insert.id, specifiedUUID)
  }

  // test for an auto generated UUID assignment
  func testAutoId() async throws {
    let result = try await DataConnect.kitchenSinkClient.createTestAutoIdMutationRef().execute()
    _ = result.data.testAutoId_insert.id
    // if we get till here - we have successfully got a UUID and decoded it. So test is successful
    XCTAssert(true)
  }

  func testStandardScalar() async throws {
    let standardScalarUUID = UUID()
    let testText = "Hello Firebase World"
    let testDecimal = Double.random(in: 10.0 ... 999.0)
    let testInt = Int(Int32.random(in: Int32.min ... Int32.max))
    // The following fails since server returns a different value.
    // The value is outside the 32-bit range and GQL Int is 32-bits.
    // Tracked internally with issue - b/358198261
    // let testInt = -6196243450739521536

    let executeResult = try await DataConnect.kitchenSinkClient.createStandardScalarMutationRef(
      id: standardScalarUUID,
      number: testInt,
      text: testText,
      decimal: testDecimal
    ).execute()

    XCTAssertEqual(
      executeResult.data.standardScalars_insert.id,
      standardScalarUUID,
      "UUID mismatch between specified and returned"
    )

    let queryResult = try await DataConnect.kitchenSinkClient
      .getStandardScalarQueryRef(id: standardScalarUUID).execute()

    let returnedDecimal = queryResult.data.standardScalars?.decimal
    XCTAssertEqual(
      returnedDecimal,
      testDecimal,
      "Decimal value mismatch between sent \(testDecimal) and received \(String(describing: returnedDecimal))"
    )

    let returnedNumber = queryResult.data.standardScalars?.number
    XCTAssertEqual(
      returnedNumber,
      testInt,
      "Int value mismatch between sent \(testInt) and received \(String(describing: returnedNumber))"
    )

    let returnedText = queryResult.data.standardScalars?.text
    XCTAssertEqual(
      returnedText,
      testText,
      "String value mismatch between sent \(testText) and received \(String(describing: returnedText))"
    )
  }

  func testScalarBoundaries() async throws {
    let scalaryBoundaryUUID = UUID()

    let maxInt = Int(Int32.max)
    let minInt = Int(Int32.min)
    let maxFloat = Double.greatestFiniteMagnitude
    let minFloat = Double.leastNormalMagnitude

    _ = try await DataConnect.kitchenSinkClient.createScalarBoundaryMutationRef(
      id: scalaryBoundaryUUID,
      maxNumber: maxInt,
      minNumber: minInt,
      maxDecimal: maxFloat,
      minDecimal: minFloat
    ).execute()

    let queryResult = try await DataConnect.kitchenSinkClient
      .getScalarBoundaryQueryRef(id: scalaryBoundaryUUID).execute()

    let returnedMaxInt = queryResult.data.scalarBoundary?.maxNumber
    XCTAssertEqual(
      returnedMaxInt,
      maxInt,
      "Returned maxInt \(String(describing: returnedMaxInt)) is not same as sent \(maxInt)"
    )

    let returnedMinInt = queryResult.data.scalarBoundary?.minNumber
    XCTAssertEqual(
      returnedMinInt,
      minInt,
      "Returned minInt \(minInt) is not same as sent \(minInt)"
    )

    let returnedMaxFloat = queryResult.data.scalarBoundary?.maxDecimal
    XCTAssertEqual(
      returnedMaxFloat,
      maxFloat,
      "Returned maxFloat \(String(describing: returnedMaxFloat)) is not same as sent \(maxFloat)"
    )

    let returnedMinFloat = queryResult.data.scalarBoundary?.minDecimal
    XCTAssertEqual(
      returnedMinFloat,
      minFloat,
      "Returned minFloat \(String(describing: returnedMinFloat)) is not same as sent \(minFloat)"
    )
  }

  func testLargeNum() async throws {
    let largeNumUUID = UUID()
    let largeNum = Int64.random(in: Int64.min ... Int64.max)
    let largeNumMax = Int64.max
    let largeNumMin = Int64.min

    _ = try await DataConnect.kitchenSinkClient.createLargeNumMutationRef(
      id: largeNumUUID,
      num: largeNum,
      maxNum: largeNumMax,
      minNum: largeNumMin
    ).execute()

    let result = try await DataConnect.kitchenSinkClient.getLargeNumQueryRef(id: largeNumUUID)
      .execute()

    let returnedLargeNum = result.data.largeIntType?.num
    XCTAssertEqual(
      returnedLargeNum,
      largeNum,
      "Int64 returned \(String(describing: returnedLargeNum)) does not match sent \(largeNum)"
    )

    let returnedMax = result.data.largeIntType?.maxNum
    XCTAssertEqual(
      returnedMax,
      largeNumMax,
      "Int64 max returned \(String(describing: returnedMax)) does not match sent \(largeNumMax)"
    )

    let returnedMin = result.data.largeIntType?.minNum
    XCTAssertEqual(
      returnedMin,
      largeNumMin,
      "Int64 min returned \(String(describing: returnedMin)) does not match sent \(largeNumMin)"
    )
  }

  func testLocalDateSerialization() async throws {
    let localDateUUID = UUID()
    let ld = try LocalDate(localDateString: "2024-11-01")

    _ = try await DataConnect.kitchenSinkClient.createLocalDateMutationRef(
      id: localDateUUID,
      localDate: ld
    ).execute()

    let result = try await DataConnect.kitchenSinkClient.getLocalDateTypeQueryRef(id: localDateUUID)
      .execute()
    let returnedLd = result.data.localDateType?.localDate
    XCTAssertEqual(ld, returnedLd)
  }
}
