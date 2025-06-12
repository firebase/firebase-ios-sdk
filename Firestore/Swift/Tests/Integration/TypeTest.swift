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
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class TypeTest: FSTIntegrationTestCase {
  // Note: Type tests are missing from our Swift Integration tests.
  // Below we're adding new tests for BSON types.
  // TODO(b/403333631): Port other (non-BSON) tests to Swift.

  func expectRoundtrip(coll: CollectionReference,
                       data: [String: Any],
                       validateSnapshots: Bool = true,
                       expectedData: [String: Any]? = nil) async throws -> DocumentSnapshot {
    let expectedData = expectedData ?? data
    let docRef = coll.document("a")

    try await docRef.setData(data)
    var docSnapshot = try await docRef.getDocument()
    XCTAssertEqual(docSnapshot.data() as NSDictionary?, expectedData as NSDictionary?)

    try await docRef.updateData(data)
    docSnapshot = try await docRef.getDocument()
    XCTAssertEqual(docSnapshot.data() as NSDictionary?, expectedData as NSDictionary?)

    // Validate that the transaction API returns the same types
    _ = try await db.runTransaction { transaction, errorPointer in
      do {
        let transactionSnapshot = try transaction.getDocument(docRef)
        XCTAssertEqual(
          transactionSnapshot.data() as NSDictionary?,
          expectedData as NSDictionary?
        )
        return nil // Transaction doesn't need to modify data in this test
      } catch {
        errorPointer?.pointee = error as NSError
        return nil
      }
    }

    if validateSnapshots {
      let querySnapshot = try await coll.getDocuments()
      if let firstDoc = querySnapshot.documents.first {
        docSnapshot = firstDoc
        XCTAssertEqual(docSnapshot.data() as NSDictionary?, expectedData as NSDictionary?)
      } else {
        XCTFail("No documents found in collection snapshot")
      }

      let expectation = XCTestExpectation(description: "Snapshot listener received data")
      var listener: ListenerRegistration?
      listener = coll.addSnapshotListener { snapshot, error in
        guard let snapshot = snapshot, let firstDoc = snapshot.documents.first,
              error == nil else {
          XCTFail(
            "Error fetching snapshot: \(error?.localizedDescription ?? "Unknown error")"
          )
          expectation.fulfill()
          return
        }
        XCTAssertEqual(firstDoc.data() as NSDictionary?, expectedData as NSDictionary?)
        expectation.fulfill()

        // Stop listening after receiving the first snapshot
        listener?.remove()
      }

      // Wait for the listener to fire
      await fulfillment(of: [expectation], timeout: 5.0)
    }

    return docSnapshot
  }

  /*
   * A Note on Equality Tests:
   *
   * Since `isEqual` is a public Obj-c API, we should test that the
   * `==` and `!=` operator in Swift is comparing objects correctly.
   */

  func testMinKeyEquality() {
    let k1 = MinKey.shared
    let k2 = MinKey.shared
    XCTAssertTrue(k1 == k2)
    XCTAssertFalse(k1 != k2)
  }

  func testMaxKeyEquality() {
    let k1 = MaxKey.shared
    let k2 = MaxKey.shared
    XCTAssertTrue(k1 == k2)
    XCTAssertFalse(k1 != k2)
  }

  func testRegexValueEquality() {
    let v1 = RegexValue(pattern: "foo", options: "bar")
    let v2 = RegexValue(pattern: "foo", options: "bar")
    let v3 = RegexValue(pattern: "foo_3", options: "bar")
    let v4 = RegexValue(pattern: "foo", options: "bar_4")

    XCTAssertTrue(v1 == v2)
    XCTAssertFalse(v1 == v3)
    XCTAssertFalse(v1 == v4)

    XCTAssertFalse(v1 != v2)
    XCTAssertTrue(v1 != v3)
    XCTAssertTrue(v1 != v4)
  }

  func testInt32ValueEquality() {
    let v1 = Int32Value(1)
    let v2 = Int32Value(1)
    let v3 = Int32Value(-1)

    XCTAssertTrue(v1 == v2)
    XCTAssertFalse(v1 == v3)

    XCTAssertFalse(v1 != v2)
    XCTAssertTrue(v1 != v3)
  }

  func testBsonTimestampEquality() {
    let v1 = BSONTimestamp(seconds: 1, increment: 1)
    let v2 = BSONTimestamp(seconds: 1, increment: 1)
    let v3 = BSONTimestamp(seconds: 1, increment: 2)
    let v4 = BSONTimestamp(seconds: 2, increment: 1)

    XCTAssertTrue(v1 == v2)
    XCTAssertFalse(v1 == v3)
    XCTAssertFalse(v1 == v4)

    XCTAssertFalse(v1 != v2)
    XCTAssertTrue(v1 != v3)
    XCTAssertTrue(v1 != v4)
  }

  func testBsonObjectIdEquality() {
    let v1 = BSONObjectId("foo")
    let v2 = BSONObjectId("foo")
    let v3 = BSONObjectId("bar")

    XCTAssertTrue(v1 == v2)
    XCTAssertFalse(v1 == v3)

    XCTAssertFalse(v1 != v2)
    XCTAssertTrue(v1 != v3)
  }

  func testBsonBinaryDataEquality() {
    let v1 = BSONBinaryData(subtype: 1, data: Data([1, 2, 3]))
    let v2 = BSONBinaryData(subtype: 1, data: Data([1, 2, 3]))
    let v3 = BSONBinaryData(subtype: 128, data: Data([1, 2, 3]))
    let v4 = BSONBinaryData(subtype: 1, data: Data([1, 2, 3, 4]))

    XCTAssertTrue(v1 == v2)
    XCTAssertFalse(v1 == v3)
    XCTAssertFalse(v1 == v4)

    XCTAssertFalse(v1 != v2)
    XCTAssertTrue(v1 != v3)
    XCTAssertTrue(v1 != v4)
  }

  func testCanReadAndWriteMinKeyFields() async throws {
    _ = try await expectRoundtrip(
      coll: collectionRef(),
      data: ["min": MinKey.shared]
    )
  }

  func testCanReadAndWriteMaxKeyFields() async throws {
    _ = try await expectRoundtrip(
      coll: collectionRef(),
      data: ["max": MaxKey.shared]
    )
  }

  func testCanReadAndWriteRegexFields() async throws {
    _ = try await expectRoundtrip(
      coll: collectionRef(),
      data: ["regex": RegexValue(pattern: "^foo", options: "i")]
    )
  }

  func testCanReadAndWriteInt32Fields() async throws {
    _ = try await expectRoundtrip(
      coll: collectionRef(),
      data: ["int32": Int32Value(1)]
    )
  }

  func testCanReadAndWriteBsonTimestampFields() async throws {
    _ = try await expectRoundtrip(
      coll: collectionRef(),
      data: ["bsonTimestamp": BSONTimestamp(seconds: 1, increment: 2)]
    )
  }

  func testCanReadAndWriteBsonObjectIdFields() async throws {
    _ = try await expectRoundtrip(
      coll: collectionRef(),
      data: ["bsonObjectId": BSONObjectId("507f191e810c19729de860ea")]
    )
  }

  func testCanReadAndWriteBsonBinaryDataFields() async throws {
    _ = try await expectRoundtrip(
      coll: collectionRef(),
      data: ["bsonBinaryData": BSONBinaryData(subtype: 1, data: Data([1, 2, 3]))]
    )
    _ = try await expectRoundtrip(
      coll: collectionRef(),
      data: ["bsonBinaryData": BSONBinaryData(subtype: 128, data: Data([1, 2, 3]))]
    )
    _ = try await expectRoundtrip(
      coll: collectionRef(),
      data: ["bsonBinaryData": BSONBinaryData(subtype: 255, data: Data([]))]
    )
  }

  func testCanReadAndWriteBsonFieldsInAnArray() async throws {
    _ = try await expectRoundtrip(
      coll: collectionRef(),
      data: ["array": [
        BSONBinaryData(subtype: 1, data: Data([1, 2, 3])),
        BSONObjectId("507f191e810c19729de860ea"),
        BSONTimestamp(seconds: 123, increment: 456),
        Int32Value(1),
        MinKey.shared,
        MaxKey.shared,
        RegexValue(pattern: "^foo", options: "i"),
      ]]
    )
  }

  func testCanReadAndWriteBsonFieldsInAnObject() async throws {
    _ = try await expectRoundtrip(
      coll: collectionRef(),
      data: ["array": [
        "binary": BSONBinaryData(subtype: 1, data: Data([1, 2, 3])),
        "objectId": BSONObjectId("507f191e810c19729de860ea"),
        "bsonTimestamp": BSONTimestamp(seconds: 123, increment: 456),
        "int32": Int32Value(1),
        "min": MinKey.shared,
        "max": MaxKey.shared,
        "regex": RegexValue(pattern: "^foo", options: "i"),
      ]]
    )
  }

  func testInvalidRegexValueGetsRejected() async throws {
    let docRef = collectionRef().document("test-doc")
    var errorMessage: String?

    do {
      // Using an invalid regex option "a"
      try await docRef.setData(["key": RegexValue(pattern: "foo", options: "a")])
      XCTFail("Expected error for invalid regex option")
    } catch {
      errorMessage = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String
      XCTAssertNotNil(errorMessage)
      XCTAssertTrue(
        errorMessage!
          .contains("Invalid regex option 'a'. Supported options are 'i', 'm', 's', 'u', and 'x'."),
        "Unexpected error message: \(errorMessage ?? "nil")"
      )
    }
  }

  func testInvalidBsonObjectIdValueGetsRejected() async throws {
    let docRef = collectionRef().document("test-doc")
    var errorMessage: String?

    do {
      // BSONObjectId with string length not equal to 24
      try await docRef.setData(["key": BSONObjectId("foo")])
      XCTFail("Expected error for invalid BSON Object ID string length")
    } catch {
      errorMessage = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String
      XCTAssertNotNil(errorMessage)
      XCTAssertTrue(
        errorMessage!.contains("Object ID hex string has incorrect length."),
        "Unexpected error message: \(errorMessage ?? "nil")"
      )
    }
  }

  func testCanOrderValuesOfDifferentTypeOrderTogether() async throws {
    let collection = collectionRef()
    let testDocs: [String: [String: Any?]] = [
      "nullValue": ["key": NSNull()],
      "minValue": ["key": MinKey.shared],
      "booleanValue": ["key": true],
      "nanValue": ["key": Double.nan],
      "int32Value": ["key": Int32Value(1)],
      "doubleValue": ["key": 2.0],
      "integerValue": ["key": 3],
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
    let snapshot = try await orderedQuery.getDocuments()

    let expectedOrder = [
      "nullValue",
      "minValue",
      "booleanValue",
      "nanValue",
      "int32Value",
      "doubleValue",
      "integerValue",
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

    XCTAssertEqual(snapshot.documents.count, testDocs.count)

    for i in 0 ..< snapshot.documents.count {
      let actualDocSnapshot = snapshot.documents[i]
      let actualKeyValue = actualDocSnapshot.data()["key"]
      let expectedDocId = expectedOrder[i]
      let expectedKeyValue = testDocs[expectedDocId]!["key"]

      XCTAssertEqual(actualDocSnapshot.documentID, expectedDocId)

      // Since we have a 'nullValue' case, we should use `as?`.
      XCTAssert(actualKeyValue as? NSObject == expectedKeyValue as? NSObject)
    }
  }
}
