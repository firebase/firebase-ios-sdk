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

    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: expectedResultsMap)
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
}
