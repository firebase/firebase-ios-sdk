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

import FirebaseCore
import FirebaseFirestore
import Foundation
import XCTest

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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class PipelineIntegrationTests: FSTIntegrationTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()

    if FSTIntegrationTestCase.backendEdition() == .standard {
      throw XCTSkip(
        "Skipping all tests in PipelineIntegrationTests because backend edition is Standard."
      )
    }
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

    TestHelper.compare(snapshot: snapshot, expectedCount: 0)
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

    TestHelper.compare(snapshot: snapshot, expectedIDs: [
      "book1", "book10", "book2", "book3", "book4",
      "book5", "book6", "book7", "book8", "book9",
    ], enforceOrder: false)
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
      collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline().collection(collRef.path).limit(0)
    let snapshot = try await pipeline.execute()

    TestHelper.compare(snapshot: snapshot, expectedCount: 0)

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
      .aggregate([Field("rating").average().as("avgRating")])
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
        [Field("rating").average().as("avgRating")],
        groups: [Field("genre")]
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

    TestHelper.compare(snapshot: snapshot, expectedCount: bookDocs.count)
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

    TestHelper
      .compare(
        snapshot: snapshot,
        expectedIDs: ["book1", "book2", "book3"],
        enforceOrder: false
      )
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

    TestHelper
      .compare(
        snapshot: snapshot,
        expectedIDs: ["book1", "book2", "book3"],
        enforceOrder: false
      )
  }

  func testRejectsCollectionReferenceFromAnotherDB() async throws {
    let db1 = firestore()

    let db2 = Firestore.firestore(app: db1.app, database: "db2")

    let collRefDb2 = db2.collection("foo")

    XCTAssertTrue(FSTNSExceptionUtil.testForException({
      _ = db1.pipeline().collection(collRefDb2)
    }, reasonContains: "Invalid CollectionReference"))
  }

  func testRejectsDocumentReferenceFromAnotherDB() async throws {
    let db1 = firestore()

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
      .sort([Field("order").ascending()])

    let snapshot = try await pipeline.execute()

    // Assert that only the two documents from the targeted subCollectionId are fetched, in the
    // correct order.
    TestHelper
      .compare(
        snapshot: snapshot,
        expectedIDs: [doc1Ref.documentID, doc2Ref.documentID],
        enforceOrder: true
      )
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
      .where(Field("randomId").equal(randomIDValue))
      .sort([Field("order").ascending()])
    let snapshot = try await pipeline.execute()

    // We expect 3 documents: docA, docB, and docE (from sub-sub-collection)
    XCTAssertEqual(
      snapshot.results.count,
      3,
      "Should fetch the three documents with the correct randomId"
    )
    // Order should be docE (order 0), docA (order 1), docB (order 2)
    TestHelper
      .compare(
        snapshot: snapshot,
        expectedIDs: [subSubCollDocRef.documentID, collADocRef.documentID, collBDocRef.documentID],
        enforceOrder: true
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
      Constant(Data([1, 2, 3, 4, 5, 6, 7, 0])).as("bytes"),
      Constant(db.document("foo/bar")).as("documentReference"),
      Constant(VectorValue([1, 2, 3])).as("vectorValue"),
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
        "bytesArray": Data([1, 2, 3, 4, 5, 6, 7, 0]),
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
        Data([11, 22, 33]),
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
      "bytes": Data([1, 2, 3, 4, 5, 6, 7, 0]),
      "documentReference": db.document("foo/bar"),
      "vectorValue": VectorValue([1, 2, 3]),
      "map": [
        "number": 1,
        "string": "a string",
        "boolean": true,
        "nil": nil,
        "geoPoint": GeoPoint(latitude: 0.1, longitude: 0.2),
        "timestamp": refTimestamp,
        "date": refTimestamp,
        "bytesArray": Data([1, 2, 3, 4, 5, 6, 7, 0]),
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
        Data([11, 22, 33]),
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

    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: expectedResultsMap)
  }

  func testAcceptsAndReturnsNil() async throws {
    let db = firestore()
    let randomCol = collectionRef() // Ensure a unique collection for the test

    // Add a dummy document to the collection.
    // A pipeline query with .select against an empty collection might not behave as expected.
    try await randomCol.document("dummyDoc").setData(["field": "value"])

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
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: expectedResultsMap)
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
      .sort([Field("rating").descending()])
      .limit(1) // This should pick "The Lord of the Rings" (rating 4.7)
      .select([
        Field("title"),
        Field("author"),
        Field("genre"),
        Field("rating"),
        Field("published"),
        Field("tags"),
        Field("awards"),
      ])
      .addFields([
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
        ]).as("metadata"),
      ])
      .where(
        Field("metadataArray").equal(metadataArrayElements) &&
          Field("metadata").equal(metadataMapElements)
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

      TestHelper.compare(pipelineResult: resultDoc, expected: expectedFullDoc)
    } else {
      XCTFail("No document retrieved")
    }
  }

  func testSupportsAggregate() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    var pipeline = db.pipeline()
      .collection(collRef.path)
      .aggregate([CountAll().as("count")])
    var snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Count all should return a single aggregate document")
    if let result = snapshot.results.first {
      TestHelper.compare(pipelineResult: result, expected: ["count": bookDocs.count])
    } else {
      XCTFail("No result for count all aggregation")
    }

    pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("genre").equal("Science Fiction"))
      .aggregate([
        CountAll().as("count"),
        Field("rating").average().as("avgRating"),
        Field("rating").maximum().as("maxRating"),
      ])
    snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Filtered aggregate should return a single document")
    if let result = snapshot.results.first {
      let expectedAggValues: [String: Sendable] = [
        "count": 2,
        "avgRating": 4.4,
        "maxRating": 4.6,
      ]
      TestHelper.compare(pipelineResult: result, expected: expectedAggValues)
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
        .where(Field("published").lessThan(1900))
        .aggregate([], groups: [Field("genre")])
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
      .where(Field("published").lessThan(1984))
      .aggregate(
        [Field("rating").average().as("avgRating")],
        groups: [Field("genre")]
      )
      .where(Field("avgRating").greaterThan(4.3))
      .sort([Field("avgRating").descending()])

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

    TestHelper
      .compare(snapshot: snapshot, expected: expectedResultsArray, enforceOrder: true)
  }

  func testReturnsMinMaxCountAndCountAllAccumulations() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .aggregate([
        Field("cost").count().as("booksWithCost"),
        CountAll().as("count"),
        Field("rating").maximum().as("maxRating"),
        Field("published").minimum().as("minPublished"),
      ])

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Aggregate should return a single document")

    let expectedValues: [String: Sendable] = [
      "booksWithCost": 1,
      "count": bookDocs.count,
      "maxRating": 4.7,
      "minPublished": 1813,
    ]

    if let result = snapshot.results.first {
      TestHelper.compare(pipelineResult: result, expected: expectedValues)
    } else {
      XCTFail("No result for min/max/count/countAll aggregation")
    }
  }

  func testReturnsCountDistinctAccumulation() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .aggregate([
        Field("genre").countDistinct().as("distinctGenres"),
      ])

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Aggregate should return a single document")

    let expectedValues: [String: Sendable] = [
      "distinctGenres": 8,
    ]

    if let result = snapshot.results.first {
      TestHelper.compare(pipelineResult: result, expected: expectedValues)
    } else {
      XCTFail("No result for countDistinct aggregation")
    }
  }

  func testReturnsCountIfAccumulation() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let expectedCount = 3
    let expectedResults: [String: Sendable] = ["count": expectedCount]
    let condition = Field("rating").greaterThan(4.3)

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .aggregate([condition.countIf().as("count")])
    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "countIf aggregate should return a single document")
    if let result = snapshot.results.first {
      TestHelper.compare(pipelineResult: result, expected: expectedResults)
    } else {
      XCTFail("No result for countIf aggregation")
    }
  }

  func testDistinctStage() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .distinct([Field("genre"), Field("author")])
      .sort([Field("genre").ascending(), Field("author").ascending()])

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

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testSelectStage() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([Field("title"), Field("author")])
      .sort([Field("author").ascending()])

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

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testAddFieldStage() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([Field("title"), Field("author")])
      .addFields([Constant("bar").as("foo")])
      .sort([Field("author").ascending()])

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

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testRemoveFieldsStage() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([Field("title"), Field("author")])
      .sort([Field("author").ascending()]) // Sort before removing the 'author' field
      .removeFields(["author"])

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

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testWhereStageWithAndConditions() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    // Test Case 1: Two AND conditions
    var pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("rating").greaterThan(4.5)
        && Field("genre").equalAny(["Science Fiction", "Romance", "Fantasy"]))
    var snapshot = try await pipeline.execute()
    var expectedIDs = ["book10", "book4"] // Dune (SF, 4.6), LOTR (Fantasy, 4.7)
    TestHelper.compare(snapshot: snapshot, expectedIDs: expectedIDs, enforceOrder: false)

    // Test Case 2: Three AND conditions
    pipeline = db.pipeline()
      .collection(collRef.path)
      .where(
        Field("rating").greaterThan(4.5)
          && Field("genre").equalAny(["Science Fiction", "Romance", "Fantasy"])
          && Field("published").lessThan(1965)
      )
    snapshot = try await pipeline.execute()
    expectedIDs = ["book4"] // LOTR (Fantasy, 4.7, published 1954)
    TestHelper.compare(snapshot: snapshot, expectedIDs: expectedIDs, enforceOrder: false)
  }

  func testWhereStageWithOrAndXorConditions() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    // Test Case 1: OR conditions
    var pipeline = db.pipeline()
      .collection(collRef.path)
      .where(
        Field("genre").equal("Romance")
          || Field("genre").equal("Dystopian")
          || Field("genre").equal("Fantasy")
      )
      .select([Field("title")])
      .sort([Field("title").ascending()])

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
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)

    // Test Case 2: XOR conditions
    // XOR is true if an odd number of its arguments are true.
    pipeline = db.pipeline()
      .collection(collRef.path)
      .where(
        Field("genre").equal("Romance") // Book2 (T), Book5 (F), Book4 (F), Book8 (F)
          ^ Field("genre").equal("Dystopian") // Book2 (F), Book5 (T), Book4 (F), Book8 (T)
          ^ Field("genre").equal("Fantasy") // Book2 (F), Book5 (F), Book4 (T), Book8 (F)
          ^ Field("published").equal(1949) // Book2 (F), Book5 (F), Book4 (F), Book8 (T)
      )
      .select([Field("title")])
      .sort([Field("title").ascending()])

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
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testSortOffsetAndLimitStages() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("author").ascending()])
      .offset(5)
      .limit(3)
      .select(["title", "author"])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "1984", "author": "George Orwell"],
      ["title": "To Kill a Mockingbird", "author": "Harper Lee"],
      ["title": "The Lord of the Rings", "author": "J.R.R. Tolkien"],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  // MARK: - Generic Stage Tests

  func testRawStageSelectFields() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let expectedSelectedData: [String: Sendable] = [
      "title": "1984",
      "metadata": ["author": "George Orwell"],
    ]

    let selectParameters: [Sendable] =
      [
        [
          "title": Field("title"),
          "metadata": ["author": Field("author")],
        ],
      ]

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .rawStage(name: "select", params: selectParameters)
      .sort([Field("title").ascending()])
      .limit(1)

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")
    TestHelper.compare(
      snapshot: snapshot,
      expected: [expectedSelectedData],
      enforceOrder: true
    )
  }

  func testCanAddFields() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("author").ascending()])
      .limit(1)
      .select(["title", "author"])
      .rawStage(
        name: "add_fields",
        params: [
          [
            "display": Field("title").stringConcat([
              Constant(" - "),
              Field("author"),
            ]),
          ],
        ]
      )

    let snapshot = try await pipeline.execute()

    TestHelper.compare(
      snapshot: snapshot,
      expected: [
        [
          "title": "The Hitchhiker's Guide to the Galaxy",
          "author": "Douglas Adams",
          "display": "The Hitchhiker's Guide to the Galaxy - Douglas Adams",
        ],
      ],
      enforceOrder: false
    )
  }

  func testCanPerformDistinctQuery() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select(["title", "author", "rating"])
      .rawStage(
        name: "distinct",
        params: [
          ["rating": Field("rating")],
        ]
      )
      .sort([Field("rating").descending()])

    let snapshot = try await pipeline.execute()

    TestHelper.compare(
      snapshot: snapshot,
      expected: [
        ["rating": 4.7],
        ["rating": 4.6],
        ["rating": 4.5],
        ["rating": 4.3],
        ["rating": 4.2],
        ["rating": 4.1],
        ["rating": 4.0],
      ],
      enforceOrder: true
    )
  }

  func testCanPerformAggregateQuery() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let emptySendableDictionary: [String: Sendable?] = [:]

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select(["title", "author", "rating"])
      .rawStage(
        name: "aggregate",
        params: [
          [
            "averageRating": Field("rating").average(),
          ],
          emptySendableDictionary,
        ]
      )

    let snapshot = try await pipeline.execute()

    TestHelper.compare(
      snapshot: snapshot,
      expected: [
        [
          "averageRating": 4.3100000000000005,
        ],
      ],
      enforceOrder: true
    )
  }

  func testCanFilterWithWhere() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select(["title", "author"])
      .rawStage(
        name: "where",
        params: [Field("author").equal("Douglas Adams")]
      )

    let snapshot = try await pipeline.execute()

    TestHelper.compare(
      snapshot: snapshot,
      expected: [
        [
          "title": "The Hitchhiker's Guide to the Galaxy",
          "author": "Douglas Adams",
        ],
      ],
      enforceOrder: false
    )
  }

  func testCanLimitOffsetAndSort() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select(["title", "author"])
      .rawStage(
        name: "sort",
        params: [
          [
            "direction": "ascending",
            "expression": Field("author"),
          ],
        ]
      )
      .rawStage(name: "offset", params: [3])
      .rawStage(name: "limit", params: [1])

    let snapshot = try await pipeline.execute()

    TestHelper.compare(
      snapshot: snapshot,
      expected: [
        [
          "author": "Fyodor Dostoevsky",
          "title": "Crime and Punishment",
        ],
      ],
      enforceOrder: false
    )
  }

  // MARK: - Replace Stage Test

  func testReplaceStagePromoteAwardsAndAddFlag() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").equal("The Hitchhiker's Guide to the Galaxy"))
      .replace(with: "awards")

    let snapshot = try await pipeline.execute()

    TestHelper.compare(snapshot: snapshot, expectedCount: 1)

    let expectedBook1Transformed: [String: Sendable?] = [
      "hugo": true,
      "nebula": false,
      "others": ["unknown": ["year": 1980]],
    ]

    TestHelper
      .compare(
        snapshot: snapshot,
        expected: [expectedBook1Transformed],
        enforceOrder: false
      )
  }

  func testReplaceWithExprResult() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").equal("The Hitchhiker's Guide to the Galaxy"))
      .replace(with:
        MapExpression([
          "foo": "bar",
          "baz": MapExpression([
            "title": Field("title"),
          ]),
        ]))

    let snapshot = try await pipeline.execute()

    let expectedResults: [String: Sendable?] = [
      "foo": "bar",
      "baz": ["title": "The Hitchhiker's Guide to the Galaxy"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: [expectedResults], enforceOrder: false)
  }

  // MARK: - Sample Stage Tests

  func testSampleStageLimit3() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sample(count: 3)

    let snapshot = try await pipeline.execute()

    TestHelper
      .compare(snapshot: snapshot, expectedCount: 3)
  }

  func testSampleStageLimitPercentage60Average() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    var avgSize = 0.0
    let numIterations = 20
    for _ in 0 ..< numIterations {
      let snapshot = try await db
        .pipeline()
        .collection(collRef.path)
        .sample(percentage: 0.6)
        .execute()
      avgSize += Double(snapshot.results.count)
    }
    avgSize /= Double(numIterations)
    XCTAssertEqual(avgSize, 6.0, accuracy: 1.0, "Average size should be close to 6")
  }

  // MARK: - Union Stage Test

  func testUnionStageCombineAuthors() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .union(with: db.pipeline()
        .collection(collRef.path))
      .sort([Field(FieldPath.documentID()).ascending()])

    let snapshot = try await pipeline.execute()

    let books = [
      "book1",
      "book1",
      "book10",
      "book10",
      "book2",
      "book2",
      "book3",
      "book3",
      "book4",
      "book4",
      "book5",
      "book5",
      "book6",
      "book6",
      "book7",
      "book7",
      "book8",
      "book8",
      "book9",
      "book9",
    ]
    TestHelper.compare(snapshot: snapshot, expectedIDs: books, enforceOrder: false)
  }

  func testUnnestStage() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").equal("The Hitchhiker's Guide to the Galaxy"))
      .unnest(Field("tags").as("tag"), indexField: "tagsIndex")
      .select([
        "title",
        "author",
        "genre",
        "published",
        "rating",
        "tags",
        "tag",
        "awards",
        "nestedField",
      ])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable?]] = [
      [
        "title": "The Hitchhiker's Guide to the Galaxy",
        "author": "Douglas Adams",
        "genre": "Science Fiction",
        "published": 1979,
        "rating": 4.2,
        "tags": ["comedy", "space", "adventure"],
        "tag": "comedy",
        "awards": ["hugo": true, "nebula": false, "others": ["unknown": ["year": 1980]]],
        "nestedField": ["level.1": ["level.2": true]],
      ],
      [
        "title": "The Hitchhiker's Guide to the Galaxy",
        "author": "Douglas Adams",
        "genre": "Science Fiction",
        "published": 1979,
        "rating": 4.2,
        "tags": ["comedy", "space", "adventure"],
        "tag": "space",
        "awards": ["hugo": true, "nebula": false, "others": ["unknown": ["year": 1980]]],
        "nestedField": ["level.1": ["level.2": true]],
      ],
      [
        "title": "The Hitchhiker's Guide to the Galaxy",
        "author": "Douglas Adams",
        "genre": "Science Fiction",
        "published": 1979,
        "rating": 4.2,
        "tags": ["comedy", "space", "adventure"],
        "tag": "adventure",
        "awards": ["hugo": true, "nebula": false, "others": ["unknown": ["year": 1980]]],
        "nestedField": ["level.1": ["level.2": true]],
      ],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: false)
  }

  func testUnnestExpr() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").equal("The Hitchhiker's Guide to the Galaxy"))
      .unnest(ArrayExpression([1, 2, 3]).as("copy"))
      .select([
        "title",
        "author",
        "genre",
        "published",
        "rating",
        "tags",
        "copy",
        "awards",
        "nestedField",
      ])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable?]] = [
      [
        "title": "The Hitchhiker's Guide to the Galaxy",
        "author": "Douglas Adams",
        "genre": "Science Fiction",
        "published": 1979,
        "rating": 4.2,
        "tags": ["comedy", "space", "adventure"],
        "copy": 1,
        "awards": ["hugo": true, "nebula": false, "others": ["unknown": ["year": 1980]]],
        "nestedField": ["level.1": ["level.2": true]],
      ],
      [
        "title": "The Hitchhiker's Guide to the Galaxy",
        "author": "Douglas Adams",
        "genre": "Science Fiction",
        "published": 1979,
        "rating": 4.2,
        "tags": ["comedy", "space", "adventure"],
        "copy": 2,
        "awards": ["hugo": true, "nebula": false, "others": ["unknown": ["year": 1980]]],
        "nestedField": ["level.1": ["level.2": true]],
      ],
      [
        "title": "The Hitchhiker's Guide to the Galaxy",
        "author": "Douglas Adams",
        "genre": "Science Fiction",
        "published": 1979,
        "rating": 4.2,
        "tags": ["comedy", "space", "adventure"],
        "copy": 3,
        "awards": ["hugo": true, "nebula": false, "others": ["unknown": ["year": 1980]]],
        "nestedField": ["level.1": ["level.2": true]],
      ],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: false)
  }

  func testFindNearest() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let measures: [DistanceMeasure] = [.euclidean, .dotProduct, .cosine]
    let expectedResults: [[String: Sendable]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy"],
      ["title": "One Hundred Years of Solitude"],
      ["title": "The Handmaid's Tale"],
    ]

    for measure in measures {
      let pipeline = db.pipeline()
        .collection(collRef.path)
        .findNearest(
          field: Field("embedding"),
          vectorValue: VectorValue([10, 1, 3, 1, 2, 1, 1, 1, 1, 1]),
          distanceMeasure: measure, limit: 3
        )
        .select(["title"])
      let snapshot = try await pipeline.execute()
      TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
    }
  }

  func testFindNearestWithDistance() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let expectedResults: [[String: Sendable]] = [
      [
        "title": "The Hitchhiker's Guide to the Galaxy",
        "computedDistance": 1.0,
      ],
      [
        "title": "One Hundred Years of Solitude",
        "computedDistance": 12.041594578792296,
      ],
    ]

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .findNearest(
        field: Field("embedding"),
        vectorValue: VectorValue([10, 1, 2, 1, 1, 1, 1, 1, 1, 1]),
        distanceMeasure: .euclidean, limit: 2,
        distanceField: "computedDistance"
      )
      .select(["title", "computedDistance"])
    let snapshot = try await pipeline.execute()
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: false)
  }

  func testLogicalMaxWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("title"),
        Field("published").logicalMaximum([Constant(1960), 1961]).as("published-safe"),
      ])
      .sort([Field("title").ascending()])
      .limit(3)

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "1984", "published-safe": 1961],
      ["title": "Crime and Punishment", "published-safe": 1961],
      ["title": "Dune", "published-safe": 1965],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testLogicalMinWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("title"),
        Field("published").logicalMinimum([Constant(1960), 1961]).as("published-safe"),
      ])
      .sort([Field("title").ascending()])
      .limit(3)

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "1984", "published-safe": 1949],
      ["title": "Crime and Punishment", "published-safe": 1866],
      ["title": "Dune", "published-safe": 1960],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testCondWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("title"),
        Field("published").lessThan(1960).then(Constant(1960), else: Field("published"))
          .as("published-safe"),
      ])
      .sort([Field("title").ascending()])
      .limit(3)

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "1984", "published-safe": 1960],
      ["title": "Crime and Punishment", "published-safe": 1960],
      ["title": "Dune", "published-safe": 1965],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testIfAbsentWorks() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["value": 1],
      "doc2": ["value2": 2],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("value").ifAbsent(100).as("value"),
      ])
      .sort([Field(FieldPath.documentID()).ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["value": 100],
      ["value": 1],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testInWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("published").equalAny([1979, 1999, 1967]))
      .sort([Field("title").descending()])
      .select(["title"])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy"],
      ["title": "One Hundred Years of Solitude"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testNotEqAnyWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("published")
        .notEqualAny([1965, 1925, 1949, 1960, 1866, 1985, 1954, 1967, 1979]))
      .select(["title"])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "Pride and Prejudice"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: false)
  }

  func testArrayContainsWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("tags").arrayContains("comedy"))
      .select(["title"])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: false)
  }

  func testArrayContainsAnyWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("tags").arrayContainsAny(["comedy", "classic"]))
      .sort([Field("title").descending()])
      .select(["title"])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy"],
      ["title": "Pride and Prejudice"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testArrayContainsAllWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("tags").arrayContainsAll(["adventure", "magic"]))
      .select(["title"])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Lord of the Rings"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: false)
  }

  func testArrayLengthWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([Field("tags").arrayLength().as("tagsCount")])
      .where(Field("tagsCount").equal(3))

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 10)
  }

  func testArrayReverseWorks() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["tags": ["a", "b", "c"]],
      "doc2": ["tags": [1, 2, 3]],
      "doc3": ["tags": []],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("tags").arrayReverse().as("reversedTags"),
      ])
      .sort([Field("reversedTags").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["reversedTags": []],
      ["reversedTags": [3, 2, 1]],
      ["reversedTags": ["c", "b", "a"]],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testStrConcat() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("author").ascending()])
      .select([Field("author").stringConcat([Constant(" - "), Field("title")]).as("bookInfo")])
      .limit(1)

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["bookInfo": "Douglas Adams - The Hitchhiker's Guide to the Galaxy"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testStringConcatWithSendable() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("author").ascending()])
      .select([Field("author").stringConcat([" - ", Field("title")]).as("bookInfo")])
      .limit(1)

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["bookInfo": "Douglas Adams - The Hitchhiker's Guide to the Galaxy"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testConcatWorks() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["s": "a", "b": "b", "c": "c"],
      "doc2": ["s": "x", "b": "y", "c": "z"],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("s").concat([Field("b"), Field("c"), " "]).as("concatenated"),
      ])
      .sort([Field("concatenated").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["concatenated": "abc "],
      ["concatenated": "xyz "],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testStartsWith() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").startsWith("The"))
      .select(["title"])
      .sort([Field("title").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Great Gatsby"],
      ["title": "The Handmaid's Tale"],
      ["title": "The Hitchhiker's Guide to the Galaxy"],
      ["title": "The Lord of the Rings"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testEndsWith() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").endsWith("y"))
      .select(["title"])
      .sort([Field("title").descending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy"],
      ["title": "The Great Gatsby"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testStrContains() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").stringContains("'s"))
      .select(["title"])
      .sort([Field("title").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Handmaid's Tale"],
      ["title": "The Hitchhiker's Guide to the Galaxy"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testCharLength() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("title").charLength().as("titleLength"),
        Field("title"),
      ])
      .where(Field("titleLength").greaterThan(20))
      .sort([Field("title").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["titleLength": 29, "title": "One Hundred Years of Solitude"],
      ["titleLength": 36, "title": "The Hitchhiker's Guide to the Galaxy"],
      ["titleLength": 21, "title": "The Lord of the Rings"],
      ["titleLength": 21, "title": "To Kill a Mockingbird"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testLength() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["value": "abc"],
      "doc2": ["value": ""],
      "doc3": ["value": "a"],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("value").length().as("lengthValue"),
      ])
      .sort([Field("lengthValue").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["lengthValue": 0],
      ["lengthValue": 1],
      ["lengthValue": 3],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testReverseWorksOnString() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["value": "abc"],
      "doc2": ["value": ""],
      "doc3": ["value": "a"],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("value").reverse().as("reversedValue"),
      ])
      .sort([Field("reversedValue").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["reversedValue": ""],
      ["reversedValue": "a"],
      ["reversedValue": "cba"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testReverseWorksOnArray() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["tags": ["a", "b", "c"]],
      "doc2": ["tags": [1, 2, 3]],
      "doc3": ["tags": []],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("tags").reverse().as("reversedTags"),
      ])
      .sort([Field("reversedTags").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["reversedTags": []],
      ["reversedTags": [3, 2, 1]],
      ["reversedTags": ["c", "b", "a"]],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testLike() async throws {
    try XCTSkipIf(
      FSTIntegrationTestCase.isRunningAgainstEmulator(),
      "Emulator does not support this function."
    )

    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").like("%Guide%"))
      .select(["title"])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: false)
  }

  func testRegexContains() async throws {
    try XCTSkipIf(
      FSTIntegrationTestCase.isRunningAgainstEmulator(),
      "Emulator does not support this function."
    )

    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").regexContains("(?i)(the|of)"))

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 5)
  }

  func testRegexFind() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("title").regexFind("^\\w+").as("firstWordInTitle"),
      ])
      .select([
        Field("firstWordInTitle"),
      ])
      .sort([Field("firstWordInTitle").ascending()])
      .limit(3)

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["firstWordInTitle": "1984"],
      ["firstWordInTitle": "Crime"],
      ["firstWordInTitle": "Dune"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testRegexFindAll() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("title").regexFindAll("\\w+").as("wordsInTitle"),
      ])
      .select([
        Field("wordsInTitle"),
      ])
      .sort([Field("wordsInTitle").ascending()])
      .limit(3)

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["wordsInTitle": ["1984"]],
      ["wordsInTitle": ["Crime", "and", "Punishment"]],
      ["wordsInTitle": ["Dune"]],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testRegexMatches() async throws {
    try XCTSkipIf(
      FSTIntegrationTestCase.isRunningAgainstEmulator(),
      "Emulator does not support this function."
    )

    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").regexMatch(".*(?i)(the|of).*"))

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 5)
  }

  func testArithmeticOperations() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").equal("To Kill a Mockingbird"))
      .select([
        Field("rating").add(1).as("ratingPlusOne"),
        Field("published").subtract(1900).as("yearsSince1900"),
        Field("rating").multiply(10).as("ratingTimesTen"),
        Field("rating").divide(2).as("ratingDividedByTwo"),
        Field("rating").multiply(20).as("ratingTimes20"),
        Field("rating").add(3).as("ratingPlus3"),
        Field("rating").mod(2).as("ratingMod2"),
      ])
      .limit(1)

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")

    if let resultDoc = snapshot.results.first {
      let expectedResults: [String: Sendable?] = [
        "ratingPlusOne": 5.2,
        "yearsSince1900": 60,
        "ratingTimesTen": 42.0,
        "ratingDividedByTwo": 2.1,
        "ratingTimes20": 84.0,
        "ratingPlus3": 7.2,
        "ratingMod2": 0.20000000000000018,
      ]
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResults)
    } else {
      XCTFail("No document retrieved for arithmetic operations test")
    }
  }

  func testAbsWorks() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["value": -10],
      "doc2": ["value": 5],
      "doc3": ["value": 0],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("value").abs().as("absValue"),
      ])
      .sort([Field("absValue").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["absValue": 0],
      ["absValue": 5],
      ["absValue": 10],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testCeilWorks() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["value": -10.8],
      "doc2": ["value": 5.3],
      "doc3": ["value": 0],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("value").ceil().as("ceilValue"),
      ])
      .sort([Field("ceilValue").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["ceilValue": -10],
      ["ceilValue": 0],
      ["ceilValue": 6],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testFloorWorks() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["value": -10.8],
      "doc2": ["value": 5.3],
      "doc3": ["value": 0],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("value").floor().as("floorValue"),
      ])
      .sort([Field("floorValue").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["floorValue": -11],
      ["floorValue": 0],
      ["floorValue": 5],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testLnWorks() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["value": 1],
      "doc2": ["value": exp(Double(2))],
      "doc3": ["value": exp(Double(1))],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("value").ln().as("lnValue"),
      ])
      .sort([Field("lnValue").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["lnValue": 0],
      ["lnValue": 1],
      ["lnValue": 2],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testPowWorks() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["base": 2, "exponent": 3],
      "doc2": ["base": 3, "exponent": 2],
      "doc3": ["base": 4, "exponent": 0.5],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("base").pow(Field("exponent")).as("powValue"),
      ])
      .sort([Field("powValue").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["powValue": 2],
      ["powValue": 8],
      ["powValue": 9],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testRoundWorks() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["value": -10.8],
      "doc2": ["value": 5.3],
      "doc3": ["value": 0],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("value").round().as("roundValue"),
      ])
      .sort([Field("roundValue").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["roundValue": -11],
      ["roundValue": 0],
      ["roundValue": 5],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testSqrtWorks() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["value": 4],
      "doc2": ["value": 9],
      "doc3": ["value": 16],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("value").sqrt().as("sqrtValue"),
      ])
      .sort([Field("sqrtValue").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["sqrtValue": 2],
      ["sqrtValue": 3],
      ["sqrtValue": 4],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testExpWorks() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["value": 1],
      "doc2": ["value": 0],
      "doc3": ["value": -1],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("value").exp().as("expValue"),
      ])
      .sort([Field("expValue").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["expValue": Foundation.exp(Double(-1))],
      ["expValue": Foundation.exp(Double(0))],
      ["expValue": Foundation.exp(Double(1))],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testExpUnderflow() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["value": -1000],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("value").exp().as("expValue"),
      ])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["expValue": 0],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testExpOverflow() async throws {
    try XCTSkipIf(
      FSTIntegrationTestCase.isRunningAgainstEmulator(),
      "Skipping test because the emulator's behavior deviates from the expected outcome."
    )

    let collRef = collectionRef(withDocuments: [
      "doc1": ["value": 1000],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("value").exp().as("expValue"),
      ])

    do {
      let _ = try await pipeline.execute()
      XCTFail("The pipeline should have thrown an error, but it did not.")
    } catch {
      XCTAssert(true, "Successfully caught expected error from exponent overflow.")
    }
  }

  func testCollectionIdWorks() async throws {
    let collRef = collectionRef()
    let docRef = collRef.document("doc")
    try await docRef.setData(["foo": "bar"])

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field(FieldPath.documentID()).collectionId().as("collectionId"),
      ])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["collectionId": collRef.collectionID],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

//  func testCollectionIdOnRootThrowsError() async throws {
//    let db = firestore()
//    let pipeline = db.pipeline()
//      .database()
//      .select([
//        Field(FieldPath.documentID()).collectionId().as("collectionId"),
//      ])
//
//    do {
//      _ = try await pipeline.execute()
//      XCTFail("Should have thrown an error")
//    } catch {
//      // Expected error
//    }
//  }

  func testComparisonOperators() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(
        Field("rating").greaterThan(4.2) &&
          Field("rating").lessThanOrEqual(4.5) &&
          Field("genre").notEqual("Science Fiction")
      )
      .select(["rating", "title"])
      .sort([Field("title").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["rating": 4.3, "title": "Crime and Punishment"],
      ["rating": 4.3, "title": "One Hundred Years of Solitude"],
      ["rating": 4.5, "title": "Pride and Prejudice"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testLogicalOperators() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(
        (Field("rating").greaterThan(4.5) && Field("genre").equal("Science Fiction")) ||
          Field("published").lessThan(1900)
      )
      .select(["title"])
      .sort([Field("title").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "Crime and Punishment"],
      ["title": "Dune"],
      ["title": "Pride and Prejudice"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testChecks() async throws {
    try XCTSkipIf(
      FSTIntegrationTestCase.isRunningAgainstEmulator(),
      "Skipping test because the emulator's behavior deviates from the expected outcome."
    )

    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("rating").descending()])
      .limit(1)
      .select(
        [
          Field("rating").equal(Constant.nil).as("ratingIsNull"),
          Field("rating").equal(Constant(Double.nan)).as("ratingIsNaN"),
          Field("foo").isAbsent().as("isAbsent"),
          Field("title").notEqual(Constant.nil).as("titleIsNotNull"),
          Field("cost").notEqual(Constant(Double.nan)).as("costIsNotNan"),
          Field("fooBarBaz").exists().as("fooBarBazExists"),
          Field("title").exists().as("titleExists"),
        ]
      )

    let snapshot = try await pipeline.execute()
    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document for checks")

    if let resultDoc = snapshot.results.first {
      let expectedResults: [String: Sendable?] = [
        "ratingIsNull": false,
        "ratingIsNaN": false,
        "isAbsent": true,
        "titleIsNotNull": true,
        "costIsNotNan": false,
        "fooBarBazExists": false,
        "titleExists": true,
      ]
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResults)
    } else {
      XCTFail("No document retrieved for checks")
    }
  }

  func testIsError() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("rating").descending()])
      .limit(1)
      .select(
        [
          Field("title").arrayLength().isError().as("isError"),
        ]
      )

    let snapshot = try await pipeline.execute()
    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document for test")

    if let resultDoc = snapshot.results.first {
      let expectedResults: [String: Sendable?] = [
        "isError": true,
      ]
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResults)
    } else {
      XCTFail("No document retrieved for test")
    }
  }

  func testIfError() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("rating").descending()])
      .limit(1)
      .select(
        [
          Field("title").arrayLength().ifError(Constant("was error")).as("ifError"),
        ]
      )

    let snapshot = try await pipeline.execute()
    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document for test")

    if let resultDoc = snapshot.results.first {
      let expectedResults: [String: Sendable?] = [
        "ifError": "was error",
      ]
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResults)
    } else {
      XCTFail("No document retrieved for test")
    }
  }

  func testMapGet() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("published").descending()])
      .select(
        [
          Field("awards").mapGet("hugo").as("hugoAward"),
          Field("awards").mapGet("others").as("others"),
          Field("title"),
        ]
      )
      .where(Field("hugoAward").equal(true))

    let snapshot = try await pipeline.execute()

    // Expected results are ordered by "published" descending for those with hugoAward == true
    // 1. The Hitchhiker's Guide to the Galaxy (1979)
    // 2. Dune (1965)
    let expectedResults: [[String: Sendable?]] = [
      [
        "hugoAward": true,
        "title": "The Hitchhiker's Guide to the Galaxy",
        "others": ["unknown": ["year": 1980]],
      ],
      [
        "hugoAward": true,
        "title": "Dune",
      ],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testDistanceFunctions() async throws {
    let db = firestore()
    let randomCol = collectionRef() // Ensure a unique collection for the test
    // Add a dummy document to the collection for the select stage to operate on.
    try await randomCol.document("dummyDocForDistanceTest").setData(["field": "value"])

    let sourceVector: [Double] = [0.1, 0.1]
    let targetVector: [Double] = [0.5, 0.8]
    let targetVectorValue = VectorValue(targetVector)

    let expectedCosineDistance = 0.02560880430538015
    let expectedDotProductDistance = 0.13
    let expectedEuclideanDistance = 0.806225774829855
    let accuracy = 0.000000000000001 // Define a suitable accuracy for floating-point comparisons

    let pipeline = db.pipeline()
      .collection(randomCol.path)
      .select(
        [
          Constant(VectorValue(sourceVector)).cosineDistance(targetVectorValue)
            .as("cosineDistance"),
          Constant(VectorValue(sourceVector)).dotProduct(targetVectorValue)
            .as("dotProductDistance"),
          Constant(VectorValue(sourceVector)).euclideanDistance(targetVectorValue)
            .as("euclideanDistance"),
        ]
      )
      .limit(1)

    let snapshot = try await pipeline.execute()
    XCTAssertEqual(
      snapshot.results.count,
      1,
      "Should retrieve one document for distance functions part 1"
    )

    if let resultDoc = snapshot.results.first {
      XCTAssertEqual(
        resultDoc.get("cosineDistance")! as! Double,
        expectedCosineDistance,
        accuracy: accuracy
      )
      XCTAssertEqual(
        resultDoc.get("dotProductDistance")! as! Double,
        expectedDotProductDistance,
        accuracy: accuracy
      )
      XCTAssertEqual(
        resultDoc.get("euclideanDistance")! as! Double,
        expectedEuclideanDistance,
        accuracy: accuracy
      )
    } else {
      XCTFail("No document retrieved for distance functions part 1")
    }
  }

  func testVectorLength() async throws {
    let collRef = collectionRef() // Using a new collection for this test
    let db = collRef.firestore
    let docRef = collRef.document("vectorDocForLengthTestFinal")

    // Add a document with a known vector field
    try await docRef.setData(["embedding": VectorValue([1.0, 2.0, 3.0])])

    // Construct a pipeline query
    let pipeline = db.pipeline()
      .collection(collRef.path)
      .limit(1) // Limit to the document we just added
      .select([Field("embedding").vectorLength().as("vectorLength")])

    // Execute the pipeline
    let snapshot = try await pipeline.execute()

    // Assert that the vectorLength in the result is 3
    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")
    if let resultDoc = snapshot.results.first {
      let expectedResult: [String: Sendable?] = ["vectorLength": 3]
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResult)
    } else {
      XCTFail("No document retrieved for vectorLength test")
    }
  }

  func testNestedFields() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("awards.hugo").equal(true))
      .sort([Field("title").descending()])
      .select([Field("title"), Field("awards.hugo")])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable?]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy", "awards.hugo": true],
      ["title": "Dune", "awards.hugo": true],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testMapGetWithFieldNameIncludingDotNotation() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("awards.hugo").equal(true)) // Filters to book1 and book10
      .select([
        Field("title"),
        Field("nestedField.level.1"),
        Field("nestedField").mapGet("level.1").mapGet("level.2").as("nested"),
      ])
      .sort([Field("title").descending()])

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 2, "Should retrieve two documents")

    let expectedResultsArray: [[String: Sendable?]] = [
      [
        "title": "The Hitchhiker's Guide to the Galaxy",
        "nested": true,
      ],
      [
        "title": "Dune",
      ],
    ]
    TestHelper.compare(
      snapshot: snapshot,
      expected: expectedResultsArray,
      enforceOrder: true
    )
  }

  func testGenericFunctionAddSelectable() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("rating").descending()])
      .limit(1)
      .select(
        [
          FunctionExpression(functionName: "add", args: [Field("rating"), Constant(1)]).as(
            "rating"
          ),
        ]
      )

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")

    let expectedResult: [String: Sendable?] = [
      "rating": 5.7,
    ]

    if let resultDoc = snapshot.results.first {
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResult)
    } else {
      XCTFail("No document retrieved for testGenericFunctionAddSelectable")
    }
  }

  func testGenericFunctionAndVariadicSelectable() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(
        FunctionExpression(functionName: "and", args: [Field("rating").greaterThan(0),
                                                       Field("title").charLength().lessThan(5),
                                                       Field("tags")
                                                         .arrayContains("propaganda")]).asBoolean()
      )
      .select(["title"])

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")

    let expectedResult: [[String: Sendable?]] = [
      ["title": "1984"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResult, enforceOrder: false)
  }

  func testGenericFunctionArrayContainsAny() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(FunctionExpression(
        functionName: "array_contains_any",
        args: [Field("tags"), ArrayExpression(["politics"])]
      ).asBoolean())
      .select([Field("title")])

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")

    let expectedResult: [[String: Sendable?]] = [
      ["title": "Dune"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResult, enforceOrder: false)
  }

  func testGenericFunctionCountIfAggregate() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .aggregate(
        [AggregateFunction(
          functionName: "count_if",
          args: [Field("rating").greaterThanOrEqual(4.5)]
        )
        .as("countOfBest")]
      )

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Aggregate should return a single document")

    let expectedResult: [String: Sendable?] = [
      "countOfBest": 3,
    ]

    if let resultDoc = snapshot.results.first {
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResult)
    } else {
      XCTFail("No document retrieved for testGenericFunctionCountIfAggregate")
    }
  }

  func testGenericFunctionSortByCharLen() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort(
        [
          FunctionExpression(functionName: "char_length", args: [Field("title")]).ascending(),
          Field("__name__").descending(),
        ]
      )
      .limit(3)
      .select([Field("title")])

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 3, "Should retrieve three documents")

    let expectedResults: [[String: Sendable?]] = [
      ["title": "1984"],
      ["title": "Dune"],
      ["title": "The Great Gatsby"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testJoinWorks() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["tags": ["a", "b", "c"]],
      "doc2": ["tags": ["d", "e"]],
      "doc3": ["tags": []],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("tags").join(delimiter: ", ").as("tagsString"),
      ])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["tagsString": "a, b, c"],
      ["tagsString": "d, e"],
      ["tagsString": ""],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: false)
  }

