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

import FirebaseCore
import FirebaseFirestore
import Foundation
import XCTest

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class QueryToPipelineTests: FSTIntegrationTestCase {
  let testUnsupportedFeatures = false

  private func verifyResults(_ snapshot: PipelineSnapshot,
                             _ expected: [[String: AnyHashable?]],
                             enforceOrder: Bool = false,
                             file: StaticString = #file,
                             line: UInt = #line) {
    let results = snapshot.results.map { $0.data as! [String: AnyHashable?] }
    XCTAssertEqual(results.count, expected.count, "Result count mismatch.", file: file, line: line)

    if enforceOrder {
      for i in 0 ..< expected.count {
        XCTAssertEqual(
          results[i],
          expected[i],
          "Document at index \(i) does not match.",
          file: file,
          line: line
        )
      }
    } else {
      // For unordered comparison, convert to Sets of dictionaries.
      XCTAssertEqual(
        Set(results),
        Set(expected),
        "Result sets do not match.",
        file: file,
        line: line
      )
    }
  }

  func testSupportsDefaultQuery() async throws {
    let collRef = collectionRef(withDocuments: ["1": ["foo": 1]])
    let db = collRef.firestore

    let pipeline = db.pipeline().create(from: collRef)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 1]])
  }

  func testSupportsFilteredQuery() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1],
      "2": ["foo": 2],
    ])
    let db = collRef.firestore

    let query = collRef.whereField("foo", isEqualTo: 1)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 1]])
  }

  func testSupportsFilteredQueryWithFieldPath() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1],
      "2": ["foo": 2],
    ])
    let db = collRef.firestore

    let query = collRef.whereField(FieldPath(["foo"]), isEqualTo: 1)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 1]])
  }

  func testSupportsOrderedQueryWithDefaultOrder() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1],
      "2": ["foo": 2],
    ])
    let db = collRef.firestore

    let query = collRef.order(by: "foo")
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 1], ["foo": 2]], enforceOrder: true)
  }

  func testSupportsOrderedQueryWithAsc() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1],
      "2": ["foo": 2],
    ])
    let db = collRef.firestore

    let query = collRef.order(by: "foo", descending: false)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 1], ["foo": 2]], enforceOrder: true)
  }

  func testSupportsOrderedQueryWithDesc() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1],
      "2": ["foo": 2],
    ])
    let db = collRef.firestore

    let query = collRef.order(by: "foo", descending: true)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 2], ["foo": 1]], enforceOrder: true)
  }

  func testSupportsLimitQuery() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1],
      "2": ["foo": 2],
    ])
    let db = collRef.firestore

    let query = collRef.order(by: "foo").limit(to: 1)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 1]], enforceOrder: true)
  }

  func testSupportsLimitToLastQuery() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1],
      "2": ["foo": 2],
      "3": ["foo": 3],
    ])
    let db = collRef.firestore

    let query = collRef.order(by: "foo").limit(toLast: 2)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 2], ["foo": 3]], enforceOrder: true)
  }

  func testSupportsStartAt() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1],
      "2": ["foo": 2],
    ])
    let db = collRef.firestore

    let query = collRef.order(by: "foo").start(at: [2])
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 2]], enforceOrder: true)
  }

  func testSupportsStartAtWithLimitToLast() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1],
      "2": ["foo": 2],
      "3": ["foo": 3],
      "4": ["foo": 4],
      "5": ["foo": 5],
    ])
    let db = collRef.firestore

    let query = collRef.order(by: "foo").start(at: [3]).limit(toLast: 4)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 3], ["foo": 4], ["foo": 5]], enforceOrder: true)
  }

  func testSupportsEndAtWithLimitToLast() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1],
      "2": ["foo": 2],
      "3": ["foo": 3],
      "4": ["foo": 4],
      "5": ["foo": 5],
    ])
    let db = collRef.firestore

    let query = collRef.order(by: "foo").end(at: [3]).limit(toLast: 2)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 2], ["foo": 3]], enforceOrder: true)
  }

  func testSupportsStartAfterWithDocumentSnapshot() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["id": 1, "foo": 1, "bar": 1, "baz": 1],
      "2": ["id": 2, "foo": 1, "bar": 1, "baz": 2],
      "3": ["id": 3, "foo": 1, "bar": 1, "baz": 2],
      "4": ["id": 4, "foo": 1, "bar": 2, "baz": 1],
      "5": ["id": 5, "foo": 1, "bar": 2, "baz": 2],
      "6": ["id": 6, "foo": 1, "bar": 2, "baz": 2],
      "7": ["id": 7, "foo": 2, "bar": 1, "baz": 1],
      "8": ["id": 8, "foo": 2, "bar": 1, "baz": 2],
      "9": ["id": 9, "foo": 2, "bar": 1, "baz": 2],
      "10": ["id": 10, "foo": 2, "bar": 2, "baz": 1],
      "11": ["id": 11, "foo": 2, "bar": 2, "baz": 2],
      "12": ["id": 12, "foo": 2, "bar": 2, "baz": 2],
    ])
    let db = collRef.firestore

    var docRef = try await collRef.document("2").getDocument()
    var query = collRef.order(by: "foo").order(by: "bar").order(by: "baz")
      .start(afterDocument: docRef)
    var pipeline = db.pipeline().create(from: query)
    var snapshot = try await pipeline.execute()

    verifyResults(
      snapshot,
      [
        ["id": 3, "foo": 1, "bar": 1, "baz": 2],
        ["id": 4, "foo": 1, "bar": 2, "baz": 1],
        ["id": 5, "foo": 1, "bar": 2, "baz": 2],
        ["id": 6, "foo": 1, "bar": 2, "baz": 2],
        ["id": 7, "foo": 2, "bar": 1, "baz": 1],
        ["id": 8, "foo": 2, "bar": 1, "baz": 2],
        ["id": 9, "foo": 2, "bar": 1, "baz": 2],
        ["id": 10, "foo": 2, "bar": 2, "baz": 1],
        ["id": 11, "foo": 2, "bar": 2, "baz": 2],
        ["id": 12, "foo": 2, "bar": 2, "baz": 2],
      ],
      enforceOrder: true
    )

    docRef = try await collRef.document("3").getDocument()
    query = collRef.order(by: "foo").order(by: "bar").order(by: "baz").start(afterDocument: docRef)
    pipeline = db.pipeline().create(from: query)
    snapshot = try await pipeline.execute()
    verifyResults(
      snapshot,
      [
        ["id": 4, "foo": 1, "bar": 2, "baz": 1],
        ["id": 5, "foo": 1, "bar": 2, "baz": 2],
        ["id": 6, "foo": 1, "bar": 2, "baz": 2],
        ["id": 7, "foo": 2, "bar": 1, "baz": 1],
        ["id": 8, "foo": 2, "bar": 1, "baz": 2],
        ["id": 9, "foo": 2, "bar": 1, "baz": 2],
        ["id": 10, "foo": 2, "bar": 2, "baz": 1],
        ["id": 11, "foo": 2, "bar": 2, "baz": 2],
        ["id": 12, "foo": 2, "bar": 2, "baz": 2],
      ],
      enforceOrder: true
    )
  }

  func testSupportsStartAtWithDocumentSnapshot() async throws {
    try XCTSkipIf(true, "Unsupported feature: sort on __name__ is not working")
    let collRef = collectionRef(withDocuments: [
      "1": ["id": 1, "foo": 1, "bar": 1, "baz": 1],
      "2": ["id": 2, "foo": 1, "bar": 1, "baz": 2],
      "3": ["id": 3, "foo": 1, "bar": 1, "baz": 2],
      "4": ["id": 4, "foo": 1, "bar": 2, "baz": 1],
      "5": ["id": 5, "foo": 1, "bar": 2, "baz": 2],
      "6": ["id": 6, "foo": 1, "bar": 2, "baz": 2],
      "7": ["id": 7, "foo": 2, "bar": 1, "baz": 1],
      "8": ["id": 8, "foo": 2, "bar": 1, "baz": 2],
      "9": ["id": 9, "foo": 2, "bar": 1, "baz": 2],
      "10": ["id": 10, "foo": 2, "bar": 2, "baz": 1],
      "11": ["id": 11, "foo": 2, "bar": 2, "baz": 2],
      "12": ["id": 12, "foo": 2, "bar": 2, "baz": 2],
    ])
    let db = collRef.firestore

    var docRef = try await collRef.document("2").getDocument()
    var query = collRef.order(by: "foo").order(by: "bar").order(by: "baz").start(atDocument: docRef)
    var pipeline = db.pipeline().create(from: query)
    var snapshot = try await pipeline.execute()

    verifyResults(
      snapshot,
      [
        ["id": 2, "foo": 1, "bar": 1, "baz": 2],
        ["id": 3, "foo": 1, "bar": 1, "baz": 2],
        ["id": 4, "foo": 1, "bar": 2, "baz": 1],
        ["id": 5, "foo": 1, "bar": 2, "baz": 2],
        ["id": 6, "foo": 1, "bar": 2, "baz": 2],
        ["id": 7, "foo": 2, "bar": 1, "baz": 1],
        ["id": 8, "foo": 2, "bar": 1, "baz": 2],
        ["id": 9, "foo": 2, "bar": 1, "baz": 2],
        ["id": 10, "foo": 2, "bar": 2, "baz": 1],
        ["id": 11, "foo": 2, "bar": 2, "baz": 2],
        ["id": 12, "foo": 2, "bar": 2, "baz": 2],
      ],
      enforceOrder: true
    )

    docRef = try await collRef.document("3").getDocument()
    query = collRef.order(by: "foo").order(by: "bar").order(by: "baz").start(atDocument: docRef)
    pipeline = db.pipeline().create(from: query)
    snapshot = try await pipeline.execute()
    verifyResults(
      snapshot,
      [
        ["id": 3, "foo": 1, "bar": 1, "baz": 2],
        ["id": 4, "foo": 1, "bar": 2, "baz": 1],
        ["id": 5, "foo": 1, "bar": 2, "baz": 2],
        ["id": 6, "foo": 1, "bar": 2, "baz": 2],
        ["id": 7, "foo": 2, "bar": 1, "baz": 1],
        ["id": 8, "foo": 2, "bar": 1, "baz": 2],
        ["id": 9, "foo": 2, "bar": 1, "baz": 2],
        ["id": 10, "foo": 2, "bar": 2, "baz": 1],
        ["id": 11, "foo": 2, "bar": 2, "baz": 2],
        ["id": 12, "foo": 2, "bar": 2, "baz": 2],
      ],
      enforceOrder: true
    )
  }

  func testSupportsStartAfter() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1],
      "2": ["foo": 2],
    ])
    let db = collRef.firestore

    let query = collRef.order(by: "foo").start(after: [1])
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 2]], enforceOrder: true)
  }

  func testSupportsEndAt() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1],
      "2": ["foo": 2],
    ])
    let db = collRef.firestore

    let query = collRef.order(by: "foo").end(at: [1])
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 1]], enforceOrder: true)
  }

  func testSupportsEndBefore() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1],
      "2": ["foo": 2],
    ])
    let db = collRef.firestore

    let query = collRef.order(by: "foo").end(before: [2])
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 1]], enforceOrder: true)
  }

  func testSupportsPagination() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1],
      "2": ["foo": 2],
    ])
    let db = collRef.firestore

    var query = collRef.order(by: "foo").limit(to: 1)
    var pipeline = db.pipeline().create(from: query)
    var snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 1]], enforceOrder: true)

    let lastFoo = snapshot.results.first!.get("foo")!
    query = query.start(after: [lastFoo])
    pipeline = db.pipeline().create(from: query)
    snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 2]], enforceOrder: true)
  }

  func testSupportsPaginationOnDocumentIds() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1],
      "2": ["foo": 2],
    ])
    let db = collRef.firestore

    var query = collRef.order(by: "foo").order(by: FieldPath.documentID()).limit(to: 1)
    var pipeline = db.pipeline().create(from: query)
    var snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 1]], enforceOrder: true)

    let lastSnapshot = snapshot.results.first!
    query = query.start(after: [lastSnapshot.get("foo")!, lastSnapshot.ref!.documentID])
    pipeline = db.pipeline().create(from: query)
    snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 2]], enforceOrder: true)
  }

  func testSupportsCollectionGroups() async throws {
    let db = firestore()
    let collRef = collectionRef()
    let collectionGroupId = "\(collRef.collectionID)group"

    let fooDoc = db.document("\(collRef.path)/foo/\(collectionGroupId)/doc1")
    let barDoc = db.document("\(collRef.path)/bar/baz/boo/\(collectionGroupId)/doc2")

    try await fooDoc.setData(["foo": 1])
    try await barDoc.setData(["bar": 1])

    let query = db.collectionGroup(collectionGroupId)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["bar": 1], ["foo": 1]])
  }

  func testSupportsQueryOverCollectionPathWithSpecialCharacters() async throws {
    let collRef = collectionRef()
    let db = collRef.firestore

    let docWithSpecials = collRef.document("so! @#$%^&*()_+special")
    let collectionWithSpecials = docWithSpecials.collection("so! @#$%^&*()_+special")

    try await collectionWithSpecials.addDocument(data: ["foo": 1])
    try await collectionWithSpecials.addDocument(data: ["foo": 2])

    let query = collectionWithSpecials.order(by: "foo", descending: false)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 1], ["foo": 2]], enforceOrder: true)
  }

  func testSupportsMultipleInequalityOnSameField() async throws {
    let collRef = collectionRef(withDocuments: [
      "01": ["id": 1, "foo": 1, "bar": 1, "baz": 1],
      "02": ["id": 2, "foo": 1, "bar": 1, "baz": 2],
      "03": ["id": 3, "foo": 1, "bar": 1, "baz": 2],
      "04": ["id": 4, "foo": 1, "bar": 2, "baz": 1],
      "05": ["id": 5, "foo": 1, "bar": 2, "baz": 2],
      "06": ["id": 6, "foo": 1, "bar": 2, "baz": 2],
      "07": ["id": 7, "foo": 2, "bar": 1, "baz": 1],
      "08": ["id": 8, "foo": 2, "bar": 1, "baz": 2],
      "09": ["id": 9, "foo": 2, "bar": 1, "baz": 2],
      "10": ["id": 10, "foo": 2, "bar": 2, "baz": 1],
      "11": ["id": 11, "foo": 2, "bar": 2, "baz": 2],
      "12": ["id": 12, "foo": 2, "bar": 2, "baz": 2],
    ])
    let db = collRef.firestore

    let query = collRef.whereField("id", isGreaterThan: 2).whereField("id", isLessThanOrEqualTo: 10)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(
      snapshot,
      [
        ["id": 3, "foo": 1, "bar": 1, "baz": 2],
        ["id": 4, "foo": 1, "bar": 2, "baz": 1],
        ["id": 5, "foo": 1, "bar": 2, "baz": 2],
        ["id": 6, "foo": 1, "bar": 2, "baz": 2],
        ["id": 7, "foo": 2, "bar": 1, "baz": 1],
        ["id": 8, "foo": 2, "bar": 1, "baz": 2],
        ["id": 9, "foo": 2, "bar": 1, "baz": 2],
        ["id": 10, "foo": 2, "bar": 2, "baz": 1],
      ],
      enforceOrder: false
    )
  }

  func testSupportsMultipleInequalityOnDifferentFields() async throws {
    let collRef = collectionRef(withDocuments: [
      "01": ["id": 1, "foo": 1, "bar": 1, "baz": 1],
      "02": ["id": 2, "foo": 1, "bar": 1, "baz": 2],
      "03": ["id": 3, "foo": 1, "bar": 1, "baz": 2],
      "04": ["id": 4, "foo": 1, "bar": 2, "baz": 1],
      "05": ["id": 5, "foo": 1, "bar": 2, "baz": 2],
      "06": ["id": 6, "foo": 1, "bar": 2, "baz": 2],
      "07": ["id": 7, "foo": 2, "bar": 1, "baz": 1],
      "08": ["id": 8, "foo": 2, "bar": 1, "baz": 2],
      "09": ["id": 9, "foo": 2, "bar": 1, "baz": 2],
      "10": ["id": 10, "foo": 2, "bar": 2, "baz": 1],
      "11": ["id": 11, "foo": 2, "bar": 2, "baz": 2],
      "12": ["id": 12, "foo": 2, "bar": 2, "baz": 2],
    ])
    let db = collRef.firestore

    let query = collRef.whereField("id", isGreaterThanOrEqualTo: 2)
      .whereField("baz", isLessThan: 2)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(
      snapshot,
      [
        ["id": 4, "foo": 1, "bar": 2, "baz": 1],
        ["id": 7, "foo": 2, "bar": 1, "baz": 1],
        ["id": 10, "foo": 2, "bar": 2, "baz": 1],
      ],
      enforceOrder: false
    )
  }

  func testSupportsCollectionGroupQuery() async throws {
    let collRef = collectionRef(withDocuments: ["1": ["foo": 1]])
    let db = collRef.firestore

    let query = db.collectionGroup(collRef.collectionID)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 1]])
  }

  func testSupportsEqNan() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1, "bar": Double.nan],
      "2": ["foo": 2, "bar": 1],
    ])
    let db = collRef.firestore

    let query = collRef.whereField("bar", isEqualTo: Double.nan)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1)
    let data = snapshot.results.first!.data
    XCTAssertEqual(data["foo"] as? Int, 1)
    XCTAssertTrue((data["bar"] as? Double)?.isNaN ?? false)
  }

  func testSupportsNeqNan() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1, "bar": Double.nan],
      "2": ["foo": 2, "bar": 1],
    ])
    let db = collRef.firestore

    let query = collRef.whereField("bar", isNotEqualTo: Double.nan)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 2, "bar": 1]])
  }

  func testSupportsEqNull() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1, "bar": NSNull()],
      "2": ["foo": 2, "bar": 1],
    ])
    let db = collRef.firestore

    let query = collRef.whereField("bar", isEqualTo: NSNull())
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 1, "bar": nil]])
  }

  func testSupportsNeqNull() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1, "bar": NSNull()],
      "2": ["foo": 2, "bar": 1],
    ])
    let db = collRef.firestore

    let query = collRef.whereField("bar", isNotEqualTo: NSNull())
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 2, "bar": 1]])
  }

  func testSupportsNeq() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1, "bar": 0],
      "2": ["foo": 2, "bar": 1],
    ])
    let db = collRef.firestore

    let query = collRef.whereField("bar", isNotEqualTo: 0)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 2, "bar": 1]])
  }

  func testSupportsArrayContains() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1, "bar": [0, 2, 4, 6]],
      "2": ["foo": 2, "bar": [1, 3, 5, 7]],
    ])
    let db = collRef.firestore

    let query = collRef.whereField("bar", arrayContains: 4)
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 1, "bar": [0, 2, 4, 6]]])
  }

  func testSupportsArrayContainsAny() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1, "bar": [0, 2, 4, 6]],
      "2": ["foo": 2, "bar": [1, 3, 5, 7]],
      "3": ["foo": 3, "bar": [10, 20, 30, 40]],
    ])
    let db = collRef.firestore

    let query = collRef.whereField("bar", arrayContainsAny: [4, 5])
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(
      snapshot,
      [
        ["foo": 1, "bar": [0, 2, 4, 6]],
        ["foo": 2, "bar": [1, 3, 5, 7]],
      ]
    )
  }

  func testSupportsIn() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1, "bar": 2],
      "2": ["foo": 2],
      "3": ["foo": 3, "bar": 10],
    ])
    let db = collRef.firestore

    let query = collRef.whereField("bar", in: [0, 10, 20])
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 3, "bar": 10]])
  }

  func testSupportsInWith1() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1, "bar": 2],
      "2": ["foo": 2],
      "3": ["foo": 3, "bar": 10],
    ])
    let db = collRef.firestore

    let query = collRef.whereField("bar", in: [2])
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 1, "bar": 2]])
  }

  func testSupportsNotIn() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1, "bar": 2],
      "2": ["foo": 2, "bar": 1],
      "3": ["foo": 3, "bar": 10],
    ])
    let db = collRef.firestore

    let query = collRef.whereField("bar", notIn: [0, 10, 20])
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 1, "bar": 2], ["foo": 2, "bar": 1]])
  }

  func testSupportsNotInWith1() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1, "bar": 2],
      "2": ["foo": 2],
      "3": ["foo": 3, "bar": 10],
    ])
    let db = collRef.firestore

    let query = collRef.whereField("bar", notIn: [2])
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(snapshot, [["foo": 3, "bar": 10]])
  }

  func testSupportsOrOperator() async throws {
    let collRef = collectionRef(withDocuments: [
      "1": ["foo": 1, "bar": 2],
      "2": ["foo": 2, "bar": 0],
      "3": ["foo": 3, "bar": 10],
    ])
    let db = collRef.firestore

    let query = collRef.whereFilter(Filter.orFilter([
      Filter.whereField("bar", isEqualTo: 2),
      Filter.whereField("foo", isEqualTo: 3),
    ])).order(by: "foo")
    let pipeline = db.pipeline().create(from: query)
    let snapshot = try await pipeline.execute()

    verifyResults(
      snapshot,
      [
        ["foo": 1, "bar": 2],
        ["foo": 3, "bar": 10],
      ],
      enforceOrder: true
    )
  }
}
