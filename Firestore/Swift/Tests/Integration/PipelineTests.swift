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

import FirebaseCore // For FirebaseApp management
import FirebaseFirestore
import Foundation
import XCTest // For XCTFail, XCTAssertEqual etc.

private let bookDocs: [String: [String: Sendable]] = [
  "book1": [
    "title": "The Hitchhiker's Guide to the Galaxy",
    "author": "Douglas Adams",
    "genre": "Science Fiction",
    "published": 1979,
    "rating": 4.2,
    "tags": ["comedy", "space", "adventure"],
    "awards": ["hugo": true, "nebula": false, "others": ["unknown": ["year": 1980]]], // Corrected
    "nestedField": ["level.1": ["level.2": true]],
    "embedding": VectorValue([10, 1, 1, 1, 1, 1, 1, 1, 1, 1]),
  ],
  "book2": [
    "title": "Pride and Prejudice",
    "author": "Jane Austen",
    "genre": "Romance",
    "published": 1813,
    "rating": 4.5,
    "tags": ["classic", "social commentary", "love"],
    "awards": ["none": true],
    "embedding": VectorValue([1, 10, 1, 1, 1, 1, 1, 1, 1, 1]), // Added
  ],
  "book3": [
    "title": "One Hundred Years of Solitude",
    "author": "Gabriel García Márquez",
    "genre": "Magical Realism",
    "published": 1967,
    "rating": 4.3,
    "tags": ["family", "history", "fantasy"],
    "awards": ["nobel": true, "nebula": false],
    "embedding": VectorValue([1, 1, 10, 1, 1, 1, 1, 1, 1, 1]),
  ],
  "book4": [
    "title": "The Lord of the Rings",
    "author": "J.R.R. Tolkien",
    "genre": "Fantasy",
    "published": 1954,
    "rating": 4.7,
    "tags": ["adventure", "magic", "epic"],
    "awards": ["hugo": false, "nebula": false],
    "remarks": NSNull(), // Added
    "cost": Double.nan, // Added
    "embedding": VectorValue([1, 1, 1, 10, 1, 1, 1, 1, 1, 1]), // Added
  ],
  "book5": [
    "title": "The Handmaid's Tale",
    "author": "Margaret Atwood",
    "genre": "Dystopian",
    "published": 1985,
    "rating": 4.1,
    "tags": ["feminism", "totalitarianism", "resistance"],
    "awards": ["arthur c. clarke": true, "booker prize": false],
    "embedding": VectorValue([1, 1, 1, 1, 10, 1, 1, 1, 1, 1]), // Added
  ],
  "book6": [
    "title": "Crime and Punishment",
    "author": "Fyodor Dostoevsky",
    "genre": "Psychological Thriller",
    "published": 1866,
    "rating": 4.3,
    "tags": ["philosophy", "crime", "redemption"],
    "awards": ["none": true],
    "embedding": VectorValue([1, 1, 1, 1, 1, 10, 1, 1, 1, 1]), // Added
  ],
  "book7": [
    "title": "To Kill a Mockingbird",
    "author": "Harper Lee",
    "genre": "Southern Gothic",
    "published": 1960,
    "rating": 4.2,
    "tags": ["racism", "injustice", "coming-of-age"],
    "awards": ["pulitzer": true],
    "embedding": VectorValue([1, 1, 1, 1, 1, 1, 10, 1, 1, 1]), // Added
  ],
  "book8": [
    "title": "1984",
    "author": "George Orwell",
    "genre": "Dystopian",
    "published": 1949,
    "rating": 4.2,
    "tags": ["surveillance", "totalitarianism", "propaganda"],
    "awards": ["prometheus": true],
    "embedding": VectorValue([1, 1, 1, 1, 1, 1, 1, 10, 1, 1]), // Added
  ],
  "book9": [
    "title": "The Great Gatsby",
    "author": "F. Scott Fitzgerald",
    "genre": "Modernist",
    "published": 1925,
    "rating": 4.0,
    "tags": ["wealth", "american dream", "love"],
    "awards": ["none": true],
    "embedding": VectorValue([1, 1, 1, 1, 1, 1, 1, 1, 10, 1]), // Added
  ],
  "book10": [
    "title": "Dune",
    "author": "Frank Herbert",
    "genre": "Science Fiction",
    "published": 1965,
    "rating": 4.6,
    "tags": ["politics", "desert", "ecology"],
    "awards": ["hugo": true, "nebula": true],
    "embedding": VectorValue([1, 1, 1, 1, 1, 1, 1, 1, 1, 10]), // Added
  ],
]