//  func testSupportsRand() async throws {
//    let collRef = collectionRef(withDocuments: bookDocs)
//    let db = collRef.firestore
//
//    let pipeline = db.pipeline()
//      .collection(collRef.path)
//      .limit(10)
//      .select([RandomExpression().as("result")])
//
//    let snapshot = try await pipeline.execute()
//
//    XCTAssertEqual(snapshot.results.count, 10, "Should fetch 10 documents")
//
//    for doc in snapshot.results {
//      guard let resultValue = doc.get("result") else {
//        XCTFail("Document \(doc.id ?? "unknown") should have a 'result' field")
//        continue
//      }
//      guard let doubleValue = resultValue as? Double else {
//        XCTFail("Result value for document \(doc.id ?? "unknown") is not a Double:
//        \(resultValue)")
//        continue
//      }
//      XCTAssertGreaterThanOrEqual(
//        doubleValue,
//        0.0,
//        "Result for \(doc.id ?? "unknown") should be >= 0.0"
//      )
//      XCTAssertLessThan(doubleValue, 1.0, "Result for \(doc.id ?? "unknown") should be < 1.0")
//    }
//  }

  func testSupportsArray() async throws {
    let db = firestore()
    let collRef = collectionRef(withDocuments: bookDocs)

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("rating").descending()])
      .limit(1)
      .select([ArrayExpression([1, 2, 3, 4]).as("metadata")])

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")

    let expectedResults: [String: Sendable?] = ["metadata": [1, 2, 3, 4]]

    if let resultDoc = snapshot.results.first {
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResults)
    } else {
      XCTFail("No document retrieved for testSupportsArray")
    }
  }

  func testEvaluatesExpressionInArray() async throws {
    let db = firestore()
    let collRef = collectionRef(withDocuments: bookDocs)

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("rating").descending()])
      .limit(1)
      .select([ArrayExpression([
        1,
        2,
        Field("genre"),
        Field("rating").multiply(10),
      ]).as("metadata")])

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")

    let expectedResults: [String: Sendable?] = ["metadata": [1, 2, "Fantasy", 47.0]]

    if let resultDoc = snapshot.results.first {
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResults)
    } else {
      XCTFail("No document retrieved for testEvaluatesExpressionInArray")
    }
  }

  func testSupportsArrayOffset() async throws {
    let db = firestore()
    let collRef = collectionRef(withDocuments: bookDocs)

    let expectedResultsPart1: [[String: Sendable?]] = [
      ["firstTag": "adventure"],
      ["firstTag": "politics"],
      ["firstTag": "classic"],
    ]

    let pipeline1 = db.pipeline()
      .collection(collRef.path)
      .sort([Field("rating").descending()])
      .limit(3)
      .select([Field("tags").arrayGet(0).as("firstTag")])

    let snapshot1 = try await pipeline1.execute()
    XCTAssertEqual(snapshot1.results.count, 3, "Part 1: Should retrieve three documents")
    TestHelper.compare(
      snapshot: snapshot1,
      expected: expectedResultsPart1,
      enforceOrder: true
    )
  }

  func testSupportsMap() async throws {
    let db = firestore()
    let collRef = collectionRef(withDocuments: bookDocs)

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("rating").descending()])
      .limit(1)
      .select([MapExpression(["foo": "bar"]).as("metadata")])

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")

    let expectedResult: [String: Sendable?] = ["metadata": ["foo": "bar"]]

    if let resultDoc = snapshot.results.first {
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResult)
    } else {
      XCTFail("No document retrieved for testSupportsMap")
    }
  }

  func testEvaluatesExpressionInMap() async throws {
    let db = firestore()
    let collRef = collectionRef(withDocuments: bookDocs)

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("rating").descending()])
      .limit(1)
      .select([MapExpression([
        "genre": Field("genre"), // "Fantasy"
        "rating": Field("rating").multiply(10), // 4.7 * 10 = 47.0
      ]).as("metadata")])

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")

    // Expected: genre is "Fantasy", rating is 4.7 for book4
    let expectedResult: [String: Sendable?] = ["metadata": ["genre": "Fantasy", "rating": 47.0]]

    if let resultDoc = snapshot.results.first {
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResult)
    } else {
      XCTFail("No document retrieved for testEvaluatesExpressionInMap")
    }
  }

  func testSupportsMapRemove() async throws {
    let db = firestore()
    let collRef = collectionRef(withDocuments: bookDocs)

    let expectedResult: [String: Sendable?] = ["awards": ["nebula": false]]

    let pipeline2 = db.pipeline()
      .collection(collRef.path)
      .sort([Field("rating").descending()])
      .limit(1)
      .select([Field("awards").mapRemove("hugo").as("awards")])

    let snapshot2 = try await pipeline2.execute()
    XCTAssertEqual(snapshot2.results.count, 1, "Should retrieve one document")
    if let resultDoc2 = snapshot2.results.first {
      TestHelper.compare(pipelineResult: resultDoc2, expected: expectedResult)
    } else {
      XCTFail("No document retrieved for testSupportsMapRemove")
    }
  }

  func testSupportsMapMerge() async throws {
    let db = firestore()
    let collRef = collectionRef(withDocuments: bookDocs)

    let expectedResult: [String: Sendable] =
      ["awards": ["hugo": false, "nebula": false, "fakeAward": true]]
    let mergeMap: [String: Sendable] = ["fakeAward": true]

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("rating").descending()])
      .limit(1)
      .select([Field("awards").mapMerge([mergeMap]).as("awards")])

    let snapshot = try await pipeline.execute()
    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")
    if let resultDoc = snapshot.results.first {
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResult)
    } else {
      XCTFail("No document retrieved for testSupportsMapMerge")
    }
  }

  func testSupportsTimestampConversions() async throws {
    let db = firestore()
    let randomCol = collectionRef() // Unique collection for this test

    // Add a dummy document to ensure the select stage has an input
    try await randomCol.document("dummyTimeDoc").setData(["field": "value"])

    let pipeline = db.pipeline()
      .collection(randomCol.path)
      .limit(1)
      .select(
        [
          Constant(1_741_380_235).unixSecondsToTimestamp().as("unixSecondsToTimestamp"),
          Constant(1_741_380_235_123).unixMillisToTimestamp().as("unixMillisToTimestamp"),
          Constant(1_741_380_235_123_456).unixMicrosToTimestamp().as("unixMicrosToTimestamp"),
          Constant(Timestamp(seconds: 1_741_380_235, nanoseconds: 123_456_789))
            .timestampToUnixSeconds().as("timestampToUnixSeconds"),
          Constant(Timestamp(seconds: 1_741_380_235, nanoseconds: 123_456_789))
            .timestampToUnixMillis().as("timestampToUnixMillis"),
          Constant(Timestamp(seconds: 1_741_380_235, nanoseconds: 123_456_789))
            .timestampToUnixMicros().as("timestampToUnixMicros"),
        ]
      )

    let snapshot = try await pipeline.execute()
    XCTAssertEqual(
      snapshot.results.count,
      1,
      "Should retrieve one document for timestamp conversions"
    )

    let expectedResults: [String: Sendable?] = [
      "unixSecondsToTimestamp": Timestamp(seconds: 1_741_380_235, nanoseconds: 0),
      "unixMillisToTimestamp": Timestamp(seconds: 1_741_380_235, nanoseconds: 123_000_000),
      "unixMicrosToTimestamp": Timestamp(seconds: 1_741_380_235, nanoseconds: 123_456_000),
      "timestampToUnixSeconds": 1_741_380_235,
      "timestampToUnixMillis": 1_741_380_235_123,
      "timestampToUnixMicros": 1_741_380_235_123_456,
    ]

    if let resultDoc = snapshot.results.first {
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResults)
    } else {
      XCTFail("No document retrieved for testSupportsTimestampConversions")
    }
  }

  func testSupportsTimestampMath() async throws {
    let db = firestore()
    let randomCol = collectionRef()
    try await randomCol.document("dummyDoc").setData(["field": "value"])

    let initialTimestamp = Timestamp(seconds: 1_741_380_235, nanoseconds: 0)

    let pipeline = db.pipeline()
      .collection(randomCol.path)
      .limit(1)
      .select(
        [
          Constant(initialTimestamp).as("timestamp"),
        ]
      )
      .select(
        [
          Field("timestamp").timestampAdd(10, .day).as("plus10days"),
          Field("timestamp").timestampAdd(10, .hour).as("plus10hours"),
          Field("timestamp").timestampAdd(10, .minute).as("plus10minutes"),
          Field("timestamp").timestampAdd(10, .second).as("plus10seconds"),
          Field("timestamp").timestampAdd(10, .microsecond).as("plus10micros"),
          Field("timestamp").timestampAdd(10, .millisecond).as("plus10millis"),
          Field("timestamp").timestampAdd(amount: Constant(10), unit: "day")
            .as("plus10daysExprUnitSendable"),
          Field("timestamp").timestampSubtract(10, .day).as("minus10days"),
          Field("timestamp").timestampSubtract(10, .hour).as("minus10hours"),
          Field("timestamp").timestampSubtract(10, .minute).as("minus10minutes"),
          Field("timestamp").timestampSubtract(10, .second).as("minus10seconds"),
          Field("timestamp").timestampSubtract(10, .microsecond).as("minus10micros"),
          Field("timestamp").timestampSubtract(10, .millisecond).as("minus10millis"),
          Field("timestamp").timestampSubtract(amount: Constant(10), unit: "day")
            .as("minus10daysExprUnitSendable"),
        ]
      )

    let snapshot = try await pipeline.execute()

    let expectedResults: [String: Timestamp] = [
      "plus10days": Timestamp(seconds: 1_742_244_235, nanoseconds: 0),
      "plus10hours": Timestamp(seconds: 1_741_416_235, nanoseconds: 0),
      "plus10minutes": Timestamp(seconds: 1_741_380_835, nanoseconds: 0),
      "plus10seconds": Timestamp(seconds: 1_741_380_245, nanoseconds: 0),
      "plus10micros": Timestamp(seconds: 1_741_380_235, nanoseconds: 10000),
      "plus10millis": Timestamp(seconds: 1_741_380_235, nanoseconds: 10_000_000),
      "plus10daysExprUnitSendable": Timestamp(seconds: 1_742_244_235, nanoseconds: 0),
      "minus10days": Timestamp(seconds: 1_740_516_235, nanoseconds: 0),
      "minus10hours": Timestamp(seconds: 1_741_344_235, nanoseconds: 0),
      "minus10minutes": Timestamp(seconds: 1_741_379_635, nanoseconds: 0),
      "minus10seconds": Timestamp(seconds: 1_741_380_225, nanoseconds: 0),
      "minus10micros": Timestamp(seconds: 1_741_380_234, nanoseconds: 999_990_000),
      "minus10millis": Timestamp(seconds: 1_741_380_234, nanoseconds: 990_000_000),
      "minus10daysExprUnitSendable": Timestamp(seconds: 1_740_516_235, nanoseconds: 0),
    ]

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")
    if let resultDoc = snapshot.results.first {
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResults)
    } else {
      XCTFail("No document retrieved for timestamp math test")
    }
  }

  func testTimestampTruncWorks() async throws {
    try XCTSkipIf(
      FSTIntegrationTestCase.isRunningAgainstEmulator(),
      "Emulator does not support this function."
    )

    let db = firestore()
    let randomCol = collectionRef()
    try await randomCol.document("dummyDoc").setData(["field": "value"])

    let baseTimestamp = Timestamp(seconds: 1_741_380_235, nanoseconds: 123_456_000)

    let pipeline = db.pipeline()
      .collection(randomCol.path)
      .limit(1)
      .select(
        [
          Constant(baseTimestamp).timestampTruncate(granularity: .microsecond).as("truncMicro"),
          Constant(baseTimestamp).timestampTruncate(granularity: .millisecond).as("truncMilli"),
          Constant(baseTimestamp).timestampTruncate(granularity: .second).as("truncSecond"),
          Constant(baseTimestamp).timestampTruncate(granularity: .minute).as("truncMinute"),
          Constant(baseTimestamp).timestampTruncate(granularity: .hour).as("truncHour"),
          Constant(baseTimestamp).timestampTruncate(granularity: .day).as("truncDay"),
          Constant(baseTimestamp).timestampTruncate(granularity: .week).as("truncWeek"),
          Constant(baseTimestamp).timestampTruncate(granularity: .weekMonday).as("truncWeekMonday"),
          Constant(baseTimestamp).timestampTruncate(granularity: .weekTuesday)
            .as("truncWeekTuesday"),
          Constant(baseTimestamp).timestampTruncate(granularity: .isoweek).as("truncIsoWeek"),
          Constant(baseTimestamp).timestampTruncate(granularity: .month).as("truncMonth"),
          Constant(baseTimestamp).timestampTruncate(granularity: .quarter).as("truncQuarter"),
          Constant(baseTimestamp).timestampTruncate(granularity: .year).as("truncYear"),
          Constant(baseTimestamp).timestampTruncate(granularity: .isoyear).as("truncIsoYear"),
          Constant(baseTimestamp).timestampTruncate(granularity: "day").as("truncDayString"),
          Constant(baseTimestamp).timestampTruncate(granularity: Constant("day"))
            .as("truncDayExpr"),
        ]
      )

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")

    let expectedResults: [String: Timestamp] = [
      "truncMicro": Timestamp(seconds: 1_741_380_235, nanoseconds: 123_456_000),
      "truncMilli": Timestamp(seconds: 1_741_380_235, nanoseconds: 123_000_000),
      "truncSecond": Timestamp(seconds: 1_741_380_235, nanoseconds: 0),
      "truncMinute": Timestamp(seconds: 1_741_380_180, nanoseconds: 0),
      "truncHour": Timestamp(seconds: 1_741_377_600, nanoseconds: 0),
      "truncDay": Timestamp(seconds: 1_741_305_600, nanoseconds: 0),
      "truncWeek": Timestamp(seconds: 1_740_873_600, nanoseconds: 0),
      "truncWeekMonday": Timestamp(seconds: 1_740_960_000, nanoseconds: 0),
      "truncWeekTuesday": Timestamp(seconds: 1_741_046_400, nanoseconds: 0),
      "truncIsoWeek": Timestamp(seconds: 1_740_960_000, nanoseconds: 0),
      "truncMonth": Timestamp(seconds: 1_740_787_200, nanoseconds: 0),
      "truncQuarter": Timestamp(seconds: 1_735_689_600, nanoseconds: 0),
      "truncYear": Timestamp(seconds: 1_735_689_600, nanoseconds: 0),
      "truncIsoYear": Timestamp(seconds: 1_735_516_800, nanoseconds: 0),
      "truncDayString": Timestamp(seconds: 1_741_305_600, nanoseconds: 0),
      "truncDayExpr": Timestamp(seconds: 1_741_305_600, nanoseconds: 0),
    ]

    if let resultDoc = snapshot.results.first {
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResults)
    } else {
      XCTFail("No document retrieved for timestamp trunc test")
    }
  }

  func testCurrentTimestampWorks() async throws {
    let collRef = collectionRef(withDocuments: ["doc1": ["foo": 1]])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        CurrentTimestamp().as("timestamp"),
      ])

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1)
  }

  func testErrorExpressionWorks() async throws {
    let collRef = collectionRef(withDocuments: ["doc1": ["foo": 1]])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        ErrorExpression("This is a test error").as("error"),
      ])

    do {
      let _ = try await pipeline.execute()
      XCTFail("The pipeline should have thrown an error, but it did not.")
    } catch {
      XCTAssert(true, "Successfully caught expected error from ErrorExpression.")
    }
  }

  func testSupportsByteLength() async throws {
    let db = firestore()
    let randomCol = collectionRef()
    try await randomCol.document("dummyDoc").setData(["field": "value"])

    let bytes = Data([1, 2, 3, 4, 5, 6, 7, 0])

    let pipeline = db.pipeline()
      .collection(randomCol.path)
      .limit(1)
      .select(
        [
          Constant(bytes).as("bytes"),
        ]
      )
      .select(
        [
          Field("bytes").byteLength().as("byteLength"),
        ]
      )

    let snapshot = try await pipeline.execute()

    let expectedResults: [String: Sendable] = [
      "byteLength": 8,
    ]

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")
    if let resultDoc = snapshot.results.first {
      TestHelper.compare(
        pipelineResult: resultDoc,
        expected: expectedResults.mapValues { $0 as Sendable }
      )
    } else {
      XCTFail("No document retrieved for byte length test")
    }
  }

  func testSupportsNot() async throws {
    let db = firestore()
    let randomCol = collectionRef()
    try await randomCol.document("dummyDoc").setData(["field": "value"])

    let pipeline = db.pipeline()
      .collection(randomCol.path)
      .limit(1)
      .select([Constant(true).as("trueField")])
      .select(
        [
          Field("trueField"),
          (!(Field("trueField").equal(true))).as("falseField"),
        ]
      )

    let snapshot = try await pipeline.execute()

    let expectedResults: [String: Bool] = [
      "trueField": true,
      "falseField": false,
    ]

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")
    if let resultDoc = snapshot.results.first {
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResults)
    } else {
      XCTFail("No document retrieved for not operator test")
    }
  }

  func testDocumentId() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("rating").descending()])
      .limit(1)
      .select([Field(FieldPath.documentID()).documentId().as("docId")])
    let snapshot = try await pipeline.execute()
    TestHelper.compare(
      snapshot: snapshot,
      expected: [["docId": "book4"]],
      enforceOrder: false
    )
  }

  func testSubstring() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("rating").descending()])
      .limit(1)
      .select([Field("title").substring(position: 9, length: 2).as("of")])
    let snapshot = try await pipeline.execute()
    TestHelper.compare(snapshot: snapshot, expected: [["of": "of"]], enforceOrder: false)
  }

  func testSubstringWithoutLength() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field("rating").descending()])
      .limit(1)
      .select([Field("title").substring(position: 9).as("of")])
    let snapshot = try await pipeline.execute()
    TestHelper.compare(
      snapshot: snapshot,
      expected: [["of": "of the Rings"]],
      enforceOrder: false
    )
  }

  func testArrayConcat() async throws {
    let stringArrayDocs = [
      "doc1": ["tags": ["a", "b"], "more_tags": ["c", "d"]],
      "doc2": ["tags": ["e", "f"], "more_tags": ["g", "h"]],
    ]

    let numberArrayDocs = [
      "doc1": ["tags": [1, 2], "more_tags": [3, 4]],
      "doc2": ["tags": [5, 6], "more_tags": [7, 8]],
    ]

    let stringCollRef = collectionRef(withDocuments: stringArrayDocs)
    let numberCollRef = collectionRef(withDocuments: numberArrayDocs)
    let db = stringCollRef.firestore

    // Test case 1: Concatenating string arrays.
    let stringPipeline = db.pipeline()
      .collection(stringCollRef.path)
      .select([
        Field("tags").arrayConcat([Field("more_tags"), ArrayExpression(["i", "j"])])
          .as("concatenatedTags"),
      ])

    let stringSnapshot = try await stringPipeline.execute()

    let expectedStringResults: [[String: Sendable]] = [
      ["concatenatedTags": ["a", "b", "c", "d", "i", "j"]],
      ["concatenatedTags": ["e", "f", "g", "h", "i", "j"]],
    ]

    TestHelper.compare(
      snapshot: stringSnapshot,
      expected: expectedStringResults,
      enforceOrder: false
    )

    // Test case 2: Concatenating number arrays.
    let numberPipeline = db.pipeline()
      .collection(numberCollRef.path)
      .select([
        Field("tags").arrayConcat([Field("more_tags"), ArrayExpression([9, 10])])
          .as("concatenatedTags"),
      ])

    let numberSnapshot = try await numberPipeline.execute()

    let expectedNumberResults: [[String: Sendable]] = [
      ["concatenatedTags": [1, 2, 3, 4, 9, 10]],
      ["concatenatedTags": [5, 6, 7, 8, 9, 10]],
    ]

    TestHelper.compare(
      snapshot: numberSnapshot,
      expected: expectedNumberResults,
      enforceOrder: false
    )

    // Test case 3: Mix string and number arrays.
    let mixPipeline = db.pipeline()
      .collection(numberCollRef.path)
      .select([
        Field("tags").arrayConcat([Field("more_tags"), ArrayExpression(["i", "j"])])
          .as("concatenatedTags"),
      ])

    let mixSnapshot = try await mixPipeline.execute()

    let expectedMixResults: [[String: Sendable]] = [
      ["concatenatedTags": [1, 2, 3, 4, "i", "j"]],
      ["concatenatedTags": [5, 6, 7, 8, "i", "j"]],
    ]

    TestHelper.compare(snapshot: mixSnapshot, expected: expectedMixResults, enforceOrder: false)
  }

  func testToLower() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["title": "The Hitchhiker's Guide to the Galaxy"],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([Field("title").toLower().as("lowercaseTitle")])
    let snapshot = try await pipeline.execute()
    TestHelper.compare(
      snapshot: snapshot,
      expected: [["lowercaseTitle": "the hitchhiker's guide to the galaxy"]],
      enforceOrder: false
    )
  }

  func testToUpper() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["author": "Douglas Adams"],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([Field("author").toUpper().as("uppercaseAuthor")])
    let snapshot = try await pipeline.execute()
    TestHelper.compare(
      snapshot: snapshot,
      expected: [["uppercaseAuthor": "DOUGLAS ADAMS"]],
      enforceOrder: false
    )
  }

  func testTrimCharactersWithStringLiteral() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .addFields([Constant("---Hello World---").as("paddedString")])
      .select([Field("paddedString").trim("-").as("trimmedString")])
      .limit(1)
    let snapshot = try await pipeline.execute()
    TestHelper.compare(
      snapshot: snapshot,
      expected: [[
        "trimmedString": "Hello World",
      ]],
      enforceOrder: false
    )
  }

  func testTrimCharactersWithExpression() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .addFields([Constant("---Hello World---").as("paddedString"), Constant("-").as("trimChar")])
      .select([Field("paddedString").trim(Field("trimChar")).as("trimmedString")])
      .limit(1)
    let snapshot = try await pipeline.execute()
    TestHelper.compare(
      snapshot: snapshot,
      expected: [[
        "trimmedString": "Hello World",
      ]],
      enforceOrder: false
    )
  }

  func testSplitWorks() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["text": "a-b-c"],
      "doc2": ["text": "x,y,z", "delimiter": ","],
      "doc3": ["text": Data([0x61, 0x00, 0x62, 0x00, 0x63]), "delimiter": Data([0x00])],
    ])
    let db = collRef.firestore

    // Test with string literal delimiter
    var pipeline = db.pipeline()
      .documents([collRef.document("doc1").path])
      .select([
        Field("text").split(delimiter: "-").as("split_text"),
      ])
    var snapshot = try await pipeline.execute()

    var expectedResults: [[String: Sendable]] = [
      ["split_text": ["a", "b", "c"]],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: false)

    // Test with expression delimiter (string)
    pipeline = db.pipeline()
      .documents([collRef.document("doc2").path])
      .select([
        Field("text").split(delimiter: Field("delimiter")).as("split_text"),
      ])
    snapshot = try await pipeline.execute()

    expectedResults = [
      ["split_text": ["x", "y", "z"]],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: false)

    // Test with expression delimiter (bytes)
    pipeline = db.pipeline()
      .documents([collRef.document("doc3").path])
      .select([
        Field("text").split(delimiter: Field("delimiter")).as("split_text"),
      ])
    snapshot = try await pipeline.execute()

    let expectedByteResults: [[String: Sendable]] = [
      ["split_text": [Data([0x61]), Data([0x62]), Data([0x63])]],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedByteResults, enforceOrder: false)
  }

  func testTrimWorksWithoutArguments() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["text": "  hello world  "],
      "doc2": ["text": "\t\tFirebase\n\n"],
      "doc3": ["text": "no_whitespace"],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("text").trim().as("trimmedText"),
      ])
      .sort([Field("trimmedText").ascending()])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["trimmedText": "Firebase"],
      ["trimmedText": "hello world"],
      ["trimmedText": "no_whitespace"],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testArrayMaxMinWorks() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["scores": [10, 20, 5]],
      "doc2": ["scores": [-1, -5, 0]],
      "doc3": ["scores": [100.5, 99.5, 100.6]],
      "doc4": ["scores": []],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort([Field(FieldPath.documentID()).ascending()])
      .select([
        Field("scores").arrayMaximum().as("maxScore"),
        Field("scores").arrayMinimum().as("minScore"),
      ])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable?]] = [
      ["maxScore": 20, "minScore": 5],
      ["maxScore": 0, "minScore": -5],
      ["maxScore": 100.6, "minScore": 99.5],
      ["maxScore": nil, "minScore": nil],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testTypeWorks() async throws {
    try XCTSkipIf(
      FSTIntegrationTestCase.isRunningAgainstEmulator(),
      "Skipping test because the emulator's behavior deviates from the expected outcome."
    )

    let collRef = collectionRef(withDocuments: [
      "doc1": [
        "a": 1,
        "b": "hello",
        "c": true,
        "d": [1, 2],
        "e": ["f": "g"],
        "f": GeoPoint(latitude: 1, longitude: 2),
        "g": Timestamp(date: Date()),
        "h": Data([1, 2, 3]),
        "i": NSNull(),
        "j": Double.nan,
      ],
    ])
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select([
        Field("a").type().as("type_a"),
        Field("b").type().as("type_b"),
        Field("c").type().as("type_c"),
        Field("d").type().as("type_d"),
        Field("e").type().as("type_e"),
        Field("f").type().as("type_f"),
        Field("g").type().as("type_g"),
        Field("h").type().as("type_h"),
        Field("i").type().as("type_i"),
        Field("j").type().as("type_j"),
      ])

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      [
        "type_a": "int64",
        "type_b": "string",
        "type_c": "boolean",
        "type_d": "array",
        "type_e": "map",
        "type_f": "geo_point",
        "type_g": "timestamp",
        "type_h": "bytes",
        "type_i": "null",
        "type_j": "float64",
      ],
    ]

    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: false)
  }

  func testAggregateThrowsOnDuplicateAliases() async throws {
    let collRef = collectionRef()
    let pipeline = db.pipeline()
      .collection(collRef.path)
      .aggregate([
        CountAll().as("count"),
        Field("foo").count().as("count"),
      ])

    do {
      _ = try await pipeline.execute()
      XCTFail("Should have thrown an error")
    } catch {
      XCTAssert(error.localizedDescription.contains("Duplicate alias 'count'"))
    }
  }

  func testAggregateThrowsOnDuplicateGroupAliases() async throws {
    let collRef = collectionRef()
    let pipeline = db.pipeline()
      .collection(collRef.path)
      .aggregate(
        [CountAll().as("count")],
        groups: [Field("bax"), Field("bar").as("bax")]
      )

    do {
      _ = try await pipeline.execute()
      XCTFail("Should have thrown an error")
    } catch {
      XCTAssert(error.localizedDescription.contains("Duplicate alias 'bax'"))
    }
  }

  func testDuplicateAliasInAddFields() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select(["title", "author"])
      .addFields([
        Constant("bar").as("foo"),
        Constant("baz").as("foo"),
      ])
      .sort([Field("author").ascending()])

    do {
      _ = try await pipeline.execute()
      XCTFail("Should have thrown an error")
    } catch {
      XCTAssert(error.localizedDescription.contains("Duplicate alias 'foo'"))
    }
  }

  // MARK: - Pagination Tests

  private var addedDocs: [DocumentReference] = []

  private func addBooks(to collectionReference: CollectionReference) async throws {
    var newDocs: [DocumentReference] = []
    var docRef = collectionReference.document("book11")
    newDocs.append(docRef)
    try await docRef.setData([
      "title": "Jonathan Strange & Mr Norrell",
      "author": "Susanna Clarke",
      "genre": "Fantasy",
      "published": 2004,
      "rating": 4.6,
      "tags": ["historical fantasy", "magic", "alternate history", "england"],
      "awards": ["hugo": false, "nebula": false],
    ])

    docRef = collectionReference.document("book12")
    newDocs.append(docRef)
    try await docRef.setData([
      "title": "The Master and Margarita",
      "author": "Mikhail Bulgakov",
      "genre": "Satire",
      "published": 1967, // Though written much earlier
      "rating": 4.6,
      "tags": ["russian literature", "supernatural", "philosophy", "dark comedy"],
      "awards": [:],
    ])

    docRef = collectionReference.document("book13")
    newDocs.append(docRef)
    try await docRef.setData([
      "title": "A Long Way to a Small, Angry Planet",
      "author": "Becky Chambers",
      "genre": "Science Fiction",
      "published": 2014,
      "rating": 4.6,
      "tags": ["space opera", "found family", "character-driven", "optimistic"],
      "awards": ["hugo": false, "nebula": false, "kitschies": true],
    ])
    addedDocs.append(contentsOf: newDocs)
  }

  func testPaginationWithFilters() async throws {
    let randomCol = collectionRef(withDocuments: bookDocs)
    try await addBooks(to: randomCol)

    let pageSize = 2
    let pipeline = randomCol.firestore.pipeline()
      .collection(randomCol.path)
      .select(["title", "rating", "__name__"])
      .sort([Field("rating").descending(), Field("__name__").ascending()])

    var snapshot = try await pipeline.limit(Int32(pageSize)).execute()
    var expectedResults: [[String: Sendable]] = [
      ["title": "The Lord of the Rings", "rating": 4.7],
      ["title": "Dune", "rating": 4.6],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)

    let lastDoc = snapshot.results.last!
    let lastRating = lastDoc.get("rating")!

    snapshot = try await pipeline
      .where(
        (Field("rating").equal(lastRating)
          && Field("__name__").greaterThan(lastDoc.ref!))
          || Field("rating").lessThan(lastRating)
      )
      .limit(Int32(pageSize))
      .execute()

    expectedResults = [
      ["title": "Jonathan Strange & Mr Norrell", "rating": 4.6],
      ["title": "The Master and Margarita", "rating": 4.6],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testPaginationWithOffsets() async throws {
    let randomCol = collectionRef(withDocuments: bookDocs)
    try await addBooks(to: randomCol)

    let secondFilterField = "__name__"

    let pipeline = randomCol.firestore.pipeline()
      .collection(randomCol.path)
      .select(["title", "rating", secondFilterField])
      .sort([
        Field("rating").descending(),
        Field(secondFilterField).ascending(),
      ])

    let pageSize = 2
    var currPage = 0

    var snapshot = try await pipeline.offset(Int32(currPage * pageSize)).limit(Int32(pageSize))
      .execute()
    var expectedResults: [[String: Sendable]] = [
      ["title": "The Lord of the Rings", "rating": 4.7],
      ["title": "Dune", "rating": 4.6],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)

    currPage += 1
    snapshot = try await pipeline.offset(Int32(currPage * pageSize)).limit(Int32(pageSize))
      .execute()
    expectedResults = [
      ["title": "Jonathan Strange & Mr Norrell", "rating": 4.6],
      ["title": "The Master and Margarita", "rating": 4.6],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)

    currPage += 1
    snapshot = try await pipeline.offset(Int32(currPage * pageSize)).limit(Int32(pageSize))
      .execute()
    expectedResults = [
      ["title": "A Long Way to a Small, Angry Planet", "rating": 4.6],
      ["title": "Pride and Prejudice", "rating": 4.5],
    ]
    TestHelper.compare(snapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testFieldAndConstantAsBooleanExpression() async throws {
    let collRef = collectionRef(withDocuments: [
      "doc1": ["a": true],
      "doc2": ["a": false],
      "doc3": ["b": true],
    ])
    let db = collRef.firestore

    var pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("a").asBoolean())
    var snapshot = try await pipeline.execute()
    TestHelper.compare(snapshot: snapshot, expectedIDs: ["doc1"], enforceOrder: false)

    pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Constant(true).asBoolean())
    snapshot = try await pipeline.execute()
    TestHelper.compare(
      snapshot: snapshot,
      expectedIDs: ["doc1", "doc2", "doc3"],
      enforceOrder: false
    )

    pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Constant(false).asBoolean())
    snapshot = try await pipeline.execute()
    TestHelper.compare(snapshot: snapshot, expectedCount: 0)
  }
}
