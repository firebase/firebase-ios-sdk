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
@testable import FirebaseFirestore
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
    "awards": ["hugo": true, "nebula": false],
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
    "embedding": VectorValue([1, 10, 1, 1, 1, 1, 1, 1, 1, 1]),
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
    "cost": Double.nan,
    "embedding": VectorValue([1, 1, 1, 10, 1, 1, 1, 1, 1, 1]),
  ],
  "book5": [
    "title": "The Handmaid's Tale",
    "author": "Margaret Atwood",
    "genre": "Dystopian",
    "published": 1985,
    "rating": 4.1,
    "tags": ["feminism", "totalitarianism", "resistance"],
    "awards": ["arthur c. clarke": true, "booker prize": false],
    "embedding": VectorValue([1, 1, 1, 1, 10, 1, 1, 1, 1, 1]),
  ],
  "book6": [
    "title": "Crime and Punishment",
    "author": "Fyodor Dostoevsky",
    "genre": "Psychological Thriller",
    "published": 1866,
    "rating": 4.3,
    "tags": ["philosophy", "crime", "redemption"],
    "awards": ["none": true],
    "embedding": VectorValue([1, 1, 1, 1, 1, 10, 1, 1, 1, 1]),
  ],
  "book7": [
    "title": "To Kill a Mockingbird",
    "author": "Harper Lee",
    "genre": "Southern Gothic",
    "published": 1960,
    "rating": 4.2,
    "tags": ["racism", "injustice", "coming-of-age"],
    "awards": ["pulitzer": true],
    "embedding": VectorValue([1, 1, 1, 1, 1, 1, 10, 1, 1, 1]),
  ],
  "book8": [
    "title": "1984",
    "author": "George Orwell",
    "genre": "Dystopian",
    "published": 1949,
    "rating": 4.2,
    "tags": ["surveillance", "totalitarianism", "propaganda"],
    "awards": ["prometheus": true],
    "embedding": VectorValue([1, 1, 1, 1, 1, 1, 1, 10, 1, 1]),
  ],
  "book9": [
    "title": "The Great Gatsby",
    "author": "F. Scott Fitzgerald",
    "genre": "Modernist",
    "published": 1925,
    "rating": 4.0,
    "tags": ["wealth", "american dream", "love"],
    "awards": ["none": true],
    "embedding": VectorValue([1, 1, 1, 1, 1, 1, 1, 1, 10, 1]),
  ],
  "book10": [
    "title": "Dune",
    "author": "Frank Herbert",
    "genre": "Science Fiction",
    "published": 1965,
    "rating": 4.6,
    "tags": ["politics", "desert", "ecology"],
    "awards": ["hugo": true, "nebula": true],
    "embedding": VectorValue([1, 1, 1, 1, 1, 1, 1, 1, 1, 10]),
  ],
  "book11": [
    "title": "Timestamp Book",
    "author": "Timestamp Author",
    "timestamp": Timestamp(date: Date()),
  ],
]

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class PipelineSubqueryTests: FSTIntegrationTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()
    if FSTIntegrationTestCase.backendEdition() == .standard {
      throw XCTSkip("Skip PipelineSubqueryTests on standard backend")
    }
  }

  func testZeroResultScalarReturnsNull() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "A Book Title"]]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let emptyScalar = db.pipeline()
      .collection(collRef.document("book1").collection("reviews").path)
      .where(Field("reviewer").equal("Alice"))
      .select([CurrentDocument().as("data")])

    let snapshot = try await db.pipeline()
      .collection(collRef.path)
      .select([emptyScalar.toScalarExpression().as("first_review_data")])
      .limit(1)
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    if let resultDoc = snapshot.results.first {
      TestHelper.compare(pipelineResult: resultDoc, expected: ["first_review_data": nil])
    }
  }

  func testArraySubqueryJoinAndEmptyResult() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore
    
    let reviewsCollRef = collectionRef()
    try await reviewsCollRef.document("r1").setData(["bookTitle": "The Hitchhiker's Guide to the Galaxy", "reviewer": "Alice"])
    try await reviewsCollRef.document("r2").setData(["bookTitle": "The Hitchhiker's Guide to the Galaxy", "reviewer": "Bob"])

    let reviewsSub = db.pipeline()
      .collection(reviewsCollRef.path)
      .where(Field("bookTitle").equal(Variable("book_title")))
      .select([Field("reviewer").as("reviewer")])
      .sort([Field("reviewer").ascending()])

    let snapshot = try await db.pipeline()
      .collection(collRef.path)
      .where(Field("title").equal("The Hitchhiker's Guide to the Galaxy") || Field("title").equal("Pride and Prejudice"))
      .define([Field("title").as("book_title")])
      .addFields([reviewsSub.toArrayExpression().as("reviews_data")])
      .select(["title", "reviews_data"])
      .sort([Field("title").descending()])
      .execute()

    XCTAssertEqual(snapshot.results.count, 2)
    let expectedData: [[String: Sendable]] = [
      ["title": "The Hitchhiker's Guide to the Galaxy", "reviews_data": ["Alice", "Bob"]],
      ["title": "Pride and Prejudice", "reviews_data": []]
    ]
    for (i, resultDoc) in snapshot.results.enumerated() {
      TestHelper.compare(pipelineResult: resultDoc, expected: expectedData[i])
    }
  }

  func testMultipleArraySubqueriesOnBooks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let reviewsCollRef = collectionRef()
    let authorsCollRef = collectionRef()

    try await reviewsCollRef.document("r1").setData(["bookTitle": "1984", "rating": 5])
    try await authorsCollRef.document("a1").setData(["authorName": "George Orwell", "nationality": "British"])

    let reviewsSub = db.pipeline()
      .collection(reviewsCollRef.path)
      .where(Field("bookTitle").equal(Variable("book_title")))
      .select([Field("rating").as("rating")])

    let authorsSub = db.pipeline()
      .collection(authorsCollRef.path)
      .where(Field("authorName").equal(Variable("author_name")))
      .select([Field("nationality").as("nationality")])

    let snapshot = try await db.pipeline()
      .collection(collRef.path)
      .where(Field("title").equal("1984"))
      .define([Field("title").as("book_title"), Field("author").as("author_name")])
      .addFields([
        reviewsSub.toArrayExpression().as("reviews_data"),
        authorsSub.toArrayExpression().as("authors_data")
      ])
      .select(["title", "reviews_data", "authors_data"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: [
      "title": "1984", "reviews_data": [5], "authors_data": ["British"]
    ])
  }

  func testArraySubqueryJoinMultipleFieldsPreservesMap() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let reviewsCollRef = collectionRef()
    try await reviewsCollRef.document("r1").setData(["bookTitle": "1984", "reviewer": "Alice", "rating": 5])
    try await reviewsCollRef.document("r2").setData(["bookTitle": "1984", "reviewer": "Bob", "rating": 4])

    let reviewsSub = db.pipeline()
      .collection(reviewsCollRef.path)
      .where(Field("bookTitle").equal(Variable("book_title")))
      .select([Field("reviewer").as("reviewer"), Field("rating").as("rating")])
      .sort([Field("reviewer").ascending()])

    let snapshot = try await db.pipeline()
      .collection(collRef.path)
      .where(Field("title").equal("1984"))
      .define([Field("title").as("book_title")])
      .addFields([reviewsSub.toArrayExpression().as("reviews_data")])
      .select(["title", "reviews_data"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    let expectedData: [String: Sendable] = [
      "title": "1984",
      "reviews_data": [
        ["reviewer": "Alice", "rating": 5],
        ["reviewer": "Bob", "rating": 4]
      ]
    ]
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: expectedData)
  }

  func testArraySubqueryInWhereStageOnBooks() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let reviewsCollRef = collectionRef()
    try await reviewsCollRef.document("r1").setData(["bookTitle": "Dune", "reviewer": "Paul"])
    try await reviewsCollRef.document("r2").setData(["bookTitle": "Foundation", "reviewer": "Hari"])

    let reviewsSub = db.pipeline()
      .collection(reviewsCollRef.path)
      .where(Field("bookTitle").equal(Variable("book_title")))
      .select([Field("reviewer").as("reviewer")])

    let snapshot = try await db.pipeline()
      .collection(collRef.path)
      .where(Field("title").equal("Dune") || Field("title").equal("The Great Gatsby"))
      .define([Field("title").as("book_title")])
      .where(reviewsSub.toArrayExpression().arrayContains("Paul"))
      .select(["title"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: ["title": "Dune"])
  }

  func testScalarSubquerySingleAggregationUnwrapping() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let reviewsCollRef = collectionRef()
    try await reviewsCollRef.document("r1").setData(["bookTitle": "1984", "rating": 4])
    try await reviewsCollRef.document("r2").setData(["bookTitle": "1984", "rating": 5])

    let reviewsSub = db.pipeline()
      .collection(reviewsCollRef.path)
      .where(Field("bookTitle").equal(Variable("book_title")))
      .aggregate([Field("rating").average().as("val")])

    let snapshot = try await db.pipeline()
      .collection(collRef.path)
      .where(Field("title").equal("1984"))
      .define([Field("title").as("book_title")])
      .addFields([reviewsSub.toScalarExpression().as("average_rating")])
      .select(["title", "average_rating"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: ["title": "1984", "average_rating": 4.5])
  }

  func testScalarSubqueryMultipleAggregationsMapWrapping() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let reviewsCollRef = collectionRef()
    try await reviewsCollRef.document("r1").setData(["bookTitle": "1984", "rating": 4])
    try await reviewsCollRef.document("r2").setData(["bookTitle": "1984", "rating": 5])

    let reviewsSub = db.pipeline()
      .collection(reviewsCollRef.path)
      .where(Field("bookTitle").equal(Variable("book_title")))
      .aggregate([
        Field("rating").average().as("avg"),
        CountAll().as("count")
      ])

    let snapshot = try await db.pipeline()
      .collection(collRef.path)
      .where(Field("title").equal("1984"))
      .define([Field("title").as("book_title")])
      .addFields([reviewsSub.toScalarExpression().as("stats")])
      .select(["title", "stats"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: ["title": "1984", "stats": ["avg": 4.5, "count": 2]])
  }

  func testScalarSubqueryZeroResults() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let reviewsCollRef = collectionRef()

    let reviewsSub = db.pipeline()
      .collection(reviewsCollRef.path)
      .where(Field("bookTitle").equal(Variable("book_title")))
      .aggregate([Field("rating").average().as("avg")])

    let snapshot = try await db.pipeline()
      .collection(collRef.path)
      .where(Field("title").equal("1984"))
      .define([Field("title").as("book_title")])
      .addFields([reviewsSub.toScalarExpression().as("average_rating")])
      .select(["title", "average_rating"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: ["title": "1984", "average_rating": nil])
  }

  func testScalarSubqueryMultipleResultsRuntimeError() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let reviewsCollRef = collectionRef()
    try await reviewsCollRef.document("r1").setData(["bookTitle": "1984", "rating": 4])
    try await reviewsCollRef.document("r2").setData(["bookTitle": "1984", "rating": 5])

    let reviewsSub = db.pipeline()
      .collection(reviewsCollRef.path)
      .where(Field("bookTitle").equal(Variable("book_title")))

    do {
      _ = try await db.pipeline()
        .collection(collRef.path)
        .where(Field("title").equal("1984"))
        .define([Field("title").as("book_title")])
        .addFields([reviewsSub.toScalarExpression().as("review_data")])
        .execute()
      XCTFail("Should throw error")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("Subpipeline returned multiple results."))
    }
  }

  func testMixedScalarAndArraySubqueries() async throws {
    let collRef = collectionRef(withDocuments: bookDocs)
    let db = collRef.firestore

    let reviewsCollRef = collectionRef()
    try await reviewsCollRef.document("r1").setData(["bookTitle": "1984", "reviewer": "Alice", "rating": 4])
    try await reviewsCollRef.document("r2").setData(["bookTitle": "1984", "reviewer": "Bob", "rating": 5])

    let arraySub = db.pipeline()
      .collection(reviewsCollRef.path)
      .where(Field("bookTitle").equal(Variable("book_title")))
      .select([Field("reviewer").as("reviewer")])
      .sort([Field("reviewer").ascending()])

    let scalarSub = db.pipeline()
      .collection(reviewsCollRef.path)
      .where(Field("bookTitle").equal(Variable("book_title")))
      .aggregate([Field("rating").average().as("val")])

    let snapshot = try await db.pipeline()
      .collection(collRef.path)
      .where(Field("title").equal("1984"))
      .define([Field("title").as("book_title")])
      .addFields([
        arraySub.toArrayExpression().as("all_reviewers"),
        scalarSub.toScalarExpression().as("average_rating")
      ])
      .select(["title", "all_reviewers", "average_rating"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: [
      "title": "1984",
      "all_reviewers": ["Alice", "Bob"],
      "average_rating": 4.5
    ])
  }

  func testSingleScopeVariableUsage() async throws {
    let collRef = collectionRef()
    let db = collRef.firestore
    try await collRef.document("doc1").setData(["price": 100])

    var snapshot = try await db.pipeline()
      .collection(collRef.path)
      .define([Field("price").multiply(0.8).as("discount")])
      .where(Variable("discount").lessThan(50.0))
      .select(["price"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 0)

    try await collRef.document("doc2").setData(["price": 50])

    snapshot = try await db.pipeline()
      .collection(collRef.path)
      .define([Field("price").multiply(0.8).as("discount")])
      .where(Variable("discount").lessThan(50.0))
      .select(["price"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: ["price": 50])
  }

  func testExplicitFieldBindingScopeBridging() async throws {
    let outerCollRef = collectionRef()
    let db = outerCollRef.firestore

    try await outerCollRef.document("doc1").setData(["title": "1984", "id": "1"])

    let reviewsCollRef = collectionRef()
    try await reviewsCollRef.document("r1").setData(["bookId": "1", "reviewer": "Alice"])

    let reviewsSub = db.pipeline()
      .collection(reviewsCollRef.path)
      .where(Field("bookId").equal(Variable("rid")))
      .select([Field("reviewer").as("reviewer")])

    let snapshot = try await db.pipeline()
      .collection(outerCollRef.path)
      .where(Field("title").equal("1984"))
      .define([Field("id").as("rid")])
      .addFields([reviewsSub.toArrayExpression().as("reviews")])
      .select(["title", "reviews"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: ["title": "1984", "reviews": ["Alice"]])
  }

  func testMultipleVariableBindings() async throws {
    let outerCollRef = collectionRef()
    let db = outerCollRef.firestore

    try await outerCollRef.document("doc1").setData(["title": "1984", "id": "1", "category": "sci-fi"])

    let reviewsCollRef = collectionRef()
    try await reviewsCollRef.document("r1").setData(["bookId": "1", "category": "sci-fi", "reviewer": "Alice"])

    let reviewsSub = db.pipeline()
      .collection(reviewsCollRef.path)
      .where(Field("bookId").equal(Variable("rid")) && Field("category").equal(Variable("rcat")))
      .select([Field("reviewer").as("reviewer")])

    let snapshot = try await db.pipeline()
      .collection(outerCollRef.path)
      .where(Field("title").equal("1984"))
      .define([Field("id").as("rid"), Field("category").as("rcat")])
      .addFields([reviewsSub.toArrayExpression().as("reviews")])
      .select(["title", "reviews"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: ["title": "1984", "reviews": ["Alice"]])
  }

  func testCurrentDocumentBinding() async throws {
    let outerCollRef = collectionRef()
    let db = outerCollRef.firestore

    try await outerCollRef.document("doc1").setData(["title": "1984", "author": "George Orwell"])

    let reviewsCollRef = collectionRef()
    try await reviewsCollRef.document("r1").setData(["authorName": "George Orwell", "reviewer": "Alice"])

    let reviewsSub = db.pipeline()
      .collection(reviewsCollRef.path)
      .where(Field("authorName").equal(Variable("doc").getField("author")))
      .select([Field("reviewer").as("reviewer")])

    let snapshot = try await db.pipeline()
      .collection(outerCollRef.path)
      .where(Field("title").equal("1984"))
      .define([CurrentDocument().as("doc")])
      .addFields([reviewsSub.toArrayExpression().as("reviews")])
      .select(["title", "reviews"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: ["title": "1984", "reviews": ["Alice"]])
  }

  func testUnboundVariableCornerCase() async throws {
    let outerCollRef = collectionRef()
    let db = outerCollRef.firestore

    do {
      _ = try await db.pipeline()
        .collection(outerCollRef.path)
        .where(Field("title").equal(Variable("unknown_var")))
        .execute()
      XCTFail("Should throw error")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("unknown variable"))
    }
  }

  func testVariableShadowingCollision() async throws {
    let outerCollRef = collectionRef()
    let db = outerCollRef.firestore
    try await outerCollRef.document("doc1").setData(["title": "1984"])

    let innerCollRef = collectionRef()
    try await innerCollRef.document("i1").setData(["id": "test"])

    let sub = db.pipeline()
      .collection(innerCollRef.path)
      .define([Constant("inner_val").as("x")])
      .select([Variable("x").as("val")])

    let snapshot = try await db.pipeline()
      .collection(outerCollRef.path)
      .where(Field("title").equal("1984"))
      .limit(1)
      .define([Constant("outer_val").as("x")])
      .addFields([sub.toArrayExpression().as("shadowed")])
      .select(["shadowed"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: ["shadowed": ["inner_val"]])
  }

  func testMissingFieldOnCurrentDocument() async throws {
    let outerCollRef = collectionRef()
    let db = outerCollRef.firestore
    try await outerCollRef.document("doc1").setData(["title": "1984"])

    let reviewsCollRef = collectionRef()
    try await reviewsCollRef.document("r1").setData(["bookId": "1", "reviewer": "Alice"])

    let reviewsSub = db.pipeline()
      .collection(reviewsCollRef.path)
      .where(Field("bookId").equal(Variable("doc").getField("does_not_exist")))
      .select([Field("reviewer").as("reviewer")])

    let snapshot = try await db.pipeline()
      .collection(outerCollRef.path)
      .where(Field("title").equal("1984"))
      .define([CurrentDocument().as("doc")])
      .addFields([reviewsSub.toArrayExpression().as("reviews")])
      .select(["title", "reviews"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: ["title": "1984", "reviews": []])
  }

  func test3LevelDeepJoin() async throws {
    let publishersCollRef = collectionRef()
    let db = publishersCollRef.firestore
    let booksCollRef = collectionRef()
    let reviewsCollRef = collectionRef()

    try await publishersCollRef.document("p1").setData(["publisherId": "pub1", "name": "Penguin"])
    try await booksCollRef.document("b1").setData(["bookId": "book1", "publisherId": "pub1", "title": "1984"])
    try await reviewsCollRef.document("r1").setData(["bookId": "book1", "reviewer": "Alice"])

    let reviewsSub = db.pipeline()
      .collection(reviewsCollRef.path)
      .where(Field("bookId").equal(Variable("book_id")) && Variable("pub_name").equal("Penguin"))
      .select([Field("reviewer").as("reviewer")])

    let booksSub = db.pipeline()
      .collection(booksCollRef.path)
      .where(Field("publisherId").equal(Variable("pub_id")))
      .define([Field("bookId").as("book_id")])
      .addFields([reviewsSub.toArrayExpression().as("reviews")])
      .select(["title", "reviews"])

    let snapshot = try await db.pipeline()
      .collection(publishersCollRef.path)
      .where(Field("publisherId").equal("pub1"))
      .define([Field("publisherId").as("pub_id"), Field("name").as("pub_name")])
      .addFields([booksSub.toArrayExpression().as("books")])
      .select(["name", "books"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: [
      "name": "Penguin",
      "books": [
        ["title": "1984", "reviews": ["Alice"]]
      ]
    ])
  }

  func testDeepAggregation() async throws {
    let outerCollRef = collectionRef()
    let db = outerCollRef.firestore
    let innerCollRef = collectionRef()

    try await outerCollRef.document("doc1").setData(["id": "1"])
    try await outerCollRef.document("doc2").setData(["id": "2"])

    try await innerCollRef.document("i1").setData(["outer_id": "1", "score": 10])
    try await innerCollRef.document("i2").setData(["outer_id": "2", "score": 20])
    try await innerCollRef.document("i3").setData(["outer_id": "1", "score": 30])

    let innerSub = db.pipeline()
      .collection(innerCollRef.path)
      .where(Field("outer_id").equal(Variable("oid")))
      .aggregate([Field("score").average().as("s")])

    let snapshot = try await db.pipeline()
      .collection(outerCollRef.path)
      .define([Field("id").as("oid")])
      .addFields([innerSub.toScalarExpression().as("doc_score")])
      .aggregate([Field("doc_score").sum().as("total_score")])
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: ["total_score": 40.0])
  }

  func testPipelineStageSupport10Layers() async throws {
    let collRef = collectionRef()
    let db = collRef.firestore
    try await collRef.document("doc1").setData(["val": "hello"])

    var currentSubquery = db.pipeline()
      .collection(collRef.path)
      .limit(1)
      .select([Field("val").as("val")])

    for i in 0..<9 {
      currentSubquery = db.pipeline()
        .collection(collRef.path)
        .limit(1)
        .addFields([currentSubquery.toArrayExpression().as("nested_\(i)")])
        .select(["nested_\(i)"])
    }

    let snapshot = try await currentSubquery.execute()
    XCTAssertEqual(snapshot.results.count, 1)
  }

  func testStandardSubcollectionQuery() async throws {
    let collRef = collectionRef()
    let db = collRef.firestore

    try await collRef.document("doc1").setData(["title": "1984"])
    try await collRef.document("doc1").collection("reviews").document("r1").setData(["reviewer": "Alice"])

    let reviewsSub = Subcollection("reviews")
      .select([Field("reviewer").as("reviewer")])

    let snapshot = try await db.pipeline()
      .collection(collRef.path)
      .where(Field("title").equal("1984"))
      .addFields([reviewsSub.toArrayExpression().as("reviews")])
      .select(["title", "reviews"])
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: ["title": "1984", "reviews": ["Alice"]])
  }

  func testMissingSubcollection() async throws {
    let collRef = collectionRef()
    let db = collRef.firestore
    try await collRef.document("doc1").setData(["id": "no_subcollection_here"])

    let missingSub = Subcollection("does_not_exist")
      .select([Variable("p").as("sub_p")])

    let snapshot = try await db.pipeline()
      .collection(collRef.path)
      .define([CurrentDocument().as("p")])
      .select([missingSub.toArrayExpression().as("missing_data")])
      .limit(1)
      .execute()

    XCTAssertEqual(snapshot.results.count, 1)
    TestHelper.compare(pipelineResult: snapshot.results.first!, expected: ["missing_data": []])
  }

  func testDirectExecutionOfSubcollectionPipeline() async throws {
    let sub = Subcollection("reviews")

    do {
      _ = try await sub.execute()
      XCTFail("Should throw error")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("This pipeline was created without a database"))
    }
  }
}