// A custom function to compare two values of type 'Sendable'
private func areEqual(_ value1: Sendable?, _ value2: Sendable?) -> Bool {
  if value1 == nil || value2 == nil {
    return (value1 == nil || value1 as! NSObject == NSNull()) &&
      (value2 == nil || value2 as! NSObject == NSNull())
  }
  switch (value1!, value2!) {
  case let (v1 as [String: Sendable?], v2 as [String: Sendable?]):
    return areDictionariesEqual(v1, v2)
  case let (v1 as [Sendable?], v2 as [Sendable?]):
    return areArraysEqual(v1, v2)
  case let (v1 as Timestamp, v2 as Timestamp):
    return v1 == v2
  case let (v1 as Date, v2 as Timestamp):
    // Firestore converts Dates to Timestamps
    return Timestamp(date: v1) == v2
  case let (v1 as GeoPoint, v2 as GeoPoint):
    return v1.latitude == v2.latitude && v1.longitude == v2.longitude
  case let (v1 as DocumentReference, v2 as DocumentReference):
    return v1.path == v2.path
  case let (v1 as VectorValue, v2 as VectorValue):
    return v1.array == v2.array
  case let (v1 as Data, v2 as Data):
    return v1 == v2
  case let (v1 as Int, v2 as Int):
    return v1 == v2
  case let (v1 as Double, v2 as Double):
    return v1 == v2
  case let (v1 as Float, v2 as Float):
    return v1 == v2
  case let (v1 as String, v2 as String):
    return v1 == v2
  case let (v1 as Bool, v2 as Bool):
    return v1 == v2
  case let (v1 as UInt8, v2 as UInt8):
    return v1 == v2
  default:
    // Fallback for any other types, might need more specific checks
    return false
  }
}

// A function to compare two dictionaries
private func areDictionariesEqual(_ dict1: [String: Sendable?],
                                  _ dict2: [String: Sendable?]) -> Bool {
  guard dict1.count == dict2.count else { return false }

  for (key, value1) in dict1 {
    guard let value2 = dict2[key], areEqual(value1, value2) else {
      print("The Dictionary value is not equal.")
      print("key1: \(key)")
      print("value1: \(String(describing: value1))")
      print("value2: \(String(describing: dict2[key]))")
      return false
    }
  }
  return true
}

// A function to compare two arrays
private func areArraysEqual(_ array1: [Sendable?], _ array2: [Sendable?]) -> Bool {
  guard array1.count == array2.count else { return false }

  for (index, value1) in array1.enumerated() {
    let value2 = array2[index]
    if !areEqual(value1, value2) {
      print("The Array value is not equal.")
      print("value1: \(String(describing: value1))")
      print("value2: \(String(describing: value2))")
      return false
    }
  }
  return true
}

func expectResults(_ snapshot: PipelineSnapshot,
                   expectedCount: Int,
                   file: StaticString = #file,
                   line: UInt = #line) {
  XCTAssertEqual(
    snapshot.results.count,
    expectedCount,
    "Snapshot results count mismatch",
    file: file,
    line: line
  )
}

func expectResults(_ snapshot: PipelineSnapshot,
                   expectedIDs: [String],
                   file: StaticString = #file,
                   line: UInt = #line) {
  let results = snapshot.results
  XCTAssertEqual(
    results.count,
    expectedIDs.count,
    "Snapshot document IDs count mismatch. Expected \(expectedIDs.count), got \(results.count). Actual IDs: \(results.map { $0.id })",
    file: file,
    line: line
  )

  let actualIDs = results.map { $0.id! }.sorted()
  XCTAssertEqual(
    actualIDs,
    expectedIDs.sorted(),
    "Snapshot document IDs mismatch. Expected (sorted): \(expectedIDs.sorted()), got (sorted): \(actualIDs)",
    file: file,
    line: line
  )
}

func expectResults(result: PipelineResult,
                   expected: [String: Sendable?],
                   file: StaticString = #file,
                   line: UInt = #line) {
  XCTAssertTrue(areDictionariesEqual(result.data, expected),
                "Document data mismatch. Expected \(expected), got \(result.data)")
}

