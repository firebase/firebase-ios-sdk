/*
 * Copyright 2026 Google LLC
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

import FirebaseCore
import FirebaseFirestore
import Foundation
import XCTest

private let windowTestDocs: [String: [String: Any]] = [
  // 2026-07-01T12:00:00Z
  "sale1": [
    "product": "phone",
    "region": "east",
    "salesPrice": 12,
    "quantity": 1,
    "date": Timestamp(seconds: 1_782_907_200, nanoseconds: 0),
  ],
  // 2026-07-02T12:00:00Z
  "sale2": [
    "product": "phone",
    "region": "west",
    "salesPrice": 30,
    "quantity": 2,
    "date": Timestamp(seconds: 1_782_993_600, nanoseconds: 0),
  ],
  // 2026-07-02T18:00:00Z
  "sale3": [
    "product": "tablet",
    "region": "east",
    "salesPrice": 30,
    "quantity": 3,
    "date": Timestamp(seconds: 1_783_015_200, nanoseconds: 0),
  ],
  // 2026-07-04T12:00:00Z
  "sale4": [
    "product": "tablet",
    "region": "west",
    "salesPrice": 60,
    "quantity": 4,
    "date": Timestamp(seconds: 1_783_166_400, nanoseconds: 0),
  ],
  // 2026-07-15T12:00:00Z
  "sale5": [
    "product": "tablet",
    "region": "east",
    "salesPrice": 60,
    "quantity": 5,
    "date": Timestamp(seconds: 1_784_116_800, nanoseconds: 0),
  ],
]

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class PipelineWindowIntegrationTests: FSTIntegrationTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()

    if FSTIntegrationTestCase.backendEdition() == .standard {
      throw XCTSkip(
        "Skipping all tests in PipelineWindowIntegrationTests because backend edition is Standard."
      )
    }
  }

  func testWindowFieldsComputesRunningAggregatesOverAPartitionedMultiKeySortedDocumentsFrame(
  ) async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: WindowSpec.partition([Field("product"), Field("region").toUpper()])
          .sort([Field("date").ascending(), Field("salesPrice").descending()])
          .documents(preceding: .unbounded, following: Constant(0)),
        fields: [
          Field("salesPrice").sum().as("stats.runningTotal"),
          Field("quantity").arrayAgg().as("quantities"),
          CountAll().as("count"),
        ]
      )
      .sort([Field("date").ascending()])
      .select(["product", "stats", "quantities", "count"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "stats": ["runningTotal": 12], "quantities": [1], "count": 1],
      ["product": "phone", "stats": ["runningTotal": 30], "quantities": [2], "count": 1],
      ["product": "tablet", "stats": ["runningTotal": 30], "quantities": [3], "count": 1],
      ["product": "tablet", "stats": ["runningTotal": 60], "quantities": [4], "count": 1],
      ["product": "tablet", "stats": ["runningTotal": 90], "quantities": [3, 5], "count": 2],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsCountsDocumentsInATimeUnitRangeFrame() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .range(preceding: 12, following: .current, unit: TimeGranularity.hour)
          .sort(Field("date").ascending()),
        fields: [Field("quantity").count().as("windowCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "windowCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "windowCount": 1],
      ["product": "phone", "windowCount": 1],
      ["product": "tablet", "windowCount": 2],
      ["product": "tablet", "windowCount": 1],
      ["product": "tablet", "windowCount": 1],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsComputesLookAheadAndNearbyAggregatesWithAccumulatorLevelFrames(
  ) async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .sort(Field("quantity").ascending()),
        fields: [
          Field("salesPrice").average()
            .over(.documents(preceding: -1, following: 2))
            .as("lookAheadAverage"),
          Field("salesPrice").sum()
            .over(.range(preceding: 1.5, following: 0.5))
            .as("nearbyTotal"),
        ]
      )
      .sort([Field("date").ascending()])
      .select(["product", "lookAheadAverage", "nearbyTotal"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 5)
    XCTAssertEqual(snapshot.results[0].get("product") as? String, "phone")
    XCTAssertEqual(snapshot.results[0].get("lookAheadAverage") as? Double, 30.0)
    XCTAssertEqual(snapshot.results[0].get("nearbyTotal") as? Int, 12)

    XCTAssertEqual(snapshot.results[1].get("product") as? String, "phone")
    XCTAssertEqual(snapshot.results[1].get("lookAheadAverage") as? Double, 45.0)
    XCTAssertEqual(snapshot.results[1].get("nearbyTotal") as? Int, 42)

    XCTAssertEqual(snapshot.results[2].get("product") as? String, "tablet")
    XCTAssertEqual(snapshot.results[2].get("lookAheadAverage") as? Double, 60.0)
    XCTAssertEqual(snapshot.results[2].get("nearbyTotal") as? Int, 60)

    XCTAssertEqual(snapshot.results[3].get("product") as? String, "tablet")
    XCTAssertEqual(snapshot.results[3].get("lookAheadAverage") as? Double, 60.0)
    XCTAssertEqual(snapshot.results[3].get("nearbyTotal") as? Int, 90)

    XCTAssertEqual(snapshot.results[4].get("product") as? String, "tablet")
    XCTAssertNil(snapshot.results[4].get("lookAheadAverage"))
    XCTAssertEqual(snapshot.results[4].get("nearbyTotal") as? Int, 120)
  }

  func testWindowFieldsRejectsARangeFrameWithoutASort() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    do {
      _ = try await collRef.firestore.pipeline()
        .collection(collRef.path)
        .addWindowFields(
          window: .range(preceding: .unbounded, following: .current),
          fields: [Field("quantity").count().as("windowCount")]
        )
        .execute()
      XCTFail("Expected error for range frame without a sort")
    } catch {
      XCTAssertTrue(error.localizedDescription.lowercased().contains("range"))
    }
  }

  func testWindowFieldsRejectsDuplicateAliases() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    do {
      _ = try await collRef.firestore.pipeline()
        .collection(collRef.path)
        .addWindowFields(
          window: .partition(["product"]),
          fields: [
            Field("quantity").count().as("dup"),
            Field("salesPrice").sum().as("dup"),
          ]
        )
        .execute()
      XCTFail("Expected error for duplicate alias")
    } catch {
      XCTAssertTrue(error.localizedDescription.lowercased().contains("duplicate alias"))
    }
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class PipelineWindowComprehensiveIntegrationTests: FSTIntegrationTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()

    if FSTIntegrationTestCase.backendEdition() == .standard {
      throw XCTSkip(
        "Skipping PipelineWindowComprehensiveIntegrationTests because backend edition is Standard."
      )
    }

    // Comprehensive window function tests. Skipped by default because the backend
    // already tests window function semantics, and PipelineWindowIntegrationTests
    // exercises the SDK's window function code paths, server errors, and client-side
    // validation. Set FIRESTORE_RUN_COMPREHENSIVE_TESTS=YES (or true) to run them.
    let flag = ProcessInfo.processInfo.environment["FIRESTORE_RUN_COMPREHENSIVE_TESTS"]
    if flag != "YES" && flag != "true" {
      throw XCTSkip("Set FIRESTORE_RUN_COMPREHENSIVE_TESTS=YES to run comprehensive window tests.")
    }
  }

  // --- partitioning --------------------------------------------------------------------------

  func testWindowFieldsEmptySpecIsASingleGlobalWindow() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: WindowSpec(),
        fields: [Field("quantity").count().as("windowCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "windowCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "windowCount": 5],
      ["product": "phone", "windowCount": 5],
      ["product": "tablet", "windowCount": 5],
      ["product": "tablet", "windowCount": 5],
      ["product": "tablet", "windowCount": 5],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsOmittedSpecIsASingleGlobalWindow() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        fields: [Field("quantity").count().as("windowCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "windowCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "windowCount": 5],
      ["product": "phone", "windowCount": 5],
      ["product": "tablet", "windowCount": 5],
      ["product": "tablet", "windowCount": 5],
      ["product": "tablet", "windowCount": 5],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsPartitionsBySingleFieldName() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .partition(["product"]),
        fields: [Field("quantity").count().as("windowCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "windowCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "windowCount": 2],
      ["product": "phone", "windowCount": 2],
      ["product": "tablet", "windowCount": 3],
      ["product": "tablet", "windowCount": 3],
      ["product": "tablet", "windowCount": 3],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsPartitionsByMultipleFields() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .partition(["product", "region"]),
        fields: [Field("quantity").count().as("windowCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "region", "windowCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "region": "east", "windowCount": 1],
      ["product": "phone", "region": "west", "windowCount": 1],
      ["product": "tablet", "region": "east", "windowCount": 2],
      ["product": "tablet", "region": "west", "windowCount": 1],
      ["product": "tablet", "region": "east", "windowCount": 2],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsPartitionsByExpression() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .partition([Field("region").toUpper()]),
        fields: [Field("quantity").count().as("windowCount")]
      )
      .sort([Field("date").ascending()])
      .select(["region", "windowCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["region": "east", "windowCount": 3],
      ["region": "west", "windowCount": 2],
      ["region": "east", "windowCount": 3],
      ["region": "west", "windowCount": 2],
      ["region": "east", "windowCount": 3],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  // --- sorting and default framing -----------------------------------------------------------

  func testWindowFieldsRunningCountWithTheDefaultFrame() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .sort(Field("quantity").ascending()),
        fields: [Field("quantity").count().as("runningCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "runningCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "runningCount": 1],
      ["product": "phone", "runningCount": 2],
      ["product": "tablet", "runningCount": 3],
      ["product": "tablet", "runningCount": 4],
      ["product": "tablet", "runningCount": 5],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsRunningCountWithinEachPartition() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .partition(["product"]).sort(Field("quantity").ascending()),
        fields: [Field("quantity").count().as("runningCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "runningCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "runningCount": 1],
      ["product": "phone", "runningCount": 2],
      ["product": "tablet", "runningCount": 1],
      ["product": "tablet", "runningCount": 2],
      ["product": "tablet", "runningCount": 3],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsHonorsADescendingSort() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .sort(Field("date").descending())
          .documents(preceding: .unbounded, following: .current),
        fields: [Field("quantity").count().as("runningCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "runningCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "runningCount": 5],
      ["product": "phone", "runningCount": 4],
      ["product": "tablet", "runningCount": 3],
      ["product": "tablet", "runningCount": 2],
      ["product": "tablet", "runningCount": 1],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsHonorsMultipleSortOrderings() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .sort([Field("product").ascending(), Field("date").ascending()])
          .documents(preceding: .unbounded, following: .current),
        fields: [Field("quantity").count().as("runningCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "runningCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "runningCount": 1],
      ["product": "phone", "runningCount": 2],
      ["product": "tablet", "runningCount": 3],
      ["product": "tablet", "runningCount": 4],
      ["product": "tablet", "runningCount": 5],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  // --- documents framing ---------------------------------------------------------------------

  func testWindowFieldsDocumentsUnboundedToCurrent() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .documents(preceding: .unbounded, following: .current)
          .sort(Field("date").ascending()),
        fields: [Field("quantity").count().as("windowCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "windowCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "windowCount": 1],
      ["product": "phone", "windowCount": 2],
      ["product": "tablet", "windowCount": 3],
      ["product": "tablet", "windowCount": 4],
      ["product": "tablet", "windowCount": 5],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsDocumentsUnboundedToUnbounded() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .documents(preceding: .unbounded, following: .unbounded)
          .partition(["product"])
          .sort(Field("date").ascending()),
        fields: [Field("quantity").count().as("windowCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "windowCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "windowCount": 2],
      ["product": "phone", "windowCount": 2],
      ["product": "tablet", "windowCount": 3],
      ["product": "tablet", "windowCount": 3],
      ["product": "tablet", "windowCount": 3],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsDocumentsCurrentToCurrent() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .documents(preceding: .current, following: .current)
          .sort(Field("date").ascending()),
        fields: [Field("quantity").count().as("windowCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "windowCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "windowCount": 1],
      ["product": "phone", "windowCount": 1],
      ["product": "tablet", "windowCount": 1],
      ["product": "tablet", "windowCount": 1],
      ["product": "tablet", "windowCount": 1],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsDocumentsZeroPrecedingAndZeroFollowing() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .documents(preceding: 0, following: 0)
          .sort(Field("date").ascending()),
        fields: [Field("quantity").count().as("windowCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "windowCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "windowCount": 1],
      ["product": "phone", "windowCount": 1],
      ["product": "tablet", "windowCount": 1],
      ["product": "tablet", "windowCount": 1],
      ["product": "tablet", "windowCount": 1],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsDocumentsZeroPrecedingToUnboundedFollowing() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .documents(preceding: 0, following: .unbounded)
          .sort(Field("date").ascending()),
        fields: [Field("quantity").count().as("windowCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "windowCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "windowCount": 5],
      ["product": "phone", "windowCount": 4],
      ["product": "tablet", "windowCount": 3],
      ["product": "tablet", "windowCount": 2],
      ["product": "tablet", "windowCount": 1],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  // --- range framing -------------------------------------------------------------------------

  func testWindowFieldsRangeCurrentToCurrentCountsTiedPeers() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .range(preceding: .current, following: .current)
          .partition(["product"])
          .sort(Field("salesPrice").ascending()),
        fields: [Field("quantity").count().as("samePriceCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "salesPrice", "samePriceCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "salesPrice": 12, "samePriceCount": 1],
      ["product": "phone", "salesPrice": 30, "samePriceCount": 1],
      ["product": "tablet", "salesPrice": 30, "samePriceCount": 1],
      ["product": "tablet", "salesPrice": 60, "samePriceCount": 2],
      ["product": "tablet", "salesPrice": 60, "samePriceCount": 2],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsRangeZeroOffsetCountsTiedPeers() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .range(preceding: 0, following: 0)
          .partition(["product"])
          .sort(Field("salesPrice").ascending()),
        fields: [Field("quantity").count().as("samePriceCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "salesPrice", "samePriceCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "salesPrice": 12, "samePriceCount": 1],
      ["product": "phone", "salesPrice": 30, "samePriceCount": 1],
      ["product": "tablet", "salesPrice": 30, "samePriceCount": 1],
      ["product": "tablet", "salesPrice": 60, "samePriceCount": 2],
      ["product": "tablet", "salesPrice": 60, "samePriceCount": 2],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsRangeUnboundedToZeroOffsetIncludesTiedPeers() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .range(preceding: .unbounded, following: 0)
          .sort(Field("salesPrice").ascending()),
        fields: [Field("quantity").count().as("cumulativeCount")]
      )
      .sort([Field("date").ascending()])
      .select(["salesPrice", "cumulativeCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["salesPrice": 12, "cumulativeCount": 1],
      ["salesPrice": 30, "cumulativeCount": 3],
      ["salesPrice": 30, "cumulativeCount": 3],
      ["salesPrice": 60, "cumulativeCount": 5],
      ["salesPrice": 60, "cumulativeCount": 5],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsDocumentsUnboundedToCurrentExcludesTiedPeers() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .documents(preceding: .unbounded, following: .current)
          .sort(Field("salesPrice").ascending()),
        fields: [Field("quantity").count().as("runningCount")]
      )
      .sort([Field("runningCount").ascending()])
      .select(["salesPrice", "runningCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["salesPrice": 12, "runningCount": 1],
      ["salesPrice": 30, "runningCount": 2],
      ["salesPrice": 30, "runningCount": 3],
      ["salesPrice": 60, "runningCount": 4],
      ["salesPrice": 60, "runningCount": 5],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsRangeUnboundedToCurrentIncludesTiedPeers() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .range(preceding: .unbounded, following: .current)
          .sort(Field("salesPrice").ascending()),
        fields: [Field("quantity").count().as("cumulativeCount")]
      )
      .sort([Field("date").ascending()])
      .select(["salesPrice", "cumulativeCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["salesPrice": 12, "cumulativeCount": 1],
      ["salesPrice": 30, "cumulativeCount": 3],
      ["salesPrice": 30, "cumulativeCount": 3],
      ["salesPrice": 60, "cumulativeCount": 5],
      ["salesPrice": 60, "cumulativeCount": 5],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsRangeUnboundedToCurrentWithStringSortKey() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .range(preceding: .unbounded, following: .current)
          .sort(Field("product").ascending()),
        fields: [Field("quantity").count().as("cumulativeCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "cumulativeCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "cumulativeCount": 2],
      ["product": "phone", "cumulativeCount": 2],
      ["product": "tablet", "cumulativeCount": 5],
      ["product": "tablet", "cumulativeCount": 5],
      ["product": "tablet", "cumulativeCount": 5],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsRangeUnboundedToCurrentWithMultipleSortKeys() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .range(preceding: .unbounded, following: .current)
          .sort([Field("product").ascending(), Field("region").ascending()]),
        fields: [Field("quantity").count().as("cumulativeCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "region", "cumulativeCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "region": "east", "cumulativeCount": 1],
      ["product": "phone", "region": "west", "cumulativeCount": 2],
      ["product": "tablet", "region": "east", "cumulativeCount": 4],
      ["product": "tablet", "region": "west", "cumulativeCount": 5],
      ["product": "tablet", "region": "east", "cumulativeCount": 4],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsRangeUnboundedToUnbounded() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .range(preceding: .unbounded, following: .unbounded)
          .partition(["product"])
          .sort(Field("salesPrice").ascending()),
        fields: [Field("quantity").count().as("windowCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "windowCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "windowCount": 2],
      ["product": "phone", "windowCount": 2],
      ["product": "tablet", "windowCount": 3],
      ["product": "tablet", "windowCount": 3],
      ["product": "tablet", "windowCount": 3],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsAppliesTheTimeUnitToARangeFrameOffset() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .range(preceding: 12, following: .current, unit: TimeGranularity.hour)
          .sort(Field("date").ascending()),
        fields: [Field("quantity").count().as("windowCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "windowCount"])
      .execute()

    // None of the fixture dates sit exactly on the 12-hour boundary.
    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "windowCount": 1],
      ["product": "phone", "windowCount": 1],
      ["product": "tablet", "windowCount": 2],
      ["product": "tablet", "windowCount": 1],
      ["product": "tablet", "windowCount": 1],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  // --- accumulator level framing -------------------------------------------------------------

  func testWindowFieldsEvaluatesEachAccumulatorOverItsOwnFrame() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .partition(["product"]).sort(Field("date").ascending()),
        fields: [
          Field("quantity").count()
            .over(.documents(preceding: .unbounded, following: .current))
            .as("runningCount"),
          Field("quantity").count()
            .over(.documents(preceding: .unbounded, following: .unbounded))
            .as("partitionCount"),
        ]
      )
      .sort([Field("date").ascending()])
      .select(["product", "runningCount", "partitionCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "runningCount": 1, "partitionCount": 2],
      ["product": "phone", "runningCount": 2, "partitionCount": 2],
      ["product": "tablet", "runningCount": 1, "partitionCount": 3],
      ["product": "tablet", "runningCount": 2, "partitionCount": 3],
      ["product": "tablet", "runningCount": 3, "partitionCount": 3],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsSupportsARangeFrameInOver() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .partition(["product"]).sort(Field("salesPrice").ascending()),
        fields: [
          Field("quantity").count()
            .over(.range(preceding: 0, following: 0))
            .as("samePriceCount"),
        ]
      )
      .sort([Field("date").ascending()])
      .select(["product", "salesPrice", "samePriceCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "salesPrice": 12, "samePriceCount": 1],
      ["product": "phone", "salesPrice": 30, "samePriceCount": 1],
      ["product": "tablet", "salesPrice": 30, "samePriceCount": 1],
      ["product": "tablet", "salesPrice": 60, "samePriceCount": 2],
      ["product": "tablet", "salesPrice": 60, "samePriceCount": 2],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsMixesPlainAggregateAndFramedWindowFunction() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .partition(["product"]).sort(Field("date").ascending()),
        fields: [
          Field("quantity").count().as("partitionCount"),
          Field("quantity").count()
            .over(.documents(preceding: .unbounded, following: .current))
            .as("runningCount"),
        ]
      )
      .sort([Field("date").ascending()])
      .select(["product", "partitionCount", "runningCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "partitionCount": 2, "runningCount": 1],
      ["product": "phone", "partitionCount": 2, "runningCount": 2],
      ["product": "tablet", "partitionCount": 3, "runningCount": 1],
      ["product": "tablet", "partitionCount": 3, "runningCount": 2],
      ["product": "tablet", "partitionCount": 3, "runningCount": 3],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  // --- output fields and composition ---------------------------------------------------------

  func testWindowFieldsSupportsMultipleOutputFieldsInASingleStage() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .partition(["product"]),
        fields: [
          Field("quantity").count().as("productCount"),
          Field("quantity").count().as("productCountCopy"),
        ]
      )
      .sort([Field("date").ascending()])
      .select(["product", "productCount", "productCountCopy"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "productCount": 2, "productCountCopy": 2],
      ["product": "phone", "productCount": 2, "productCountCopy": 2],
      ["product": "tablet", "productCount": 3, "productCountCopy": 3],
      ["product": "tablet", "productCount": 3, "productCountCopy": 3],
      ["product": "tablet", "productCount": 3, "productCountCopy": 3],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsSupportsNestedOutputFieldPaths() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .partition(["product"]),
        fields: [Field("quantity").count().as("stats.productCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "stats"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "stats": ["productCount": 2]],
      ["product": "phone", "stats": ["productCount": 2]],
      ["product": "tablet", "stats": ["productCount": 3]],
      ["product": "tablet", "stats": ["productCount": 3]],
      ["product": "tablet", "stats": ["productCount": 3]],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsSupportsChainingMultipleStages() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .partition(["product"]),
        fields: [Field("quantity").count().as("productCount")]
      )
      .addWindowFields(
        window: .partition(["region"]),
        fields: [Field("quantity").count().as("regionCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "region", "productCount", "regionCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "region": "east", "productCount": 2, "regionCount": 3],
      ["product": "phone", "region": "west", "productCount": 2, "regionCount": 2],
      ["product": "tablet", "region": "east", "productCount": 3, "regionCount": 3],
      ["product": "tablet", "region": "west", "productCount": 3, "regionCount": 2],
      ["product": "tablet", "region": "east", "productCount": 3, "regionCount": 3],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsSupportsFilteringOnAWindowFieldInALaterStage() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .partition(["product"]),
        fields: [Field("quantity").count().as("productCount")]
      )
      .where(Field("productCount").greaterThan(2))
      .sort([Field("date").ascending()])
      .select(["product", "productCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "tablet", "productCount": 3],
      ["product": "tablet", "productCount": 3],
      ["product": "tablet", "productCount": 3],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsSupportsSortingOnAWindowFieldInALaterStage() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .partition(["product"]),
        fields: [Field("quantity").count().as("productCount")]
      )
      .sort([Field("productCount").ascending(), Field("date").ascending()])
      .select(["product", "productCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "productCount": 2],
      ["product": "phone", "productCount": 2],
      ["product": "tablet", "productCount": 3],
      ["product": "tablet", "productCount": 3],
      ["product": "tablet", "productCount": 3],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  // --- aggregates and frames -----------------------------------------------------------------

  func testWindowFieldsComputesSumAverageMinimumAndMaximum() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .partition(["product"]),
        fields: [
          Field("salesPrice").sum().as("total"),
          Field("salesPrice").average().as("averagePrice"),
          Field("salesPrice").minimum().as("minimumPrice"),
          Field("salesPrice").maximum().as("maximumPrice"),
        ]
      )
      .sort([Field("date").ascending()])
      .select(["product", "total", "averagePrice", "minimumPrice", "maximumPrice"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 5)
    XCTAssertEqual(snapshot.results[0].get("total") as? Int, 42)
    XCTAssertEqual(snapshot.results[0].get("averagePrice") as? Double, 21.0)
    XCTAssertEqual(snapshot.results[0].get("minimumPrice") as? Int, 12)
    XCTAssertEqual(snapshot.results[0].get("maximumPrice") as? Int, 30)

    XCTAssertEqual(snapshot.results[2].get("total") as? Int, 150)
    XCTAssertEqual(snapshot.results[2].get("averagePrice") as? Double, 50.0)
    XCTAssertEqual(snapshot.results[2].get("minimumPrice") as? Int, 30)
    XCTAssertEqual(snapshot.results[2].get("maximumPrice") as? Int, 60)
  }

  func testWindowFieldsComputesCountIfAndCountDistinct() async throws {
    throw XCTSkip("Pending backend support for count_if and count_distinct in add_window_fields")
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .partition(["product"]),
        fields: [
          Field("salesPrice").greaterThan(20).countIf().as("expensiveCount"),
          Field("salesPrice").countDistinct().as("distinctPriceCount"),
        ]
      )
      .sort([Field("date").ascending()])
      .select(["product", "expensiveCount", "distinctPriceCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "expensiveCount": 1, "distinctPriceCount": 2],
      ["product": "phone", "expensiveCount": 1, "distinctPriceCount": 2],
      ["product": "tablet", "expensiveCount": 3, "distinctPriceCount": 2],
      ["product": "tablet", "expensiveCount": 3, "distinctPriceCount": 2],
      ["product": "tablet", "expensiveCount": 3, "distinctPriceCount": 2],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsAggregatesOverAComputedExpression() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .partition(["product"]),
        fields: [
          Field("salesPrice").multiply(Field("quantity")).sum().as("totalRevenue"),
        ]
      )
      .sort([Field("date").ascending()])
      .select(["product", "totalRevenue"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "totalRevenue": 72],
      ["product": "phone", "totalRevenue": 72],
      ["product": "tablet", "totalRevenue": 630],
      ["product": "tablet", "totalRevenue": 630],
      ["product": "tablet", "totalRevenue": 630],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsComputesFirstAndLastOverThePartition() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .documents(preceding: .unbounded, following: .unbounded)
          .partition(["product"])
          .sort(Field("date").ascending()),
        fields: [
          Field("salesPrice").first().as("firstPrice"),
          Field("salesPrice").last().as("lastPrice"),
        ]
      )
      .sort([Field("date").ascending()])
      .select(["product", "firstPrice", "lastPrice"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "firstPrice": 12, "lastPrice": 30],
      ["product": "phone", "firstPrice": 12, "lastPrice": 30],
      ["product": "tablet", "firstPrice": 30, "lastPrice": 60],
      ["product": "tablet", "firstPrice": 30, "lastPrice": 60],
      ["product": "tablet", "firstPrice": 30, "lastPrice": 60],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsComputesArrayAgg() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .documents(preceding: .unbounded, following: .unbounded)
          .partition(["product"])
          .sort(Field("date").ascending()),
        fields: [Field("salesPrice").arrayAgg().as("allPrices")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "allPrices"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 5)
    XCTAssertEqual(snapshot.results[0].get("allPrices") as? [Int], [12, 30])
    XCTAssertEqual(snapshot.results[2].get("allPrices") as? [Int], [30, 60, 60])
  }

  func testWindowFieldsComputesArrayAggDistinct() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .documents(preceding: .unbounded, following: .unbounded)
          .partition(["product"])
          .sort(Field("date").ascending()),
        fields: [Field("salesPrice").arrayAggDistinct().as("distinctPrices")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "distinctPrices"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 5)
    XCTAssertEqual((snapshot.results[0].get("distinctPrices") as? [Int])?.sorted(), [12, 30])
    XCTAssertEqual((snapshot.results[2].get("distinctPrices") as? [Int])?.sorted(), [30, 60])
  }

  func testWindowFieldsComputesARunningTotal() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .documents(preceding: .unbounded, following: .current)
          .sort(Field("date").ascending()),
        fields: [Field("salesPrice").sum().as("runningTotal")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "runningTotal"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "runningTotal": 12],
      ["product": "phone", "runningTotal": 42],
      ["product": "tablet", "runningTotal": 72],
      ["product": "tablet", "runningTotal": 132],
      ["product": "tablet", "runningTotal": 192],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsComputesACenteredMovingAverage() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .documents(preceding: 1, following: 1)
          .sort(Field("date").ascending()),
        fields: [
          Field("salesPrice").average().as("movingAverage"),
          CountAll().as("windowCount"),
        ]
      )
      .sort([Field("date").ascending()])
      .select(["product", "movingAverage", "windowCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "movingAverage": 21.0, "windowCount": 2],
      ["product": "phone", "movingAverage": 24.0, "windowCount": 3],
      ["product": "tablet", "movingAverage": 40.0, "windowCount": 3],
      ["product": "tablet", "movingAverage": 50.0, "windowCount": 3],
      ["product": "tablet", "movingAverage": 60.0, "windowCount": 2],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsComputesATrailingSum() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .documents(preceding: 2, following: 0)
          .sort(Field("date").ascending()),
        fields: [Field("salesPrice").sum().as("trailingTotal")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "trailingTotal"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "trailingTotal": 12],
      ["product": "phone", "trailingTotal": 42],
      ["product": "tablet", "trailingTotal": 72],
      ["product": "tablet", "trailingTotal": 120],
      ["product": "tablet", "trailingTotal": 150],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsComputesALookAheadAverageWithANegativePrecedingBound() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .documents(preceding: -1, following: 2)
          .sort(Field("date").ascending()),
        fields: [
          Field("salesPrice").average().as("lookAheadAverage"),
          CountAll().as("windowCount"),
        ]
      )
      .sort([Field("date").ascending()])
      .select(["product", "lookAheadAverage", "windowCount"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 5)
    XCTAssertEqual(snapshot.results[0].get("lookAheadAverage") as? Double, 30.0)
    XCTAssertEqual(snapshot.results[0].get("windowCount") as? Int, 2)

    XCTAssertEqual(snapshot.results[1].get("lookAheadAverage") as? Double, 45.0)
    XCTAssertEqual(snapshot.results[1].get("windowCount") as? Int, 2)

    XCTAssertEqual(snapshot.results[2].get("lookAheadAverage") as? Double, 60.0)
    XCTAssertEqual(snapshot.results[2].get("windowCount") as? Int, 2)

    XCTAssertEqual(snapshot.results[3].get("lookAheadAverage") as? Double, 60.0)
    XCTAssertEqual(snapshot.results[3].get("windowCount") as? Int, 1)

    XCTAssertNil(snapshot.results[4].get("lookAheadAverage"))
    XCTAssertEqual(snapshot.results[4].get("windowCount") as? Int, 0)
  }

  func testWindowFieldsComputesALookBehindAverageWithANegativeFollowingBound() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .documents(preceding: 2, following: -1)
          .sort(Field("date").ascending()),
        fields: [
          Field("salesPrice").average().as("lookBehindAverage"),
          CountAll().as("windowCount"),
        ]
      )
      .sort([Field("date").ascending()])
      .select(["product", "lookBehindAverage", "windowCount"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 5)
    XCTAssertNil(snapshot.results[0].get("lookBehindAverage"))
    XCTAssertEqual(snapshot.results[0].get("windowCount") as? Int, 0)

    XCTAssertEqual(snapshot.results[1].get("lookBehindAverage") as? Double, 12.0)
    XCTAssertEqual(snapshot.results[1].get("windowCount") as? Int, 1)

    XCTAssertEqual(snapshot.results[2].get("lookBehindAverage") as? Double, 21.0)
    XCTAssertEqual(snapshot.results[2].get("windowCount") as? Int, 2)

    XCTAssertEqual(snapshot.results[3].get("lookBehindAverage") as? Double, 30.0)
    XCTAssertEqual(snapshot.results[3].get("windowCount") as? Int, 2)

    XCTAssertEqual(snapshot.results[4].get("lookBehindAverage") as? Double, 45.0)
    XCTAssertEqual(snapshot.results[4].get("windowCount") as? Int, 2)
  }

  func testWindowFieldsComputesRangeWithNegativeFollowingBound() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .range(preceding: .unbounded, following: -1)
          .sort(Field("salesPrice").ascending()),
        fields: [
          Field("salesPrice").average().as("lowerPriceAverage"),
          CountAll().as("windowCount"),
        ]
      )
      .sort([Field("date").ascending()])
      .select(["product", "lowerPriceAverage", "windowCount"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 5)
    XCTAssertNil(snapshot.results[0].get("lowerPriceAverage"))
    XCTAssertEqual(snapshot.results[0].get("windowCount") as? Int, 0)

    XCTAssertEqual(snapshot.results[1].get("lowerPriceAverage") as? Double, 12.0)
    XCTAssertEqual(snapshot.results[1].get("windowCount") as? Int, 1)

    XCTAssertEqual(snapshot.results[2].get("lowerPriceAverage") as? Double, 12.0)
    XCTAssertEqual(snapshot.results[2].get("windowCount") as? Int, 1)

    XCTAssertEqual(snapshot.results[3].get("lowerPriceAverage") as? Double, 24.0)
    XCTAssertEqual(snapshot.results[3].get("windowCount") as? Int, 3)

    XCTAssertEqual(snapshot.results[4].get("lowerPriceAverage") as? Double, 24.0)
    XCTAssertEqual(snapshot.results[4].get("windowCount") as? Int, 3)
  }

  func testWindowFieldsComputesRangeWithNegativePrecedingBound() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .range(preceding: -1, following: .unbounded)
          .sort(Field("salesPrice").ascending()),
        fields: [
          Field("salesPrice").average().as("higherPriceAverage"),
          CountAll().as("windowCount"),
        ]
      )
      .sort([Field("date").ascending()])
      .select(["product", "higherPriceAverage", "windowCount"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 5)
    XCTAssertEqual(snapshot.results[0].get("higherPriceAverage") as? Double, 45.0)
    XCTAssertEqual(snapshot.results[0].get("windowCount") as? Int, 4)

    XCTAssertEqual(snapshot.results[1].get("higherPriceAverage") as? Double, 60.0)
    XCTAssertEqual(snapshot.results[1].get("windowCount") as? Int, 2)

    XCTAssertEqual(snapshot.results[2].get("higherPriceAverage") as? Double, 60.0)
    XCTAssertEqual(snapshot.results[2].get("windowCount") as? Int, 2)

    XCTAssertNil(snapshot.results[3].get("higherPriceAverage"))
    XCTAssertEqual(snapshot.results[3].get("windowCount") as? Int, 0)

    XCTAssertNil(snapshot.results[4].get("higherPriceAverage"))
    XCTAssertEqual(snapshot.results[4].get("windowCount") as? Int, 0)
  }

  func testWindowFieldsComputesAValueBasedRangeWindow() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .range(preceding: 20, following: 0)
          .sort(Field("salesPrice").ascending()),
        fields: [Field("salesPrice").sum().as("nearbyTotal")]
      )
      .sort([Field("date").ascending()])
      .select(["salesPrice", "nearbyTotal"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["salesPrice": 12, "nearbyTotal": 12],
      ["salesPrice": 30, "nearbyTotal": 72],
      ["salesPrice": 30, "nearbyTotal": 72],
      ["salesPrice": 60, "nearbyTotal": 120],
      ["salesPrice": 60, "nearbyTotal": 120],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsComputesAValueBasedRangeWindowWithDoubleOffsets() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .range(preceding: 17.5, following: 0.5)
          .sort(Field("salesPrice").ascending()),
        fields: [Field("salesPrice").sum().as("nearbyTotal")]
      )
      .sort([Field("date").ascending()])
      .select(["salesPrice", "nearbyTotal"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["salesPrice": 12, "nearbyTotal": 12],
      ["salesPrice": 30, "nearbyTotal": 60],
      ["salesPrice": 30, "nearbyTotal": 60],
      ["salesPrice": 60, "nearbyTotal": 120],
      ["salesPrice": 60, "nearbyTotal": 120],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsComputesATrailingThreeDayTotal() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .range(preceding: 3, following: .current, unit: TimeGranularity.day)
          .sort(Field("date").ascending()),
        fields: [Field("salesPrice").sum().as("threeDayTotal")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "threeDayTotal"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "threeDayTotal": 12],
      ["product": "phone", "threeDayTotal": 42],
      ["product": "tablet", "threeDayTotal": 72],
      ["product": "tablet", "threeDayTotal": 132],
      ["product": "tablet", "threeDayTotal": 60],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsCountAllCountsEveryDocumentInTheWindow() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .partition(["product"]),
        fields: [CountAll().as("windowCount")]
      )
      .sort([Field("date").ascending()])
      .select(["product", "windowCount"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "windowCount": 2],
      ["product": "phone", "windowCount": 2],
      ["product": "tablet", "windowCount": 3],
      ["product": "tablet", "windowCount": 3],
      ["product": "tablet", "windowCount": 3],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsComputesRank() async throws {
    throw XCTSkip("Pending backend support for rank")
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .sort(Field("salesPrice").ascending()),
        fields: [Rank().as("priceRank")]
      )
      .sort([Field("date").ascending()])
      .select(["salesPrice", "priceRank"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["salesPrice": 12, "priceRank": 1],
      ["salesPrice": 30, "priceRank": 2],
      ["salesPrice": 30, "priceRank": 2],
      ["salesPrice": 60, "priceRank": 4],
      ["salesPrice": 60, "priceRank": 4],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  // --- error handling ------------------------------------------------------------------------

  func testWindowFieldsRejectsMixingStageAndAccumulatorFraming() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    do {
      _ = try await collRef.firestore.pipeline()
        .collection(collRef.path)
        .addWindowFields(
          window: .sort(Field("date").ascending())
            .documents(preceding: .unbounded, following: .current),
          fields: [
            Field("quantity").count()
              .over(.documents(preceding: .unbounded, following: .unbounded))
              .as("windowCount"),
          ]
        )
        .execute()
      XCTFail("Expected error for mixing stage and accumulator framing")
    } catch {
      // Expected backend rejection
    }
  }

  func testWindowFieldsEvaluatesAccumulatorsWithoutOverUsingTheDefaultFrameWhenOthersUseOver(
  ) async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    let snapshot = try await collRef.firestore.pipeline()
      .collection(collRef.path)
      .addWindowFields(
        window: .sort(Field("date").ascending()),
        fields: [
          Field("quantity").count()
            .over(.documents(preceding: 0, following: 0))
            .as("framed"),
          // Uses the default frame for a sorted window: unbounded preceding to current.
          Field("quantity").count().as("unframed"),
        ]
      )
      .sort([Field("date").ascending()])
      .select(["product", "framed", "unframed"])
      .execute()

    let expectedResults: [[String: Sendable]] = [
      ["product": "phone", "framed": 1, "unframed": 1],
      ["product": "phone", "framed": 1, "unframed": 2],
      ["product": "tablet", "framed": 1, "unframed": 3],
      ["product": "tablet", "framed": 1, "unframed": 4],
      ["product": "tablet", "framed": 1, "unframed": 5],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWindowFieldsRejectsAPartitionSuppliedToAnAccumulatorLevelOver() async throws {
    let collRef = collectionRef(withDocuments: windowTestDocs)
    do {
      _ = try await collRef.firestore.pipeline()
        .collection(collRef.path)
        .addWindowFields(
          window: .sort(Field("quantity").ascending()),
          fields: [
            Field("quantity").count()
              .over(
                WindowSpec.partition(["product"])
                  .documents(preceding: .unbounded, following: .current)
              )
              .as("windowCount"),
          ]
        )
        .execute()
      XCTFail("Expected error for partition supplied to accumulator-level over()")
    } catch {
      XCTAssertTrue(error.localizedDescription.lowercased().contains("unexpected field"))
    }
  }
}
