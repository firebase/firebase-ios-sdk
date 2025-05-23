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

private let bookDocs: [String: [String: Any]] = [
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

    let startTime = Date().timeIntervalSince1970

    let pipeline = db.pipeline().collection(collRef.path)
    let snapshot = try await pipeline.execute()

    let endTime = Date().timeIntervalSince1970

    XCTAssertEqual(snapshot.results.count, bookDocs.count, "Should fetch all documents")

    let executionTimeValue = snapshot.executionTime.dateValue().timeIntervalSince1970

    XCTAssertGreaterThanOrEqual(
      executionTimeValue,
      startTime,
      "Execution time should be at or after start time"
    )
    XCTAssertLessThanOrEqual(
      executionTimeValue,
      endTime,
      "Execution time should be at or before end time"
    )
    XCTAssertGreaterThan(executionTimeValue, 0, "Execution time should be positive and not zero")
  }

  func testReturnsExecutionTimeForEmptyQuery() async throws {
    let collRef =
      collectionRef(withDocuments: bookDocs) // Using bookDocs is fine, limit(0) makes it empty
    let db = collRef.firestore

    let startTime = Date().timeIntervalSince1970

    let pipeline = db.pipeline().collection(collRef.path).limit(0)
    let snapshot = try await pipeline.execute()

    let endTime = Date().timeIntervalSince1970

    expectResults(snapshot, expectedCount: 0)

    let executionTimeValue = snapshot.executionTime.dateValue().timeIntervalSince1970
    XCTAssertGreaterThanOrEqual(
      executionTimeValue,
      startTime,
      "Execution time should be at or after start time"
    )
    XCTAssertLessThanOrEqual(
      executionTimeValue,
      endTime,
      "Execution time should be at or before end time"
    )
    XCTAssertGreaterThan(executionTimeValue, 0, "Execution time should be positive and not zero")
  }

  func testReturnsCreateAndUpdateTimeForEachDocument() async throws {
    let beforeInitialExecute = Date().timeIntervalSince1970
    let collRef = collectionRef(withDocuments: bookDocs)
    let afterInitialExecute = Date().timeIntervalSince1970

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

        XCTAssertGreaterThanOrEqual(createTimestamp, beforeInitialExecute,
                                    "Initial createTime for \(String(describing: doc.id)) should be at or after start time")
        XCTAssertLessThanOrEqual(createTimestamp, afterInitialExecute,
                                 "Initial createTime for \(String(describing: doc.id)) should be positive and not zero")
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

    let startTime = Date().timeIntervalSince1970

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .aggregate(Field("rating").avg().as("avgRating"))
    let snapshot = try await pipeline.execute()

    let endTime = Date().timeIntervalSince1970

    XCTAssertEqual(snapshot.results.count, 1, "Aggregate query should return a single result")

    let executionTimeValue = snapshot.executionTime.dateValue().timeIntervalSince1970
    XCTAssertGreaterThanOrEqual(executionTimeValue, startTime)
    XCTAssertLessThanOrEqual(executionTimeValue, endTime)
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
}
