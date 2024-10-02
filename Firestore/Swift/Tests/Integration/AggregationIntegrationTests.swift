/*
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import FirebaseFirestore
import Foundation

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AggregationIntegrationTests: FSTIntegrationTestCase {
  func testCount() async throws {
    let collection = collectionRef()
    try await collection.addDocument(data: [:])
    let snapshot = try await collection.count.getAggregation(source: .server)
    XCTAssertEqual(snapshot.count, 1)
  }

  func testCanRunAggregateQuery() async throws {
    let collection = collectionRef()
    try await collection.addDocument(data: ["author": "authorA",
                                            "title": "titleA",
                                            "pages": 100,
                                            "height": 24.5,
                                            "weight": 24.1,
                                            "foo": 1,
                                            "bar": 2,
                                            "baz": 3])
    try await collection.addDocument(data: ["author": "authorB",
                                            "title": "titleB",
                                            "pages": 50,
                                            "height": 25.5,
                                            "weight": 75.5,
                                            "foo": 1,
                                            "bar": 2,
                                            "baz": 3])

    let snapshot = try await collection.aggregate([
      AggregateField.count(),
      AggregateField.sum("pages"),
      AggregateField.average("pages"),
    ]).getAggregation(source: .server)

    // Count
    XCTAssertEqual(snapshot.get(AggregateField.count()) as? NSNumber, 2)

    // Sum
    XCTAssertEqual(snapshot.get(AggregateField.sum("pages")) as? NSNumber, 150)
    XCTAssertEqual(snapshot.get(AggregateField.sum("pages")) as? Double, 150)
    XCTAssertEqual(snapshot.get(AggregateField.sum("pages")) as? Int64, 150)

    // Average
    XCTAssertEqual(snapshot.get(AggregateField.average("pages")) as? NSNumber, 75.0)
    XCTAssertEqual(snapshot.get(AggregateField.average("pages")) as? Double, 75.0)
    XCTAssertEqual(snapshot.get(AggregateField.average("pages")) as? Int64, 75)
  }

  func testCannotPerformMoreThanMaxAggregations() async throws {
    let collection = collectionRef()
    try await collection.addDocument(data: ["author": "authorA",
                                            "title": "titleA",
                                            "pages": 100,
                                            "height": 24.5,
                                            "weight": 24.1,
                                            "foo": 1,
                                            "bar": 2,
                                            "baz": 3])

    // Max is 5, we're attempting 6. I also like to live dangerously.
    do {
      let snapshot = try await collection.aggregate([
        AggregateField.count(),
        AggregateField.sum("pages"),
        AggregateField.sum("weight"),
        AggregateField.average("pages"),
        AggregateField.average("weight"),
        AggregateField.average("foo"),
      ]).getAggregation(source: .server)
      XCTFail("Error expected.")
    } catch let error as NSError {
      XCTAssertNotNil(error)
      XCTAssertTrue(error.localizedDescription.contains("maximum number of aggregations"))
    }
  }

  func testPerformsAggregationsWhenNaNExistsForSomeFieldValues() async throws {
    try XCTSkipIf(!FSTIntegrationTestCase.isRunningAgainstEmulator(),
                  "Skip this test if running against production because it requires a composite index.")

    let collection = collectionRef()
    try await collection.addDocument(data: ["author": "authorA",
                                            "title": "titleA",
                                            "pages": 100,
                                            "year": 1980,
                                            "rating": 4])
    try await collection.addDocument(data: ["author": "authorB",
                                            "title": "titleB",
                                            "pages": 50,
                                            "year": 2020,
                                            "rating": Double.nan])

    let snapshot = try await collection.aggregate([
      AggregateField.sum("pages"),
      AggregateField.sum("rating"),
      AggregateField.average("pages"),
      AggregateField.average("rating"),
    ]).getAggregation(source: .server)

    // Sum
    XCTAssertEqual(snapshot.get(AggregateField.sum("pages")) as? NSNumber, 150)
    XCTAssertTrue((snapshot.get(AggregateField.sum("rating")) as? Double)?.isNaN ?? false)

    // Average
    XCTAssertEqual(snapshot.get(AggregateField.average("pages")) as? NSNumber, 75.0)
    XCTAssertTrue((snapshot.get(AggregateField.average("rating")) as? Double)?.isNaN ?? false)
  }

  func testThrowsAnErrorWhenGettingTheResultOfAnUnrequestedAggregation() async throws {
    let collection = collectionRef()
    try await collection.addDocument(data: [:])

    let snapshot = try await collection.aggregate([AggregateField.average("foo")])
      .getAggregation(source: .server)

    XCTAssertTrue(FSTNSExceptionUtil.testForException({
      snapshot.count
    }, reasonContains: "'count()' was not requested in the aggregation query"))

    XCTAssertTrue(FSTNSExceptionUtil.testForException({
      snapshot.get(AggregateField.sum("foo"))
    }, reasonContains: "'sum(foo)' was not requested in the aggregation query"))

    XCTAssertTrue(FSTNSExceptionUtil.testForException({
      snapshot.get(AggregateField.average("bar"))
    }, reasonContains: "'avg(bar)' was not requested in the aggregation query"))
  }

  func testPerformsAggregationsOnNestedMapValues() async throws {
    let collection = collectionRef()
    try await collection.addDocument(data: ["metadata": [
      "pages": 100,
      "rating": [
        "critic": 2,
        "user": 5,
      ],
    ]])
    try await collection.addDocument(data: ["metadata": [
      "pages": 50,
      "rating": [
        "critic": 4,
        "user": 4,
      ],
    ]])

    let snapshot = try await collection.aggregate([
      AggregateField.count(),
      AggregateField.sum("metadata.pages"),
      AggregateField.average("metadata.pages"),
    ]).getAggregation(source: .server)

    // Count
    XCTAssertEqual(snapshot.get(AggregateField.count()) as? NSNumber, 2)

    // Sum
    XCTAssertEqual(
      snapshot.get(AggregateField.sum(FieldPath(["metadata", "pages"]))) as? NSNumber,
      150
    )
    XCTAssertEqual(snapshot.get(AggregateField.sum("metadata.pages")) as? NSNumber, 150)

    // Average
    XCTAssertEqual(
      snapshot.get(AggregateField.average(FieldPath(["metadata", "pages"]))) as? Double,
      75.0
    )
  }

  func testSumOverflow() async throws {
    try XCTSkipIf(!FSTIntegrationTestCase.isRunningAgainstEmulator(),
                  "Skip this test if running against production because it requires a composite index.")

    let collection = collectionRef()
    try await collection.addDocument(data: [
      "longOverflow": Int64.max,
      "accumulationOverflow": Int64.max,
      "positiveInfinity": Double.greatestFiniteMagnitude,
      "negativeInfinity": -Double.greatestFiniteMagnitude,
    ])
    try await collection.addDocument(data: [
      "longOverflow": Int64.max,
      "accumulationOverflow": 1,
      "positiveInfinity": Double.greatestFiniteMagnitude,
      "negativeInfinity": -Double.greatestFiniteMagnitude,
    ])
    try await collection.addDocument(data: [
      "longOverflow": Int64.max,
      "accumulationOverflow": -101,
      "positiveInfinity": Double.greatestFiniteMagnitude,
      "negativeInfinity": -Double.greatestFiniteMagnitude,
    ])

    let snapshot = try await collection.aggregate([
      AggregateField.sum("longOverflow"),
      AggregateField.sum("accumulationOverflow"),
      AggregateField.sum("positiveInfinity"),
      AggregateField.sum("negativeInfinity"),
    ]).getAggregation(source: .server)

    // Sum
    XCTAssertEqual(
      snapshot.get(AggregateField.sum("longOverflow")) as? Double,
      Double(Int64.max) + Double(Int64.max) + Double(Int64.max)
    )
    XCTAssertEqual(
      snapshot.get(AggregateField.sum("accumulationOverflow")) as? Int64,
      Int64.max - 100
    )
    XCTAssertEqual(
      snapshot.get(AggregateField.sum("positiveInfinity")) as? Double,
      Double.infinity
    )
    XCTAssertEqual(
      snapshot.get(AggregateField.sum("negativeInfinity")) as? Double,
      -Double.infinity
    )
  }

  func testAverageOverflow() async throws {
    try XCTSkipIf(!FSTIntegrationTestCase.isRunningAgainstEmulator(),
                  "Skip this test if running against production because it requires a composite index.")

    let collection = collectionRef()
    try await collection.addDocument(data: [
      "longOverflow": Int64.max,
      "doubleOverflow": Double.greatestFiniteMagnitude,
      "negativeInfinity": -Double.greatestFiniteMagnitude,
    ])
    try await collection.addDocument(data: [
      "longOverflow": Int64.max,
      "doubleOverflow": Double.greatestFiniteMagnitude,
      "negativeInfinity": -Double.greatestFiniteMagnitude,
    ])
    try await collection.addDocument(data: [
      "longOverflow": Int64.max,
      "doubleOverflow": Double.greatestFiniteMagnitude,
      "negativeInfinity": -Double.greatestFiniteMagnitude,
    ])

    let snapshot = try await collection.aggregate([
      AggregateField.average("longOverflow"),
      AggregateField.average("doubleOverflow"),
      AggregateField.average("negativeInfinity"),
    ]).getAggregation(source: .server)

    // Average
    XCTAssertEqual(
      snapshot.get(AggregateField.average("longOverflow")) as? Double,
      Double(Int64.max)
    )
    XCTAssertEqual(
      snapshot.get(AggregateField.average("doubleOverflow")) as? Double,
      Double.infinity
    )
    XCTAssertEqual(
      snapshot.get(AggregateField.average("negativeInfinity")) as? Double,
      -Double.infinity
    )
  }

  func testAverageUnderflow() async throws {
    let collection = collectionRef()
    try await collection.addDocument(data: ["underflowSmall": Double.leastNonzeroMagnitude])
    try await collection.addDocument(data: ["underflowSmall": 0])

    let snapshot = try await collection.aggregate([AggregateField.average("underflowSmall")])
      .getAggregation(source: .server)

    // Average
    XCTAssertEqual(snapshot.get(AggregateField.average("underflowSmall")) as? Double, 0.0)
  }

  func testPerformsAggregateOverResultSetOfZeroDocuments() async throws {
    let collection = collectionRef()
    try await collection.addDocument(data: ["pages": 100])
    try await collection.addDocument(data: ["pages": 50])

    let snapshot = try await collection.whereField("pages", isGreaterThan: 200)
      .aggregate([AggregateField.count(), AggregateField.sum("pages"),
                  AggregateField.average("pages")]).getAggregation(source: .server)

    // Count
    XCTAssertEqual(snapshot.get(AggregateField.count()) as? NSNumber, 0)

    // Sum
    XCTAssertEqual(snapshot.get(AggregateField.sum("pages")) as? NSNumber, 0)

    // Average
    XCTAssertEqual(snapshot.get(AggregateField.average("pages")) as? NSNull, NSNull())
  }

  func testPerformsAggregateOverResultSetOfZeroFields() async throws {
    let collection = collectionRef()
    try await collection.addDocument(data: ["pages": 100])
    try await collection.addDocument(data: ["pages": 50])

    let snapshot = try await collection
      .aggregate([AggregateField.count(), AggregateField.sum("notInMyDocs"),
                  AggregateField.average("notInMyDocs")]).getAggregation(source: .server)

    // Count  - 0 because aggregation is performed on documents matching the query AND documents
    // that have all aggregated fields
    XCTAssertEqual(snapshot.get(AggregateField.count()) as? NSNumber, 0)

    // Sum
    XCTAssertEqual(snapshot.get(AggregateField.sum("notInMyDocs")) as? NSNumber, 0)

    // Average
    XCTAssertEqual(snapshot.get(AggregateField.average("notInMyDocs")) as? NSNull, NSNull())
  }
}