func expectSnapshots(snapshot: PipelineSnapshot,
                     expected: [[String: Sendable?]],
                     file: StaticString = #file,
                     line: UInt = #line) {
  for i in 0 ..< expected.count {
    guard i < snapshot.results.count else {
      XCTFail("Mismatch in expected results count and actual results count.")
      return
    }
    expectResults(result: snapshot.results[i], expected: expected[i])
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class PipelineIntegrationTests: FSTIntegrationTestCase {
  override func setUp() {
    FSTIntegrationTestCase.switchToEnterpriseMode()
    super.setUp()
  }

  func testEmptyResults() async throws {
    let collRef = collectionRef(
      withDocuments: bookDocs
    )
    let db = collRef.firestore

    let snapshot = try await db
      .pipeline()
      .collection(collRef.path)
      .limit(0)
      .execute()

    expectResults(snapshot, expectedCount: 0)
  }

  func testFullResults() async throws {
    let collRef = collectionRef(
      withDocuments: bookDocs
    )
    let db = collRef.firestore

    let snapshot = try await db
      .pipeline()
      .collection(collRef.path)
      .execute()

    // expectResults(snapshot, expectedCount: 10) // This is implicitly checked by expectedIDs
    // version
    expectResults(
      snapshot,
      expectedIDs: [
        "book1", "book10", "book2", "book3", "book4",
        "book5", "book6", "book7", "book8", "book9",
      ]
    )
  }

  func testReturnsExecutionTime() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline().collection(collRef.path)
    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, bookDocs.count, "Should fetch all documents")

    let executionTimeValue = snapshot.executionTime.dateValue().timeIntervalSince1970

    XCTAssertGreaterThan(executionTimeValue, 0, "Execution time should be positive and not zero")
  }

  func testReturnsExecutionTimeForEmptyQuery() async throws {
    let collRef =
      collectionRef(withDocuments: bookDocs) // Using bookDocs is fine, limit(0) makes it empty
    let db = collRef.firestore

    let pipeline = db.pipeline().collection(collRef.path).limit(0)
    let snapshot = try await pipeline.execute()

    expectResults(snapshot, expectedCount: 0)

    let executionTimeValue = snapshot.executionTime.dateValue().timeIntervalSince1970
    XCTAssertGreaterThan(executionTimeValue, 0, "Execution time should be positive and not zero")
  }

  func testReturnsCreateAndUpdateTimeForEachDocument() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore
    let pipeline = db.pipeline().collection(collRef.path)
    var snapshot = try await pipeline.execute()

    XCTAssertEqual(
      snapshot.results.count,
      bookDocs.count,
      "Initial fetch should return all documents"
    )
    for doc in snapshot.results {
      XCTAssertNotNil(
        doc.createTime,
        "Document \(String(describing: doc.id)) should have createTime"
      )
      XCTAssertNotNil(
        doc.updateTime,
        "Document \(String(describing: doc.id)) should have updateTime"
      )
      if let createTime = doc.createTime, let updateTime = doc.updateTime {
        let createTimestamp = createTime.dateValue().timeIntervalSince1970
        let updateTimestamp = updateTime.dateValue().timeIntervalSince1970

        XCTAssertEqual(createTimestamp,
                       updateTimestamp,
                       "Initial createTime and updateTime should be equal for \(String(describing: doc.id))")
      }
    }

    // Update documents
    let batch = db.batch()
    for doc in snapshot.results {
      batch
        .updateData(
          ["newField": "value"],
          forDocument: doc.ref!
        )
    }

    try await batch.commit()

    snapshot = try await pipeline.execute()
    XCTAssertEqual(
      snapshot.results.count,
      bookDocs.count,
      "Fetch after update should return all documents"
    )

    for doc in snapshot.results {
      XCTAssertNotNil(
        doc.createTime,
        "Document \(String(describing: doc.id)) should still have createTime after update"
      )
      XCTAssertNotNil(
        doc.updateTime,
        "Document \(String(describing: doc.id)) should still have updateTime after update"
      )
      if let createTime = doc.createTime, let updateTime = doc.updateTime {
        let createTimestamp = createTime.dateValue().timeIntervalSince1970
        let updateTimestamp = updateTime.dateValue().timeIntervalSince1970

        XCTAssertLessThan(createTimestamp,
                          updateTimestamp,
                          "updateTime (\(updateTimestamp)) should be after createTime (\(createTimestamp)) for \(String(describing: doc.id))")
      }
    }
  }

  func testReturnsExecutionTimeForAggregateQuery() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .aggregate(Field("rating").avg().as("avgRating"))
    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Aggregate query should return a single result")

    let executionTimeValue = snapshot.executionTime.dateValue().timeIntervalSince1970
    XCTAssertGreaterThan(executionTimeValue, 0, "Execution time should be positive")
  }

  func testTimestampsAreNilForAggregateQueryResults() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .aggregate(
        [Field("rating").avg().as("avgRating")],
        groups: ["genre"]
      ) // Make sure 'groupBy' and 'average' are correct
    let snapshot = try await pipeline.execute()

    // There are 8 unique genres in bookDocs
    XCTAssertEqual(snapshot.results.count, 8, "Should return one result per genre")

    for doc in snapshot.results {
      XCTAssertNil(
        doc.createTime,
        "createTime should be nil for aggregate result (docID: \(String(describing: doc.id)), data: \(doc.data))"
      )
      XCTAssertNil(
        doc.updateTime,
        "updateTime should be nil for aggregate result (docID: \(String(describing: doc.id)), data: \(doc.data))"
      )
    }
  }

  func testSupportsCollectionReferenceAsSource() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline().collection(collRef)
    let snapshot = try await pipeline.execute()

    expectResults(snapshot, expectedCount: bookDocs.count)
  }

  func testSupportsListOfDocumentReferencesAsSource() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let docRefs: [DocumentReference] = [
      collRef.document("book1"),
      collRef.document("book2"),
      collRef.document("book3"),
    ]
    let pipeline = db.pipeline().documents(docRefs)
    let snapshot = try await pipeline.execute()

    expectResults(snapshot, expectedIDs: ["book1", "book2", "book3"])
  }

  func testSupportsListOfDocumentPathsAsSource() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let docPaths: [String] = [
      collRef.document("book1").path,
      collRef.document("book2").path,
      collRef.document("book3").path,
    ]
    let pipeline = db.pipeline().documents(docPaths)
    let snapshot = try await pipeline.execute()

    expectResults(snapshot, expectedIDs: ["book1", "book2", "book3"])
  }

  func testRejectsCollectionReferenceFromAnotherDB() async throws {
    let db1 = firestore() // Primary DB

    let db2 = Firestore.firestore(app: db1.app, database: "db2")

    let collRefDb2 = db2.collection("foo")

    XCTAssertTrue(FSTNSExceptionUtil.testForException({
      _ = db1.pipeline().collection(collRefDb2)
    }, reasonContains: "Invalid CollectionReference"))
  }

  func testRejectsDocumentReferenceFromAnotherDB() async throws {
    let db1 = firestore() // Primary DB

    let db2 = Firestore.firestore(app: db1.app, database: "db2")

    let docRefDb2 = db2.collection("foo").document("bar")

    XCTAssertTrue(FSTNSExceptionUtil.testForException({
      _ = db1.pipeline().documents([docRefDb2])
    }, reasonContains: "Invalid DocumentReference"))
  }

  func testSupportsCollectionGroupAsSource() async throws {
    let db = firestore()

    let rootCollForTest = collectionRef()

    let randomSubCollectionId = String(UUID().uuidString.prefix(8))

    // Create parent documents first to ensure they exist before creating subcollections.
    let doc1Ref = rootCollForTest.document("book1").collection(randomSubCollectionId)
      .document("translation")
    try await doc1Ref.setData(["order": 1])

    let doc2Ref = rootCollForTest.document("book2").collection(randomSubCollectionId)
      .document("translation")
    try await doc2Ref.setData(["order": 2])

    let pipeline = db.pipeline()
      .collectionGroup(randomSubCollectionId)
      .sort(Field("order").ascending())

    let snapshot = try await pipeline.execute()

    // Assert that only the two documents from the targeted subCollectionId are fetched, in the
    // correct order.
    expectResults(snapshot, expectedIDs: [doc1Ref.documentID, doc2Ref.documentID])
  }

  func testSupportsDatabaseAsSource() async throws {
    let db = firestore()
    let testRootCol = collectionRef() // Provides a unique root path for this test

    let randomIDValue = UUID().uuidString.prefix(8)

    // Document 1
    let collADocRef = testRootCol.document("docA") // Using specific IDs for clarity in debugging
    try await collADocRef.setData(["order": 1, "randomId": randomIDValue, "name": "DocInCollA"])

    // Document 2
    let collBDocRef = testRootCol.document("docB") // Using specific IDs for clarity in debugging
    try await collBDocRef.setData(["order": 2, "randomId": randomIDValue, "name": "DocInCollB"])

    // Document 3 (control, should not be fetched by the main query due to different randomId)
    let collCDocRef = testRootCol.document("docC")
    try await collCDocRef.setData([
      "order": 3,
      "randomId": "\(UUID().uuidString)",
      "name": "DocInCollC",
    ])

    // Document 4 (control, no randomId, should not be fetched)
    let collDDocRef = testRootCol.document("docD")
    try await collDDocRef.setData(["order": 4, "name": "DocInCollDNoRandomId"])

    // Document 5 (control, correct randomId but in a sub-sub-collection to test depth)
    // This also helps ensure the database() query scans deeply.
    let subSubCollDocRef = testRootCol.document("parentForSubSub").collection("subSubColl")
      .document("docE")
    try await subSubCollDocRef.setData([
      "order": 0,
      "randomId": randomIDValue,
      "name": "DocInSubSubColl",
    ])

    let pipeline = db.pipeline()
      .database() // Source is the entire database
      .where(Field("randomId").eq(randomIDValue))
      .sort(Ascending("order"))
    let snapshot = try await pipeline.execute()

    // We expect 3 documents: docA, docB, and docE (from sub-sub-collection)
    XCTAssertEqual(
      snapshot.results.count,
      3,
      "Should fetch the three documents with the correct randomId"
    )
    // Order should be docE (order 0), docA (order 1), docB (order 2)
    expectResults(
      snapshot,
      expectedIDs: [subSubCollDocRef.documentID, collADocRef.documentID, collBDocRef.documentID]
    )
  }

  func testAcceptsAndReturnsAllSupportedDataTypes() async throws {
    let db = firestore()
    let randomCol = collectionRef() // Ensure a unique collection for the test

    // Add a dummy document to the collection.
    // A pipeline query with .select against an empty collection might not behave as expected.
    try await randomCol.document("dummyDoc").setData(["field": "value"])

    let refDate = Date(timeIntervalSince1970: 1_678_886_400)
    let refTimestamp = Timestamp(date: refDate)

    let constantsFirst: [Selectable] = [
      Constant(1).as("number"),
      Constant("a string").as("string"),
      Constant(true).as("boolean"),
      Constant.nil.as("nil"),
      Constant(GeoPoint(latitude: 0.1, longitude: 0.2)).as("geoPoint"),
      Constant(refTimestamp).as("timestamp"),
      Constant(refDate).as("date"), // Firestore will convert this to a Timestamp
      Constant([1, 2, 3, 4, 5, 6, 7, 0] as [UInt8]).as("bytes"),
      Constant(db.document("foo/bar")).as("documentReference"),
      Constant(VectorValue([1, 2, 3])).as("vectorValue"),
      Constant([1, 2, 3]).as("arrayValue"), // Treated as an array of numbers
    ]

    let constantsSecond: [Selectable] = [
      MapExpression([
        "number": 1,
        "string": "a string",
        "boolean": true,
        "nil": Constant.nil,
        "geoPoint": GeoPoint(latitude: 0.1, longitude: 0.2),
        "timestamp": refTimestamp,
        "date": refDate,
        "uint8Array": Data([1, 2, 3, 4, 5, 6, 7, 0]),
        "documentReference": Constant(db.document("foo/bar")),
        "vectorValue": VectorValue([1, 2, 3]),
        "map": [
          "number": 2,
          "string": "b string",
        ],
        "array": [1, "c string"],
      ]).as("map"),
      ArrayExpression([
        1000,
        "another string",
        false,
        Constant.nil,
        GeoPoint(latitude: 10.1, longitude: 20.2),
        Timestamp(date: Date(timeIntervalSince1970: 1_700_000_000)), // Different timestamp
        Date(timeIntervalSince1970: 1_700_000_000), // Different date
        [11, 22, 33] as [UInt8],
        db.document("another/doc"),
        VectorValue([7, 8, 9]),
        [
          "nestedInArrayMapKey": "value",
          "anotherNestedKey": refTimestamp,
        ],
        [2000, "deep nested array string"],
      ]).as("array"),
    ]

    let expectedResultsMap: [String: Sendable?] = [
      "number": 1,
      "string": "a string",
      "boolean": true,
      "nil": nil,
      "geoPoint": GeoPoint(latitude: 0.1, longitude: 0.2),
      "timestamp": refTimestamp,
      "date": refTimestamp, // Dates are converted to Timestamps
      "bytes": [1, 2, 3, 4, 5, 6, 7, 0] as [UInt8],
      "documentReference": db.document("foo/bar"),
      "vectorValue": VectorValue([1, 2, 3]),
      "arrayValue": [1, 2, 3],
      "map": [
        "number": 1,
        "string": "a string",
        "boolean": true,
        "nil": nil,
        "geoPoint": GeoPoint(latitude: 0.1, longitude: 0.2),
        "timestamp": refTimestamp,
        "date": refTimestamp,
        "uint8Array": Data([1, 2, 3, 4, 5, 6, 7, 0]),
        "documentReference": db.document("foo/bar"),
        "vectorValue": VectorValue([1, 2, 3]),
        "map": [
          "number": 2,
          "string": "b string",
        ],
        "array": [1, "c string"],
      ],
      "array": [
        1000,
        "another string",
        false,
        nil,
        GeoPoint(latitude: 10.1, longitude: 20.2),
        Timestamp(date: Date(timeIntervalSince1970: 1_700_000_000)),
        Timestamp(date: Date(timeIntervalSince1970: 1_700_000_000)), // Dates are converted
        [11, 22, 33] as [UInt8],
        db.document("another/doc"),
        VectorValue([7, 8, 9]),
        [
          "nestedInArrayMapKey": "value",
          "anotherNestedKey": refTimestamp,
        ],
        [2000, "deep nested array string"],
      ],
    ]

    let pipeline = db.pipeline()
      .collection(randomCol.path)
      .limit(1)
      .select(
        constantsFirst + constantsSecond
      )
    let snapshot = try await pipeline.execute()

    expectResults(result: snapshot.results[0], expected: expectedResultsMap)
  }

  func testAcceptsAndReturnsNil() async throws {
    let db = firestore()
    let randomCol = collectionRef() // Ensure a unique collection for the test

    // Add a dummy document to the collection.
    // A pipeline query with .select against an empty collection might not behave as expected.
    try await randomCol.document("dummyDoc").setData(["field": "value"])

    let refDate = Date(timeIntervalSince1970: 1_678_886_400)
    let refTimestamp = Timestamp(date: refDate)

    let constantsFirst: [Selectable] = [
      Constant.nil.as("nil"),
    ]

    let expectedResultsMap: [String: Sendable?] = [
      "nil": nil,
    ]

    let pipeline = db.pipeline()
      .collection(randomCol.path)
      .limit(1)
      .select(
        constantsFirst
      )
    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1)
    expectResults(result: snapshot.results.first!, expected: expectedResultsMap)
  }

  func testConvertsArraysAndPlainObjectsToFunctionValues() async throws {
    let collRef = collectionRef(withDocuments: bookDocs) // Uses existing bookDocs
    let db = collRef.firestore

    // Expected data for "The Lord of the Rings"
    let expectedTitle = "The Lord of the Rings"
    let expectedAuthor = "J.R.R. Tolkien"
    let expectedGenre = "Fantasy"
    let expectedPublished = 1954
    let expectedRating = 4.7
    let expectedTags = ["adventure", "magic", "epic"]
    let expectedAwards: [String: Sendable] = ["hugo": false, "nebula": false]

    let metadataArrayElements: [Sendable] = [
      1,
      2,
      expectedGenre,
      expectedRating * 10,
      [expectedTitle],
      ["published": expectedPublished],
    ]

    let metadataMapElements: [String: Sendable] = [
      "genre": expectedGenre,
      "rating": expectedRating * 10,
      "nestedArray": [expectedTitle],
      "nestedMap": ["published": expectedPublished],
    ]

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort(Field("rating").descending())
      .limit(1) // This should pick "The Lord of the Rings" (rating 4.7)
      .select(
        Field("title"),
        Field("author"),
        Field("genre"),
        Field("rating"),
        Field("published"),
        Field("tags"),
        Field("awards")
      )
      .addFields(
        ArrayExpression([
          1,
          2,
          Field("genre"),
          Field("rating").multiply(10),
          ArrayExpression([Field("title")]),
          MapExpression(["published": Field("published")]),
        ]).as("metadataArray"),
        MapExpression([
          "genre": Field("genre"),
          "rating": Field("rating").multiply(10),
          "nestedArray": ArrayExpression([Field("title")]),
          "nestedMap": MapExpression(["published": Field("published")]),
        ]).as("metadata")
      )
      .where(
        Field("metadataArray").eq(metadataArrayElements) &&
          Field("metadata").eq(metadataMapElements)
      )

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")

    if let resultDoc = snapshot.results.first {
      let expectedFullDoc: [String: Sendable?] = [
        "title": expectedTitle,
        "author": expectedAuthor,
        "genre": expectedGenre,
        "published": expectedPublished,
        "rating": expectedRating,
        "tags": expectedTags,
        "awards": expectedAwards,
        "metadataArray": metadataArrayElements,
        "metadata": metadataMapElements,
      ]
      XCTAssertTrue(
        areDictionariesEqual(resultDoc.data, expectedFullDoc as [String: Sendable]),
        "Document data does not match expected."
      )
    } else {
      XCTFail("No document retrieved")
    }
  }

  func testSupportsAggregate() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    var pipeline = db.pipeline()
      .collection(collRef.path)
      .aggregate(CountAll().as("count"))
    var snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Count all should return a single aggregate document")
    if let result = snapshot.results.first {
      expectResults(result: result, expected: ["count": bookDocs.count])
    } else {
      XCTFail("No result for count all aggregation")
    }

    pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("genre").eq("Science Fiction"))
      .aggregate(
        CountAll().as("count"),
        Field("rating").avg().as("avgRating"),
        Field("rating").maximum().as("maxRating")
      )
    snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Filtered aggregate should return a single document")
    if let result = snapshot.results.first {
      let expectedAggValues: [String: Sendable] = [
        "count": 2,
        "avgRating": 4.4,
        "maxRating": 4.6,
      ]
      expectResults(result: result, expected: expectedAggValues)
    } else {
      XCTFail("No result for filtered aggregation")
    }
  }

  func testRejectsGroupsWithoutAccumulators() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let dummyDocRef = collRef.document("dummyDocForRejectTest")
    try await dummyDocRef.setData(["field": "value"])

    do {
      _ = try await db.pipeline()
        .collection(collRef.path)
        .where(Field("published").lt(1900))
        .aggregate([], groups: ["genre"])
        .execute()

      XCTFail(
        "The pipeline should have thrown an error for groups without accumulators, but it did not."
      )

    } catch {
      XCTAssert(true, "Successfully caught expected error for groups without accumulators.")
    }
  }

  func testReturnsGroupAndAccumulateResults() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("published").lt(1984))
      .aggregate(
        [Field("rating").avg().as("avgRating")],
        groups: ["genre"]
      )
      .where(Field("avgRating").gt(4.3))
      .sort(Field("avgRating").descending())

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(
      snapshot.results.count,
      3,
      "Should return 3 documents after grouping and filtering."
    )

    let expectedResultsArray: [[String: Sendable]] = [
      ["avgRating": 4.7, "genre": "Fantasy"],
      ["avgRating": 4.5, "genre": "Romance"],
      ["avgRating": 4.4, "genre": "Science Fiction"],
    ]

    expectSnapshots(snapshot: snapshot, expected: expectedResultsArray)
  }

  func testReturnsMinMaxCountAndCountAllAccumulations() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .aggregate(
        Field("cost").count().as("booksWithCost"),
        CountAll().as("count"),
        Field("rating").maximum().as("maxRating"),
        Field("published").minimum().as("minPublished")
      )

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Aggregate should return a single document")

    let expectedValues: [String: Sendable] = [
      "booksWithCost": 1,
      "count": bookDocs.count,
      "maxRating": 4.7,
      "minPublished": 1813,
    ]

    if let result = snapshot.results.first {
      expectResults(result: result, expected: expectedValues)
    } else {
      XCTFail("No result for min/max/count/countAll aggregation")
    }
  }

  func testReturnsCountIfAccumulation() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let expectedCount = 3
    let expectedResults: [String: Sendable] = ["count": expectedCount]
    let condition = Field("rating").gt(4.3)

    var pipeline = db.pipeline()
      .collection(collRef.path)
      .aggregate(condition.countIf().as("count"))
    var snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "countIf aggregate should return a single document")
    if let result = snapshot.results.first {
      expectResults(result: result, expected: expectedResults)
    } else {
      XCTFail("No result for countIf aggregation")
    }
  }

  func testDistinctStage() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .distinct(Field("genre"), Field("author"))
      .sort(Field("genre").ascending(), Field("author").ascending())

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["genre": "Dystopian", "author": "George Orwell"],
      ["genre": "Dystopian", "author": "Margaret Atwood"],
      ["genre": "Fantasy", "author": "J.R.R. Tolkien"],
      ["genre": "Magical Realism", "author": "Gabriel García Márquez"],
      ["genre": "Modernist", "author": "F. Scott Fitzgerald"],
      ["genre": "Psychological Thriller", "author": "Fyodor Dostoevsky"],
      ["genre": "Romance", "author": "Jane Austen"],
      ["genre": "Science Fiction", "author": "Douglas Adams"],
      ["genre": "Science Fiction", "author": "Frank Herbert"],
      ["genre": "Southern Gothic", "author": "Harper Lee"],
    ]

    XCTAssertEqual(snapshot.results.count, expectedResults.count, "Snapshot results count mismatch")

    expectSnapshots(snapshot: snapshot, expected: expectedResults)
  }

  func testSelectStage() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select(Field("title"), Field("author"))
      .sort(Field("author").ascending())

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy", "author": "Douglas Adams"],
      ["title": "The Great Gatsby", "author": "F. Scott Fitzgerald"],
      ["title": "Dune", "author": "Frank Herbert"],
      ["title": "Crime and Punishment", "author": "Fyodor Dostoevsky"],
      ["title": "One Hundred Years of Solitude", "author": "Gabriel García Márquez"],
      ["title": "1984", "author": "George Orwell"],
      ["title": "To Kill a Mockingbird", "author": "Harper Lee"],
      ["title": "The Lord of the Rings", "author": "J.R.R. Tolkien"],
      ["title": "Pride and Prejudice", "author": "Jane Austen"],
      ["title": "The Handmaid's Tale", "author": "Margaret Atwood"],
    ]

    XCTAssertEqual(
      snapshot.results.count,
      expectedResults.count,
      "Snapshot results count mismatch for select stage."
    )

    expectSnapshots(snapshot: snapshot, expected: expectedResults)
  }

  func testAddFieldStage() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select(Field("title"), Field("author"))
      .addFields(Constant("bar").as("foo"))
      .sort(Field("author").ascending())

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy", "author": "Douglas Adams", "foo": "bar"],
      ["title": "The Great Gatsby", "author": "F. Scott Fitzgerald", "foo": "bar"],
      ["title": "Dune", "author": "Frank Herbert", "foo": "bar"],
      ["title": "Crime and Punishment", "author": "Fyodor Dostoevsky", "foo": "bar"],
      ["title": "One Hundred Years of Solitude", "author": "Gabriel García Márquez", "foo": "bar"],
      ["title": "1984", "author": "George Orwell", "foo": "bar"],
      ["title": "To Kill a Mockingbird", "author": "Harper Lee", "foo": "bar"],
      ["title": "The Lord of the Rings", "author": "J.R.R. Tolkien", "foo": "bar"],
      ["title": "Pride and Prejudice", "author": "Jane Austen", "foo": "bar"],
      ["title": "The Handmaid's Tale", "author": "Margaret Atwood", "foo": "bar"],
    ]

    XCTAssertEqual(
      snapshot.results.count,
      expectedResults.count,
      "Snapshot results count mismatch for addField stage."
    )

    expectSnapshots(snapshot: snapshot, expected: expectedResults)
  }

  func testRemoveFieldsStage() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select(Field("title"), Field("author"))
      .sort(Field("author").ascending()) // Sort before removing the 'author' field
      .removeFields(Field("author"))

    let snapshot = try await pipeline.execute()

    // Expected results are sorted by author, but only contain the title
    let expectedResults: [[String: Sendable]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy"], // Douglas Adams
      ["title": "The Great Gatsby"], // F. Scott Fitzgerald
      ["title": "Dune"], // Frank Herbert
      ["title": "Crime and Punishment"], // Fyodor Dostoevsky
      ["title": "One Hundred Years of Solitude"], // Gabriel García Márquez
      ["title": "1984"], // George Orwell
      ["title": "To Kill a Mockingbird"], // Harper Lee
      ["title": "The Lord of the Rings"], // J.R.R. Tolkien
      ["title": "Pride and Prejudice"], // Jane Austen
      ["title": "The Handmaid's Tale"], // Margaret Atwood
    ]

    XCTAssertEqual(
      snapshot.results.count,
      expectedResults.count,
      "Snapshot results count mismatch for removeFields stage."
    )

    expectSnapshots(snapshot: snapshot, expected: expectedResults)
  }

  func testWhereStageWithAndConditions() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    // Test Case 1: Two AND conditions
    var pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("rating").gt(4.5)
        && Field("genre").eqAny(["Science Fiction", "Romance", "Fantasy"]))
    var snapshot = try await pipeline.execute()
    var expectedIDs = ["book10", "book4"] // Dune (SF, 4.6), LOTR (Fantasy, 4.7)
    expectResults(snapshot, expectedIDs: expectedIDs)

    // Test Case 2: Three AND conditions
    pipeline = db.pipeline()
      .collection(collRef.path)
      .where(
        Field("rating").gt(4.5)
          && Field("genre").eqAny(["Science Fiction", "Romance", "Fantasy"])
          && Field("published").lt(1965)
      )
    snapshot = try await pipeline.execute()
    expectedIDs = ["book4"] // LOTR (Fantasy, 4.7, published 1954)
    expectResults(snapshot, expectedIDs: expectedIDs)
  }

  func testWhereStageWithOrAndXorConditions() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    // Test Case 1: OR conditions
    var pipeline = db.pipeline()
      .collection(collRef.path)
      .where(
        Field("genre").eq("Romance")
          || Field("genre").eq("Dystopian")
          || Field("genre").eq("Fantasy")
      )
      .select(Field("title"))
      .sort(Field("title").ascending())

    var snapshot = try await pipeline.execute()
    var expectedResults: [[String: Sendable]] = [
      ["title": "1984"], // Dystopian
      ["title": "Pride and Prejudice"], // Romance
      ["title": "The Handmaid's Tale"], // Dystopian
      ["title": "The Lord of the Rings"], // Fantasy
    ]

    XCTAssertEqual(
      snapshot.results.count,
      expectedResults.count,
      "Snapshot results count mismatch for OR conditions."
    )
    expectSnapshots(snapshot: snapshot, expected: expectedResults)

    // Test Case 2: XOR conditions
    // XOR is true if an odd number of its arguments are true.
    pipeline = db.pipeline()
      .collection(collRef.path)
      .where(
        Field("genre").eq("Romance") // Book2 (T), Book5 (F), Book4 (F), Book8 (F)
          ^ Field("genre").eq("Dystopian") // Book2 (F), Book5 (T), Book4 (F), Book8 (T)
          ^ Field("genre").eq("Fantasy") // Book2 (F), Book5 (F), Book4 (T), Book8 (F)
          ^ Field("published").eq(1949) // Book2 (F), Book5 (F), Book4 (F), Book8 (T)
      )
      .select(Field("title"))
      .sort(Field("title").ascending())

    snapshot = try await pipeline.execute()

    expectedResults = [
      ["title": "Pride and Prejudice"],
      ["title": "The Handmaid's Tale"],
      ["title": "The Lord of the Rings"],
    ]

    XCTAssertEqual(
      snapshot.results.count,
      expectedResults.count,
      "Snapshot results count mismatch for XOR conditions."
    )
    expectSnapshots(snapshot: snapshot, expected: expectedResults)
  }

  func testSortOffsetAndLimitStages() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort(Field("author").ascending())
      .offset(5)
      .limit(3)
      .select("title", "author")

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "1984", "author": "George Orwell"],
      ["title": "To Kill a Mockingbird", "author": "Harper Lee"],
      ["title": "The Lord of the Rings", "author": "J.R.R. Tolkien"],
    ]
    expectSnapshots(snapshot: snapshot, expected: expectedResults)
  }

  // MARK: - Generic Stage Tests

  func testRawStageSelectFields() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    // Expected book: book2 (Pride and Prejudice, Jane Austen, 1813)
    // It's the earliest published book.
    let expectedSelectedData: [String: Sendable] = [
      "title": "Pride and Prejudice",
      // "metadata": ["author": "Douglas Adams"]
    ]

    // The parameters for rawStage("select", ...) are an array containing a single dictionary.
    // The keys of this dictionary are the output field names, and the values are Field objects.
    let selectParameters: [[String: Sendable]] =
      [
        // Field("title").as("title")
        ["title": Field("author")],
      ]

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort(Field("published").ascending())
      .limit(1)
      .rawStage(name: "select", params: selectParameters) // Using rawStage for selection

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")
    expectSnapshots(snapshot: snapshot, expected: [expectedSelectedData])
  }

  // TODO:

  // MARK: - Replace Stage Test

  func testReplaceStagePromoteAwardsAndAddFlag() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").eq("The Hitchhiker's Guide to the Galaxy"))
      .replace(with: "awards")

    let snapshot = try await pipeline.execute()

    expectResults(snapshot, expectedCount: 1)

    let expectedBook1Transformed: [String: Sendable?] = [
      "hugo": true,
      "nebula": false,
      "others": ["unknown": ["year": 1980]],
    ]

    // Need to use nullable Sendable for comparison because 'others' is nested
    // and the areEqual function handles Sendable?
    expectSnapshots(snapshot: snapshot, expected: [expectedBook1Transformed])
  }

  // MARK: - Sample Stage Tests

  func testSampleStageLimit3() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort(DocumentId().ascending()) // Sort for predictable results
      .limit(3) // Simulate sampling 3 documents

    let snapshot = try await pipeline.execute()

    expectResults(snapshot, expectedCount: 3)

    // Based on documentID ascending sort of bookDocs keys:
    // book1, book10, book2, book3, ...
    let expectedIDs = ["book1", "book10", "book2"]
    expectResults(snapshot, expectedIDs: expectedIDs)
  }

  func testSampleStageLimitDocuments3() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort(DocumentId().ascending()) // Sort for predictable results
      .limit(3) // Simulate sampling {documents: 3}

    let snapshot = try await pipeline.execute()

    expectResults(snapshot, expectedCount: 3)

    // Based on documentID ascending sort of bookDocs keys:
    // book1, book10, book2, book3, ...
    let expectedIDs = ["book1", "book10", "book2"]
    expectResults(snapshot, expectedIDs: expectedIDs)
  }

  func testSampleStageLimitPercentage60() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let totalDocs = bookDocs.count
    let percentage = 0.6
    let limitCount = Int(Double(totalDocs) * percentage) // 10 * 0.6 = 6

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort(DocumentId().ascending()) // Sort for predictable results
      .limit(Int32(limitCount)) // Simulate sampling {percentage: 0.6}

    let snapshot = try await pipeline.execute()

    expectResults(snapshot, expectedCount: limitCount) // Should be 6

    // Based on documentID ascending sort of bookDocs keys:
    // book1, book10, book2, book3, book4, book5, book6, book7, book8, book9
    let expectedIDs = ["book1", "book10", "book2", "book3", "book4", "book5"]
    expectResults(snapshot, expectedIDs: expectedIDs)
  }

  // MARK: - Union Stage Test

  func testUnionStageCombineAuthors() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .union(db.pipeline()
        .collection(collRef.path))

    let snapshot = try await pipeline.execute()

    let bookSequence = (1 ... 10).map { "book\($0)" }
    let repeatedIDs = bookSequence + bookSequence
    expectResults(snapshot, expectedIDs: repeatedIDs)
  }
}
