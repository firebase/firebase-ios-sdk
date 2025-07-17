/*
 * Copyright 2025 Google LLC
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

import Combine
import FirebaseFirestore
import Foundation

// iOS 15 required for test implementation, not BSON types
@available(iOS 15, tvOS 15, macOS 12.0, macCatalyst 13, watchOS 7, *)
class BsonTypesIntegrationTests: FSTIntegrationTestCase {
  func toDataArray(_ snapshot: QuerySnapshot) -> [[String: Any]] {
    return snapshot.documents.map { document in
      document.data()
    }
  }

  func toDocIdArray(_ snapshot: QuerySnapshot) -> [String] {
    return snapshot.documents.map { document in
      document.documentID
    }
  }

  func setDocumentData(
    _ documentDataMap: [String: [String: Any]],
    toCollection: CollectionReference
  ) async {
    for (documentName, documentData) in documentDataMap {
      do {
        try await toCollection.document(documentName).setData(documentData)
      } catch {
        print("Failed to write documents to collection.")
      }
    }
  }

  func verifySnapshot(snapshot: QuerySnapshot,
                      allData: [String: [String: Any]],
                      expectedDocIds: [String],
                      description: String) throws {
    XCTAssertEqual(snapshot.count, expectedDocIds.count)

    XCTAssertTrue(expectedDocIds == toDocIdArray(snapshot),
                  "Did not get the same documents in query result set for '\(description)'. Expected Doc IDs: \(expectedDocIds), Actual Doc IDs: \(toDocIdArray(snapshot))")

    for i in 0 ..< expectedDocIds.count {
      let expectedDocId = expectedDocIds[i]
      let expectedDocData = allData[expectedDocId] ?? [:]
      let actualDocData = snapshot.documents[i].data()

      // We don't need to compare expectedDocId and actualDocId because
      // it's already been checked above. We only compare the data below.
      let nsExpected = NSDictionary(dictionary: expectedDocData)
      let nsActual = NSDictionary(dictionary: actualDocData)
      XCTAssertTrue(
        nsExpected.isEqual(nsActual),
        "Did not get the same document content. Expected Doc Data: \(nsExpected), Actual Doc Data:\(nsActual)"
      )
    }
  }

  // Asserts that the given query produces the expected result for all of the
  // following scenarios:
  // 1. Using a snapshot listener to get the first snapshot for the query.
  // 2. Performing the given query using source=server.
  // 3. Performing the given query using source=cache.
  func assertSdkQueryResultsConsistentWithBackend(_ documentDataMap: [String: [String: Any]],
                                                  collection: CollectionReference,
                                                  query: Query,
                                                  expectedResult: [String]) async throws {
    let watchSnapshot = try await Future<QuerySnapshot, Error>() { promise in
      query.addSnapshotListener { snapshot, error in
        if let error {
          promise(Result.failure(error))
        }
        if let snapshot {
          promise(Result.success(snapshot))
        }
      }
    }.value

    try verifySnapshot(
      snapshot: watchSnapshot,
      allData: documentDataMap,
      expectedDocIds: expectedResult,
      description: "snapshot listener"
    )

    checkOnlineAndOfflineCollection(collection, query: query, matchesResult: expectedResult)
  }

  func testCanWriteAndReadBsonTypes() async throws {
    let collection = collectionRef()
    let ref = try await collection.addDocument(data: [
      "binary": BSONBinaryData(subtype: 1, data: Data([1, 2, 3])),
      "objectId": BSONObjectId("507f191e810c19729de860ea"),
      "int32": Int32Value(1),
      "decimal128": Decimal128Value("1.2e3"),
      "min": MinKey.shared,
      "max": MaxKey.shared,
      "regex": RegexValue(pattern: "^foo", options: "i"),
    ])

    try await ref.updateData([
      "binary": BSONBinaryData(subtype: 1, data: Data([1, 2, 3])),
      "timestamp": BSONTimestamp(seconds: 1, increment: 2),
      "int32": Int32Value(2),
    ])

    let snapshot = try await ref.getDocument()
    XCTAssertEqual(
      snapshot.get("objectId") as? BSONObjectId,
      BSONObjectId("507f191e810c19729de860ea")
    )
    XCTAssertEqual(
      snapshot.get("int32") as? Int32Value,
      Int32Value(2)
    )
    XCTAssertEqual(
      snapshot.get("decimal128") as? Decimal128Value,
      Decimal128Value("1.2e3")
    )
    XCTAssertEqual(
      snapshot.get("min") as? MinKey,
      MinKey.shared
    )
    XCTAssertEqual(
      snapshot.get("max") as? MaxKey,
      MaxKey.shared
    )
    XCTAssertEqual(
      snapshot.get("binary") as? BSONBinaryData,
      BSONBinaryData(subtype: 1, data: Data([1, 2, 3]))
    )
    XCTAssertEqual(
      snapshot.get("timestamp") as? BSONTimestamp,
      BSONTimestamp(seconds: 1, increment: 2)
    )
    XCTAssertEqual(
      snapshot.get("regex") as? RegexValue,
      RegexValue(pattern: "^foo", options: "i")
    )
  }

  func testCanWriteAndReadBsonTypesOffline() throws {
    let collection = collectionRef()
    disableNetwork()

    let ref = collection.document("doc")

    // Adding docs to cache, do not wait for promise to resolve.
    ref.setData([
      "binary": BSONBinaryData(subtype: 1, data: Data([1, 2, 3])),
      "objectId": BSONObjectId("507f191e810c19729de860ea"),
      "int32": Int32Value(1),
      "decimal128": Decimal128Value("-1.23e-4"),
      "min": MinKey.shared,
      "max": MaxKey.shared,
      "regex": RegexValue(pattern: "^foo", options: "i"),
    ])
    ref.updateData([
      "binary": BSONBinaryData(subtype: 128, data: Data([1, 2, 3])),
      "timestamp": BSONTimestamp(seconds: 1, increment: 2),
      "int32": Int32Value(2),
    ])

    let snapshot = readDocument(forRef: ref, source: FirestoreSource.cache)
    XCTAssertEqual(
      snapshot.get("objectId") as? BSONObjectId,
      BSONObjectId("507f191e810c19729de860ea")
    )
    XCTAssertEqual(
      snapshot.get("int32") as? Int32Value,
      Int32Value(2)
    )
    XCTAssertEqual(
      snapshot.get("decimal128") as? Decimal128Value,
      Decimal128Value("-1.23e-4")
    )
    XCTAssertEqual(
      snapshot.get("min") as? MinKey,
      MinKey.shared
    )
    XCTAssertEqual(
      snapshot.get("max") as? MaxKey,
      MaxKey.shared
    )
    XCTAssertEqual(
      snapshot.get("binary") as? BSONBinaryData,
      BSONBinaryData(subtype: 128, data: Data([1, 2, 3]))
    )
    XCTAssertEqual(
      snapshot.get("timestamp") as? BSONTimestamp,
      BSONTimestamp(seconds: 1, increment: 2)
    )
    XCTAssertEqual(
      snapshot.get("regex") as? RegexValue,
      RegexValue(pattern: "^foo", options: "i")
    )
  }

  func testCanFilterAndOrderObjectIds() async throws {
    let testDocs = [
      "a": ["key": BSONObjectId("507f191e810c19729de860ea")],
      "b": ["key": BSONObjectId("507f191e810c19729de860eb")],
      "c": ["key": BSONObjectId("507f191e810c19729de860ec")],
    ]

    let collection = collectionRef()
    await setDocumentData(testDocs, toCollection: collection)

    var query = collection
      .whereField("key", isGreaterThan: BSONObjectId("507f191e810c19729de860ea"))
      .order(by: "key", descending: true)

    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["c", "b"]
    )

    query = collection
      .whereField("key", in:
        [
          BSONObjectId("507f191e810c19729de860ea"),
          BSONObjectId("507f191e810c19729de860eb"),
        ])
      .order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["b", "a"]
    )
  }

  func testCanFilterAndOrderInt32Values() async throws {
    let testDocs: [String: [String: Any]] = [
      "a": ["key": Int32Value(-1)],
      "b": ["key": Int32Value(1)],
      "c": ["key": Int32Value(2)],
    ]

    let collection = collectionRef()
    await setDocumentData(testDocs, toCollection: collection)

    var query = collection
      .whereField("key", isGreaterThanOrEqualTo: Int32Value(1))
      .order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["c", "b"]
    )

    query = collection
      .whereField("key", notIn: [Int32Value(1)])
      .order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["c", "a"]
    )
  }

  func testCanFilterAndOrderDecimal128Values() async throws {
    let testDocs: [String: [String: Any]] = [
      "a": ["key": Decimal128Value("-Infinity")],
      "b": ["key": Decimal128Value("NaN")],
      "c": ["key": Decimal128Value("-0")],
      "d": ["key": Decimal128Value("0")],
      "e": ["key": Decimal128Value("0.0")],
      "f": ["key": Decimal128Value("-01.23e-4")],
      "g": ["key": Decimal128Value("1.5e6")],
      "h": ["key": Decimal128Value("Infinity")],
    ]

    let collection = collectionRef()
    await setDocumentData(testDocs, toCollection: collection)

    var query = collection
      .whereField("key", isGreaterThanOrEqualTo: Decimal128Value("0"))
      .order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["h", "g", "e", "d", "c"]
    )

    query = collection
      .whereField("key", isNotEqualTo: Decimal128Value("0"))
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["b", "a", "f", "g", "h"]
    )

    query = collection
      .whereField("key", isNotEqualTo: Decimal128Value("NaN"))
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["a", "f", "c", "d", "e", "g", "h"]
    )

    query = collection
      .whereField("key", isEqualTo: Decimal128Value("-01.23e-4"))
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["f"]
    )

    query = collection
      .whereField("key", isNotEqualTo: Decimal128Value("-01.23e-4"))
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["b", "a", "c", "d", "e", "g", "h"]
    )

    query = collection
      .whereField("key", in: [Decimal128Value("0")])
      .order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["e", "d", "c"]
    )

    // Note: The server sends document `b` incorrectly, but the client filters
    // it out. Currently `FieldFilter.NOT_IN` with `NaN` in the list does not
    // behave the same as `UnaryFilter.IS_NOT_NAN`.
    query = collection
      .whereField("key", notIn: [Decimal128Value("NaN"), Decimal128Value("Infinity")])
      .order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["g", "e", "d", "c", "f", "a"]
    )
  }

  func testCanFilterAndOrderNumericalValues() async throws {
    let testDocs: [String: [String: Any]] = [
      "a": ["key": Decimal128Value("-1.2e3")],
      "b": ["key": Int32Value(0)],
      "c": ["key": Decimal128Value("1")],
      "d": ["key": Int32Value(1)],
      "e": ["key": 1],
      "f": ["key": 1.0],
      "g": ["key": Decimal128Value("1.2e-3")],
      "h": ["key": Int32Value(2)],
      "i": ["key": Decimal128Value("NaN")],
      "j": ["key": Decimal128Value("-Infinity")],
      "k": ["key": Double.nan],
      "l": ["key": Decimal128Value("Infinity")],
    ]

    let collection = collectionRef()
    await setDocumentData(testDocs, toCollection: collection)

    let query = collection.order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: [
        "l", // Infinity
        "h", // 2
        "f", // 1.0
        "e", // 1
        "d", // 1
        "c", // 1
        "g", // 0.0012
        "b", // 0
        "a", // -1200
        "j", // -Infinity
        "k", // NaN
        "i", // NaN
      ]
    )

    let query2 = collection
      .whereField("key", isNotEqualTo: Decimal128Value("1.0"))
      .order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query2,
      expectedResult: ["l", "h", "g", "b", "a", "j", "k", "i"]
    )

    let query3 = collection
      .whereField("key", isEqualTo: 1)
      .order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query3,
      expectedResult: ["f", "e", "d", "c"]
    )
  }

  func testDecimal128ValuesWithNo2sComplementRepresentation() async throws {
    let testDocs: [String: [String: Any]] = [
      "a": ["key": Decimal128Value("-1.1e-3")], // -0.0011
      "b": ["key": Decimal128Value("1.1")],
      "c": ["key": 1.1],
      "d": ["key": 1.0],
      "e": ["key": Decimal128Value("1.1e-3")], // 0.0011
    ]

    let collection = collectionRef()
    await setDocumentData(testDocs, toCollection: collection)

    let query = collection
      .whereField("key", isEqualTo: Decimal128Value("1.1"))
      .order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["b"]
    )

    let query2 = collection
      .whereField("key", isNotEqualTo: Decimal128Value("1.1"))
      .order(by: "key", descending: false)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query2,
      expectedResult: ["a", "e", "d", "c"]
    )

    let query3 = collection
      .whereField("key", isEqualTo: 1.1)
      .order(by: "key", descending: false)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query3,
      expectedResult: ["c"]
    )

    let query4 = collection
      .whereField("key", isNotEqualTo: 1.1)
      .order(by: "key", descending: false)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query4,
      expectedResult: ["a", "e", "d", "b"]
    )
  }

  func testCanFilterAndOrderTimestampValues() async throws {
    let testDocs: [String: [String: Any]] = [
      "a": ["key": BSONTimestamp(seconds: 1, increment: 1)],
      "b": ["key": BSONTimestamp(seconds: 1, increment: 2)],
      "c": ["key": BSONTimestamp(seconds: 2, increment: 1)],
    ]

    let collection = collectionRef()
    await setDocumentData(testDocs, toCollection: collection)

    var query = collection
      .whereField("key", isGreaterThan: BSONTimestamp(seconds: 1, increment: 1))
      .order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["c", "b"]
    )

    query = collection
      .whereField("key", isNotEqualTo: BSONTimestamp(seconds: 1, increment: 1))
      .order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["c", "b"]
    )
  }

  func testCanFilterAndOrderBinaryValues() async throws {
    let testDocs: [String: [String: Any]] = [
      "a": ["key": BSONBinaryData(subtype: 1, data: Data([1, 2, 3]))],
      "b": ["key": BSONBinaryData(subtype: 1, data: Data([1, 2, 4]))],
      "c": ["key": BSONBinaryData(subtype: 2, data: Data([1, 2, 3]))],
    ]

    let collection = collectionRef()
    await setDocumentData(testDocs, toCollection: collection)

    var query = collection
      .whereField(
        "key",
        isGreaterThan: BSONBinaryData(subtype: 1, data: Data([1, 2, 3]))
      )
      .order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["c", "b"]
    )

    query = collection
      .whereField(
        "key",
        isGreaterThanOrEqualTo: BSONBinaryData(subtype: 1, data: Data([1, 2, 3]))
      )
      .whereField(
        "key",
        isLessThan: BSONBinaryData(subtype: 2, data: Data([1, 2, 3]))
      )
      .order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["b", "a"]
    )
  }

  func testCanFilterAndOrderRegexValues() async throws {
    let testDocs = [
      "a": ["key": RegexValue(pattern: "^bar", options: "i")],
      "b": ["key": RegexValue(pattern: "^bar", options: "x")],
      "c": ["key": RegexValue(pattern: "^baz", options: "i")],
    ]

    let collection = collectionRef()
    await setDocumentData(testDocs, toCollection: collection)

    let query =
      collection.whereFilter(
        Filter.orFilter([
          Filter.whereField("key", isGreaterThan: RegexValue(pattern: "^bar", options: "x")),
          Filter.whereField("key", isNotEqualTo: RegexValue(pattern: "^bar", options: "x")),
        ])
      ).order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["c", "a"]
    )
  }

  func testCanFilterAndOrderMinKeyValues() async throws {
    let testDocs: [String: [String: Any]] = [
      "a": ["key": MinKey.shared],
      "b": ["key": MinKey.shared],
      "c": ["key": NSNull()],
      "d": ["key": 1],
      "e": ["key": MaxKey.shared],
    ]

    let collection = collectionRef()
    await setDocumentData(testDocs, toCollection: collection)

    var query = collection
      .whereField("key", isEqualTo: MinKey.shared)
      .order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["b", "a"]
    )

    query = collection
      .whereField("key", isNotEqualTo: MinKey.shared)
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["d", "e"]
    )

    query = collection
      .whereField("key", isGreaterThanOrEqualTo: MinKey.shared)
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["a", "b"]
    )

    query = collection
      .whereField("key", isLessThanOrEqualTo: MinKey.shared)
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["a", "b"]
    )

    query = collection
      .whereField("key", isGreaterThan: MinKey.shared)
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: []
    )

    query = collection
      .whereField("key", isLessThan: MinKey.shared)
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: []
    )

    query = collection
      .whereField("key", isLessThan: 1)
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: []
    )
  }

  func testCanFilterAndOrderMaxKeyValues() async throws {
    let testDocs: [String: [String: Any]] = [
      "a": ["key": MinKey.shared],
      "b": ["key": 1],
      "c": ["key": MaxKey.shared],
      "d": ["key": MaxKey.shared],
      "e": ["key": NSNull()],
    ]

    let collection = collectionRef()
    await setDocumentData(testDocs, toCollection: collection)

    var query = collection
      .whereField("key", isEqualTo: MaxKey.shared)
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["c", "d"]
    )

    query = collection
      .whereField("key", isNotEqualTo: MaxKey.shared)
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["a", "b"]
    )

    query = collection
      .whereField("key", isGreaterThanOrEqualTo: MaxKey.shared)
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["c", "d"]
    )

    query = collection
      .whereField("key", isLessThanOrEqualTo: MaxKey.shared)
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["c", "d"]
    )

    query = collection
      .whereField("key", isGreaterThan: MaxKey.shared)
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: []
    )

    query = collection
      .whereField("key", isLessThan: MaxKey.shared)
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: []
    )

    query = collection
      .whereField("key", isGreaterThan: 1)
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: []
    )
  }

  func testCanHandleNullWithBsonValues() async throws {
    let testDocs: [String: [String: Any]] = [
      "a": ["key": MinKey.shared],
      "b": ["key": NSNull()],
      "c": ["key": NSNull()],
      "d": ["key": 1],
      "e": ["key": MaxKey.shared],
    ]

    let collection = collectionRef()
    await setDocumentData(testDocs, toCollection: collection)

    var query = collection
      .whereField("key", isEqualTo: NSNull())
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["b", "c"]
    )

    query = collection
      .whereField("key", isNotEqualTo: NSNull())
      .order(by: "key")
    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: query,
      expectedResult: ["a", "d", "e"]
    )
  }

  func testCanOrderBsonValues() async throws {
    // This test includes several BSON values of different types and ensures
    // correct inter-type and intra-type order for BSON values.
    let testDocs: [String: [String: Any]] = [
      "bsonObjectId1": ["key": BSONObjectId("507f191e810c19729de860ea")],
      "bsonObjectId2": ["key": BSONObjectId("507f191e810c19729de860eb")],
      "bsonObjectId3": ["key": BSONObjectId("407f191e810c19729de860ea")],
      "regex1": ["key": RegexValue(pattern: "^bar", options: "m")],
      "regex2": ["key": RegexValue(pattern: "^bar", options: "i")],
      "regex3": ["key": RegexValue(pattern: "^baz", options: "i")],
      "bsonTimestamp1": ["key": BSONTimestamp(seconds: 2, increment: 0)],
      "bsonTimestamp2": ["key": BSONTimestamp(seconds: 1, increment: 2)],
      "bsonTimestamp3": ["key": BSONTimestamp(seconds: 1, increment: 1)],
      "bsonBinary1": ["key": BSONBinaryData(subtype: 1, data: Data([1, 2, 3]))],
      "bsonBinary2": ["key": BSONBinaryData(subtype: 1, data: Data([1, 2, 4]))],
      "bsonBinary3": ["key": BSONBinaryData(subtype: 2, data: Data([1, 2, 2]))],
      "decimal128Value1": ["key": Decimal128Value("NaN")],
      "decimal128Value2": ["key": Decimal128Value("-Infinity")],
      "decimal128Value3": ["key": Decimal128Value("-1.0")],
      "int32Value1": ["key": Int32Value(-1)],
      "decimal128Value4": ["key": Decimal128Value("1.0")],
      "int32Value2": ["key": Int32Value(1)],
      "decimal128Value5": ["key": Decimal128Value("-0.0")],
      "decimal128Value6": ["key": Decimal128Value("0.0")],
      "int32Value3": ["key": Int32Value(0)],
      "decimal128Value7": ["key": Decimal128Value("1.23e-4")],
      "decimal128Value8": ["key": Decimal128Value("Infinity")],
      "minKey1": ["key": MinKey.shared],
      "minKey2": ["key": MinKey.shared],
      "maxKey1": ["key": MaxKey.shared],
      "maxKey2": ["key": MaxKey.shared],
    ]

    let collection = collectionRef()
    await setDocumentData(testDocs, toCollection: collection)

    let query = collection.order(by: "key", descending: true)
    try await assertSdkQueryResultsConsistentWithBackend(testDocs,
                                                         collection: collection,
                                                         query: query, expectedResult: [
                                                           "maxKey2",
                                                           "maxKey1",
                                                           "regex3",
                                                           "regex1",
                                                           "regex2",
                                                           "bsonObjectId2",
                                                           "bsonObjectId1",
                                                           "bsonObjectId3",
                                                           "bsonBinary3",
                                                           "bsonBinary2",
                                                           "bsonBinary1",
                                                           "bsonTimestamp1",
                                                           "bsonTimestamp2",
                                                           "bsonTimestamp3",
                                                           "decimal128Value8",
                                                           "int32Value2",
                                                           "decimal128Value4",
                                                           "decimal128Value7",
                                                           "int32Value3",
                                                           "decimal128Value6",
                                                           "decimal128Value5",
                                                           "int32Value1",
                                                           "decimal128Value3",
                                                           "decimal128Value2",
                                                           "decimal128Value1",
                                                           "minKey2",
                                                           "minKey1",
                                                         ])
  }

  func testCanOrderValuesOfDifferentTypes() async throws {
    // This test has only 1 value of each type, and ensures correct order
    // across all types.
    let collection = collectionRef()
    let testDocs: [String: [String: Any]] = [
      "nullValue": ["key": NSNull()],
      "minValue": ["key": MinKey.shared],
      "booleanValue": ["key": true],
      "nanValue": ["key": Double.nan],
      "nanValue2": ["key": Decimal128Value("NaN")],
      "negativeInfinity": ["key": Decimal128Value("-Infinity")],
      "int32Value": ["key": Int32Value(1)],
      "doubleValue": ["key": 2.0],
      "integerValue": ["key": 3],
      "decimal128Value": ["key": Decimal128Value("3.4e-5")],
      "infinity": ["key": Decimal128Value("Infinity")],
      "timestampValue": ["key": Timestamp(seconds: 100, nanoseconds: 123_456_000)],
      "bsonTimestampValue": ["key": BSONTimestamp(seconds: 1, increment: 2)],
      "stringValue": ["key": "string"],
      "bytesValue": ["key": Data([0, 1, 255])],
      "bsonBinaryValue": ["key": BSONBinaryData(subtype: 1, data: Data([1, 2, 3]))],
      "referenceValue": ["key": collection.document("doc")],
      "objectIdValue": ["key": BSONObjectId("507f191e810c19729de860ea")],
      "geoPointValue": ["key": GeoPoint(latitude: 0, longitude: 0)],
      "regexValue": ["key": RegexValue(pattern: "^foo", options: "i")],
      "arrayValue": ["key": [1, 2]],
      "vectorValue": ["key": VectorValue([1.0, 2.0])],
      "objectValue": ["key": ["a": 1]],
      "maxValue": ["key": MaxKey.shared],
    ]

    for (docId, data) in testDocs {
      try await collection.document(docId).setData(data as [String: Any])
    }

    let orderedQuery = collection.order(by: "key")

    let expectedOrder = [
      "nullValue",
      "minValue",
      "booleanValue",
      "nanValue",
      "nanValue2",
      "negativeInfinity",
      "decimal128Value",
      "int32Value",
      "doubleValue",
      "integerValue",
      "infinity",
      "timestampValue",
      "bsonTimestampValue",
      "stringValue",
      "bytesValue",
      "bsonBinaryValue",
      "referenceValue",
      "objectIdValue",
      "geoPointValue",
      "regexValue",
      "arrayValue",
      "vectorValue",
      "objectValue",
      "maxValue",
    ]

    try await assertSdkQueryResultsConsistentWithBackend(
      testDocs,
      collection: collection,
      query: orderedQuery,
      expectedResult: expectedOrder
    )
  }

  func testCanRunTransactionsOnDocumentsWithBsonTypes() async throws {
    let testDocs = [
      "a": ["key": BSONTimestamp(seconds: 1, increment: 2)],
      "b": ["key": "placeholder"],
      "c": ["key": BSONBinaryData(subtype: 1, data: Data([1, 2, 3]))],
    ]

    let collection = collectionRef()
    await setDocumentData(testDocs, toCollection: collection)

    try await runTransaction(collection.firestore, block: { transaction, errorPointer -> Any? in
      transaction.setData(
        ["key": RegexValue(pattern: "^foo", options: "i")],
        forDocument: collection.document("b")
      )
      transaction.deleteDocument(collection.document("c"))
      return true
    })

    let snapshot = try await collection.getDocuments()
    print("snapshot.size=")
    print(snapshot.documents.count)
    print(toDataArray(snapshot))
    XCTAssertEqual(
      toDataArray(snapshot) as? [[String: RegexValue]],
      [
        ["key": BSONTimestamp(seconds: 1, increment: 2)],
        ["key": RegexValue(pattern: "^foo", options: "i")],
      ] as? [[String: RegexValue]]
    )
  }
}
