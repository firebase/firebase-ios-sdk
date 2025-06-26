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

    TestHelper.compare(pipelineSnapshot: snapshot, expectedCount: 0)
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

    TestHelper.compare(pipelineSnapshot: snapshot, expectedIDs: [
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

    TestHelper.compare(pipelineSnapshot: snapshot, expectedCount: 0)

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

    TestHelper.compare(pipelineSnapshot: snapshot, expectedCount: bookDocs.count)
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
        pipelineSnapshot: snapshot,
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
        pipelineSnapshot: snapshot,
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
      .sort(Field("order").ascending())

    let snapshot = try await pipeline.execute()

    // Assert that only the two documents from the targeted subCollectionId are fetched, in the
    // correct order.
    TestHelper
      .compare(
        pipelineSnapshot: snapshot,
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
    TestHelper
      .compare(
        pipelineSnapshot: snapshot,
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
      .aggregate(CountAll().as("count"))
    var snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Count all should return a single aggregate document")
    if let result = snapshot.results.first {
      TestHelper.compare(pipelineResult: result, expected: ["count": bookDocs.count])
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

    TestHelper
      .compare(pipelineSnapshot: snapshot, expected: expectedResultsArray, enforceOrder: true)
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
      TestHelper.compare(pipelineResult: result, expected: expectedValues)
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

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
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

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
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

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
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

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
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
    TestHelper.compare(pipelineSnapshot: snapshot, expectedIDs: expectedIDs, enforceOrder: false)

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
    TestHelper.compare(pipelineSnapshot: snapshot, expectedIDs: expectedIDs, enforceOrder: false)
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
    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)

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
    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
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
    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
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
      .sort(Field("title").ascending())
      .limit(1)

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")
    TestHelper.compare(
      pipelineSnapshot: snapshot,
      expected: [expectedSelectedData],
      enforceOrder: true
    )
  }

  func testCanAddFields() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort(Field("author").ascending())
      .limit(1)
      .select("title", "author")
      .rawStage(
        name: "add_fields",
        params: [
          [
            "display": Field("title").strConcat(
              Constant(" - "),
              Field("author")
            ),
          ],
        ]
      )

    let snapshot = try await pipeline.execute()

    TestHelper.compare(
      pipelineSnapshot: snapshot,
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
      .select("title", "author", "rating")
      .rawStage(
        name: "distinct",
        params: [
          ["rating": Field("rating")],
        ]
      )
      .sort(Field("rating").descending())

    let snapshot = try await pipeline.execute()

    TestHelper.compare(
      pipelineSnapshot: snapshot,
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
      .select("title", "author", "rating")
      .rawStage(
        name: "aggregate",
        params: [
          [
            "averageRating": Field("rating").avg(),
          ],
          emptySendableDictionary,
        ]
      )

    let snapshot = try await pipeline.execute()

    TestHelper.compare(
      pipelineSnapshot: snapshot,
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
      .select("title", "author")
      .rawStage(
        name: "where",
        params: [Field("author").eq("Douglas Adams")]
      )

    let snapshot = try await pipeline.execute()

    TestHelper.compare(
      pipelineSnapshot: snapshot,
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
      .select("title", "author")
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
      pipelineSnapshot: snapshot,
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
      .where(Field("title").eq("The Hitchhiker's Guide to the Galaxy"))
      .replace(with: "awards")

    let snapshot = try await pipeline.execute()

    TestHelper.compare(pipelineSnapshot: snapshot, expectedCount: 1)

    let expectedBook1Transformed: [String: Sendable?] = [
      "hugo": true,
      "nebula": false,
      "others": ["unknown": ["year": 1980]],
    ]

    TestHelper
      .compare(
        pipelineSnapshot: snapshot,
        expected: [expectedBook1Transformed],
        enforceOrder: false
      )
  }

  func testReplaceWithExprResult() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").eq("The Hitchhiker's Guide to the Galaxy"))
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

    TestHelper.compare(pipelineSnapshot: snapshot, expected: [expectedResults], enforceOrder: false)
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
      .compare(pipelineSnapshot: snapshot, expectedCount: 3)
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
      .union(db.pipeline()
        .collection(collRef.path))

    let snapshot = try await pipeline.execute()

    let bookSequence = (1 ... 10).map { "book\($0)" }
    let repeatedIDs = bookSequence + bookSequence
    TestHelper.compare(pipelineSnapshot: snapshot, expectedIDs: repeatedIDs, enforceOrder: false)
  }

  func testUnnestStage() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").eq("The Hitchhiker's Guide to the Galaxy"))
      .unnest(Field("tags").as("tag"), indexField: "tagsIndex")
      .select(
        "title",
        "author",
        "genre",
        "published",
        "rating",
        "tags",
        "tag",
        "awards",
        "nestedField"
      )

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

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: false)
  }

  func testUnnestExpr() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").eq("The Hitchhiker's Guide to the Galaxy"))
      .unnest(ArrayExpression([1, 2, 3]).as("copy"))
      .select(
        "title",
        "author",
        "genre",
        "published",
        "rating",
        "tags",
        "copy",
        "awards",
        "nestedField"
      )

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

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: false)
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
          vectorValue: [10, 1, 3, 1, 2, 1, 1, 1, 1, 1],
          distanceMeasure: measure, limit: 3
        )
        .select("title")
      let snapshot = try await pipeline.execute()
      TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
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
        vectorValue: [10, 1, 2, 1, 1, 1, 1, 1, 1, 1],
        distanceMeasure: .euclidean, limit: 2,
        distanceField: "computedDistance"
      )
      .select("title", "computedDistance")
    let snapshot = try await pipeline.execute()
    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: false)
  }

  func testLogicalMaxWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select(
        Field("title"),
        Field("published").logicalMaximum(Constant(1960), 1961).as("published-safe")
      )
      .sort(Field("title").ascending())
      .limit(3)

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "1984", "published-safe": 1961],
      ["title": "Crime and Punishment", "published-safe": 1961],
      ["title": "Dune", "published-safe": 1965],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testLogicalMinWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select(
        Field("title"),
        Field("published").logicalMinimum(Constant(1960), 1961).as("published-safe")
      )
      .sort(Field("title").ascending())
      .limit(3)

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "1984", "published-safe": 1949],
      ["title": "Crime and Punishment", "published-safe": 1866],
      ["title": "Dune", "published-safe": 1960],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testCondWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select(
        Field("title"),
        Field("published").lt(1960).then(Constant(1960), else: Field("published"))
          .as("published-safe")
      )
      .sort(Field("title").ascending())
      .limit(3)

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "1984", "published-safe": 1960],
      ["title": "Crime and Punishment", "published-safe": 1960],
      ["title": "Dune", "published-safe": 1965],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testEqAnyWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("published").eqAny([1979, 1999, 1967]))
      .sort(Field("title").descending())
      .select("title")

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy"],
      ["title": "One Hundred Years of Solitude"],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testNotEqAnyWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("published").notEqAny([1965, 1925, 1949, 1960, 1866, 1985, 1954, 1967, 1979]))
      .select("title")

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "Pride and Prejudice"],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: false)
  }

  func testArrayContainsWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("tags").arrayContains("comedy"))
      .select("title")

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy"],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: false)
  }

  func testArrayContainsAnyWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("tags").arrayContainsAny(["comedy", "classic"]))
      .sort(Field("title").descending())
      .select("title")

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy"],
      ["title": "Pride and Prejudice"],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testArrayContainsAllWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("tags").arrayContainsAll(["adventure", "magic"]))
      .select("title")

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Lord of the Rings"],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: false)
  }

  func testArrayLengthWorks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select(Field("tags").arrayLength().as("tagsCount"))
      .where(Field("tagsCount").eq(3))

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 10)
  }

  func testStrConcat() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort(Field("author").ascending())
      .select(Field("author").strConcat(Constant(" - "), Field("title")).as("bookInfo"))
      .limit(1)

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["bookInfo": "Douglas Adams - The Hitchhiker's Guide to the Galaxy"],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testStartsWith() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").startsWith("The"))
      .select("title")
      .sort(Field("title").ascending())

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Great Gatsby"],
      ["title": "The Handmaid's Tale"],
      ["title": "The Hitchhiker's Guide to the Galaxy"],
      ["title": "The Lord of the Rings"],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testEndsWith() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").endsWith("y"))
      .select("title")
      .sort(Field("title").descending())

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy"],
      ["title": "The Great Gatsby"],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testStrContains() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").strContains("'s"))
      .select("title")
      .sort(Field("title").ascending())

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Handmaid's Tale"],
      ["title": "The Hitchhiker's Guide to the Galaxy"],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testCharLength() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .select(
        Field("title").charLength().as("titleLength"),
        Field("title")
      )
      .where(Field("titleLength").gt(20))
      .sort(Field("title").ascending())

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["titleLength": 29, "title": "One Hundred Years of Solitude"],
      ["titleLength": 36, "title": "The Hitchhiker's Guide to the Galaxy"],
      ["titleLength": 21, "title": "The Lord of the Rings"],
      ["titleLength": 21, "title": "To Kill a Mockingbird"],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testLike() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").like("%Guide%"))
      .select("title")

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy"],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: false)
  }

  func testRegexContains() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("title").regexContains("(?i)(the|of)"))

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 5)
  }

  func testRegexMatches() async throws {
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
      .where(Field("title").eq("To Kill a Mockingbird"))
      .select(
        Field("rating").add(1).as("ratingPlusOne"),
        Field("published").subtract(1900).as("yearsSince1900"),
        Field("rating").multiply(10).as("ratingTimesTen"),
        Field("rating").divide(2).as("ratingDividedByTwo"),
        Field("rating").multiply(20).as("ratingTimes20"),
        Field("rating").add(3).as("ratingPlus3"),
        Field("rating").mod(2).as("ratingMod2")
      )
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

  func testComparisonOperators() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(
        Field("rating").gt(4.2) &&
          Field("rating").lte(4.5) &&
          Field("genre").neq("Science Fiction")
      )
      .select("rating", "title")
      .sort(Field("title").ascending())

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["rating": 4.3, "title": "Crime and Punishment"],
      ["rating": 4.3, "title": "One Hundred Years of Solitude"],
      ["rating": 4.5, "title": "Pride and Prejudice"],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testLogicalOperators() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(
        (Field("rating").gt(4.5) && Field("genre").eq("Science Fiction")) ||
          Field("published").lt(1900)
      )
      .select("title")
      .sort(Field("title").ascending())

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable]] = [
      ["title": "Crime and Punishment"],
      ["title": "Dune"],
      ["title": "Pride and Prejudice"],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testChecks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    // Part 1
    var pipeline = db.pipeline()
      .collection(collRef.path)
      .sort(Field("rating").descending())
      .limit(1)
      .select(
        Field("rating").isNull().as("ratingIsNull"),
        Field("rating").isNan().as("ratingIsNaN"),
        Field("title").arrayOffset(0).isError().as("isError"),
        Field("title").arrayOffset(0).ifError(Constant("was error")).as("ifError"),
        Field("foo").isAbsent().as("isAbsent"),
        Field("title").isNotNull().as("titleIsNotNull"),
        Field("cost").isNotNan().as("costIsNotNan"),
        Field("fooBarBaz").exists().as("fooBarBazExists"),
        Field("title").exists().as("titleExists")
      )

    var snapshot = try await pipeline.execute()
    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document for checks part 1")

    if let resultDoc = snapshot.results.first {
      let expectedResults: [String: Sendable?] = [
        "ratingIsNull": false,
        "ratingIsNaN": false,
        "isError": true,
        "ifError": "was error",
        "isAbsent": true,
        "titleIsNotNull": true,
        "costIsNotNan": false,
        "fooBarBazExists": false,
        "titleExists": true,
      ]
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResults)
    } else {
      XCTFail("No document retrieved for checks part 1")
    }

    // Part 2
    pipeline = db.pipeline()
      .collection(collRef.path)
      .sort(Field("rating").descending())
      .limit(1)
      .select(
        Field("rating").isNull().as("ratingIsNull"),
        Field("rating").isNan().as("ratingIsNaN"),
        Field("title").arrayOffset(0).isError().as("isError"),
        Field("title").arrayOffset(0).ifError(Constant("was error")).as("ifError"),
        Field("foo").isAbsent().as("isAbsent"),
        Field("title").isNotNull().as("titleIsNotNull"),
        Field("cost").isNotNan().as("costIsNotNan")
      )

    snapshot = try await pipeline.execute()
    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document for checks part 2")

    if let resultDoc = snapshot.results.first {
      let expectedResults: [String: Sendable?] = [
        "ratingIsNull": false,
        "ratingIsNaN": false,
        "isError": true,
        "ifError": "was error",
        "isAbsent": true,
        "titleIsNotNull": true,
        "costIsNotNan": false,
      ]
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResults)
    } else {
      XCTFail("No document retrieved for checks part 2")
    }
  }

  func testMapGet() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort(Field("published").descending())
      .select(
        Field("awards").mapGet("hugo").as("hugoAward"),
        Field("awards").mapGet("others").as("others"),
        Field("title")
      )
      .where(Field("hugoAward").eq(true))

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
        "others": nil,
      ],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
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
        Constant(VectorValue(sourceVector)).cosineDistance(targetVectorValue).as("cosineDistance"),
        Constant(VectorValue(sourceVector)).dotProduct(targetVectorValue).as("dotProductDistance"),
        Constant(VectorValue(sourceVector)).euclideanDistance(targetVectorValue)
          .as("euclideanDistance")
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
      .select(Field("embedding").vectorLength().as("vectorLength"))

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
      .where(Field("awards.hugo").eq(true))
      .sort(Field("title").descending())
      .select(Field("title"), Field("awards.hugo"))

    let snapshot = try await pipeline.execute()

    let expectedResults: [[String: Sendable?]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy", "awards.hugo": true],
      ["title": "Dune", "awards.hugo": true],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testMapGetWithFieldNameIncludingDotNotation() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("awards.hugo").eq(true)) // Filters to book1 and book10
      .select(
        Field("title"),
        Field("nestedField.level.1"),
        Field("nestedField").mapGet("level.1").mapGet("level.2").as("nested")
      )
      .sort(Field("title").descending())

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 2, "Should retrieve two documents")

    let expectedResultsArray: [[String: Sendable?]] = [
      [
        "title": "The Hitchhiker's Guide to the Galaxy",
        "nestedField.level.`1`": nil,
        "nested": true,
      ],
      [
        "title": "Dune",
        "nestedField.level.`1`": nil,
        "nested": nil,
      ],
    ]
    TestHelper.compare(
      pipelineSnapshot: snapshot,
      expected: expectedResultsArray,
      enforceOrder: true
    )
  }

  func testGenericFunctionAddSelectable() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort(Field("rating").descending())
      .limit(1)
      .select(
        FunctionExpr("add", [Field("rating"), Constant(1)]).as(
          "rating"
        )
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
        BooleanExpr("and", [Field("rating").gt(0),
                            Field("title").charLength().lt(5),
                            Field("tags").arrayContains("propaganda")])
      )
      .select("title")

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")

    let expectedResult: [[String: Sendable?]] = [
      ["title": "1984"],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResult, enforceOrder: false)
  }

  func testGenericFunctionArrayContainsAny() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(BooleanExpr("array_contains_any", [Field("tags"), ArrayExpression(["politics"])]))
      .select(Field("title"))

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")

    let expectedResult: [[String: Sendable?]] = [
      ["title": "Dune"],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResult, enforceOrder: false)
  }

  func testGenericFunctionCountIfAggregate() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .aggregate(AggregateFunction("count_if", [Field("rating").gte(4.5)]).as("countOfBest"))

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
        FunctionExpr("char_length", [Field("title")]).ascending(),
        Field("__name__").descending()
      )
      .limit(3)
      .select(Field("title"))

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 3, "Should retrieve three documents")

    let expectedResults: [[String: Sendable?]] = [
      ["title": "1984"],
      ["title": "Dune"],
      ["title": "The Great Gatsby"],
    ]

    TestHelper.compare(pipelineSnapshot: snapshot, expected: expectedResults, enforceOrder: true)
  }

  func testSupportsRand() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .limit(10)
      .select(RandomExpr().as("result"))

    let snapshot = try await pipeline.execute()

    XCTAssertEqual(snapshot.results.count, 10, "Should fetch 10 documents")

    for doc in snapshot.results {
      guard let resultValue = doc.get("result") else {
        XCTFail("Document \(doc.id ?? "unknown") should have a 'result' field")
        continue
      }
      guard let doubleValue = resultValue as? Double else {
        XCTFail("Result value for document \(doc.id ?? "unknown") is not a Double: \(resultValue)")
        continue
      }
      XCTAssertGreaterThanOrEqual(
        doubleValue,
        0.0,
        "Result for \(doc.id ?? "unknown") should be >= 0.0"
      )
      XCTAssertLessThan(doubleValue, 1.0, "Result for \(doc.id ?? "unknown") should be < 1.0")
    }
  }

  func testSupportsArray() async throws {
    let db = firestore()
    let collRef = collectionRef(withDocuments: bookDocs)

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort(Field("rating").descending())
      .limit(1)
      .select(ArrayExpression([1, 2, 3, 4]).as("metadata"))

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
      .sort(Field("rating").descending())
      .limit(1)
      .select(ArrayExpression([
        1,
        2,
        Field("genre"),
        Field("rating").multiply(10),
      ]).as("metadata"))

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
      ["firstTag": "adventure"], // book4 (rating 4.7)
      ["firstTag": "politics"], // book10 (rating 4.6)
      ["firstTag": "classic"], // book2 (rating 4.5)
    ]

    // Part 1: Using arrayOffset as FunctionExpr("array_offset", ...)
    // (Assuming direct top-level ArrayOffset() isn't available, as per Expr.swift structure)
    let pipeline1 = db.pipeline()
      .collection(collRef.path)
      .sort(Field("rating").descending())
      .limit(3)
      .select(Field("tags").arrayOffset(0).as("firstTag"))

    let snapshot1 = try await pipeline1.execute()
    XCTAssertEqual(snapshot1.results.count, 3, "Part 1: Should retrieve three documents")
    TestHelper.compare(
      pipelineSnapshot: snapshot1,
      expected: expectedResultsPart1,
      enforceOrder: true
    )
  }

  func testSupportsMap() async throws {
    let db = firestore()
    let collRef = collectionRef(withDocuments: bookDocs)

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort(Field("rating").descending())
      .limit(1)
      .select(MapExpression(["foo": "bar"]).as("metadata"))

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
      .sort(Field("rating").descending())
      .limit(1)
      .select(MapExpression([
        "genre": Field("genre"), // "Fantasy"
        "rating": Field("rating").multiply(10), // 4.7 * 10 = 47.0
      ]).as("metadata"))

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
      .sort(Field("rating").descending())
      .limit(1)
      .select(Field("awards").mapRemove("hugo").as("awards"))

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

    let expectedResult: [String: Sendable?] =
      ["awards": ["hugo": false, "nebula": false, "fakeAward": true]]
    let mergeMap: [String: Sendable] = ["fakeAward": true]

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .sort(Field("rating").descending())
      .limit(1)
      .select(Field("awards").mapMerge(mergeMap).as("awards"))

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
        Constant(1_741_380_235).unixSecondsToTimestamp().as("unixSecondsToTimestamp"),
        Constant(1_741_380_235_123).unixMillisToTimestamp().as("unixMillisToTimestamp"),
        Constant(1_741_380_235_123_456).unixMicrosToTimestamp().as("unixMicrosToTimestamp"),
        Constant(Timestamp(seconds: 1_741_380_235, nanoseconds: 123_456_789))
          .timestampToUnixSeconds().as("timestampToUnixSeconds"),
        Constant(Timestamp(seconds: 1_741_380_235, nanoseconds: 123_456_789))
          .timestampToUnixMillis().as("timestampToUnixMillis"),
        Constant(Timestamp(seconds: 1_741_380_235, nanoseconds: 123_456_789))
          .timestampToUnixMicros().as("timestampToUnixMicros")
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
        Constant(initialTimestamp).as("timestamp")
      )
      .select(
        Field("timestamp").timestampAdd(.day, 10).as("plus10days"),
        Field("timestamp").timestampAdd(.hour, 10).as("plus10hours"),
        Field("timestamp").timestampAdd(.minute, 10).as("plus10minutes"),
        Field("timestamp").timestampAdd(.second, 10).as("plus10seconds"),
        Field("timestamp").timestampAdd(.microsecond, 10).as("plus10micros"),
        Field("timestamp").timestampAdd(.millisecond, 10).as("plus10millis"),
        Field("timestamp").timestampSub(.day, 10).as("minus10days"),
        Field("timestamp").timestampSub(.hour, 10).as("minus10hours"),
        Field("timestamp").timestampSub(.minute, 10).as("minus10minutes"),
        Field("timestamp").timestampSub(.second, 10).as("minus10seconds"),
        Field("timestamp").timestampSub(.microsecond, 10).as("minus10micros"),
        Field("timestamp").timestampSub(.millisecond, 10).as("minus10millis")
      )

    let snapshot = try await pipeline.execute()

    let expectedResults: [String: Timestamp] = [
      "plus10days": Timestamp(seconds: 1_742_244_235, nanoseconds: 0),
      "plus10hours": Timestamp(seconds: 1_741_416_235, nanoseconds: 0),
      "plus10minutes": Timestamp(seconds: 1_741_380_835, nanoseconds: 0),
      "plus10seconds": Timestamp(seconds: 1_741_380_245, nanoseconds: 0),
      "plus10micros": Timestamp(seconds: 1_741_380_235, nanoseconds: 10000),
      "plus10millis": Timestamp(seconds: 1_741_380_235, nanoseconds: 10_000_000),
      "minus10days": Timestamp(seconds: 1_740_516_235, nanoseconds: 0),
      "minus10hours": Timestamp(seconds: 1_741_344_235, nanoseconds: 0),
      "minus10minutes": Timestamp(seconds: 1_741_379_635, nanoseconds: 0),
      "minus10seconds": Timestamp(seconds: 1_741_380_225, nanoseconds: 0),
      "minus10micros": Timestamp(seconds: 1_741_380_234, nanoseconds: 999_990_000),
      "minus10millis": Timestamp(seconds: 1_741_380_234, nanoseconds: 990_000_000),
    ]

    XCTAssertEqual(snapshot.results.count, 1, "Should retrieve one document")
    if let resultDoc = snapshot.results.first {
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedResults)
    } else {
      XCTFail("No document retrieved for timestamp math test")
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
        Constant(bytes).as("bytes")
      )
      .select(
        Field("bytes").byteLength().as("byteLength")
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
      .select(Constant(true).as("trueField"))
      .select(
        Field("trueField"),
        (!(Field("trueField").eq(true))).as("falseField")
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
}
