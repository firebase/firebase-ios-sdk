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
@testable import FirebaseFirestore
import Foundation
import XCTest

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class PipelineDmlTests: FSTIntegrationTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()

    if FSTIntegrationTestCase.backendEdition() == .standard {
      throw XCTSkip(
        "Skipping all tests in PipelineDmlTests because backend edition is Standard."
      )
    }
  }

  // MARK: - Delete Stage (5 tests)

  func testDeleteSingleDocument() async throws {
    let testDocs: [String: [String: Sendable]] = [
      "book1": ["title": "Book 1"],
      "book2": ["title": "Book 2"],
    ]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .documents([collRef.document("book1")])
      .delete()
      .execute()
    XCTAssertNotNil(snapshot)

    let deletedSnap = try await collRef.document("book1").getDocument()
    XCTAssertFalse(deletedSnap.exists)
    let remainingSnap = try await collRef.document("book2").getDocument()
    XCTAssertTrue(remainingSnap.exists)
  }

  func testDeleteMultipleDocumentsWithWhereFilter() async throws {
    let testDocs: [String: [String: Sendable]] = [
      "book1": ["title": "Dune", "genre": "Sci-Fi"],
      "book2": ["title": "Pride and Prejudice", "genre": "Romance"],
      "book3": ["title": "Foundation", "genre": "Sci-Fi"],
    ]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .collection(collRef.path)
      .where(Field("genre").equal(Constant("Sci-Fi")))
      .delete()
      .execute()
    XCTAssertNotNil(snapshot)

    let snap1 = try await collRef.document("book1").getDocument()
    XCTAssertFalse(snap1.exists)
    let snap2 = try await collRef.document("book2").getDocument()
    XCTAssertTrue(snap2.exists)
    let snap3 = try await collRef.document("book3").getDocument()
    XCTAssertFalse(snap3.exists)
  }

  func testDeleteNonExistingDocument() async throws {
    let collRef = collectionRef()
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .documents([collRef.document("non_existing_id")])
      .delete()
      .execute()
    XCTAssertNotNil(snapshot)
  }

  func testDeleteWithAtomicTrue() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "ToDelete"]]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .documents([collRef.document("book1")])
      .delete()
      .execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)

    let docSnap = try await collRef.document("book1").getDocument()
    XCTAssertFalse(docSnap.exists)
  }

  func testDeleteWithAtomicFalse() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "ToDelete"]]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .documents([collRef.document("book1")])
      .delete()
      .execute(options: .init(isAtomic: false))
    XCTAssertNotNil(snapshot)

    let docSnap = try await collRef.document("book1").getDocument()
    XCTAssertFalse(docSnap.exists)
  }

  // MARK: - Update Stage (8 tests)

  func testUpdateSingleDocumentWithAddFields() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "OldTitle", "rating": 4.0]]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .documents([collRef.document("book1")])
      .addFields([
        Constant("NewTitle").as("title"),
        Constant("AddedValue").as("extraField"),
      ])
      .update()
      .execute()
    XCTAssertNotNil(snapshot)

    let docSnap = try await collRef.document("book1").getDocument()
    XCTAssertEqual(docSnap.data()?["title"] as? String, "NewTitle")
    XCTAssertEqual(docSnap.data()?["extraField"] as? String, "AddedValue")
  }

  func testUpdateMultipleDocumentsWithRemoveFields() async throws {
    let testDocs: [String: [String: Sendable]] = [
      "book1": ["title": "Book 1", "genre": "Sci-Fi", "temp": "remove_me"],
      "book2": ["title": "Book 2", "genre": "Sci-Fi", "temp": "remove_me_too"],
    ]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .collection(collRef.path)
      .where(Field("genre").equal(Constant("Sci-Fi")))
      .removeFields(["temp"])
      .update(Constant("Updated").as("status"))
      .execute()
    XCTAssertNotNil(snapshot)

    let snap1 = try await collRef.document("book1").getDocument()
    XCTAssertNil(snap1.data()?["temp"])
    XCTAssertEqual(snap1.data()?["status"] as? String, "Updated")
    let snap2 = try await collRef.document("book2").getDocument()
    XCTAssertNil(snap2.data()?["temp"])
    XCTAssertEqual(snap2.data()?["status"] as? String, "Updated")
  }

  func testUpdateWithExpressions() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "Book 1", "score": 10]]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .documents([collRef.document("book1")])
      .update(Field("score").add(5).as("score"))
      .execute()
    XCTAssertNotNil(snapshot)

    let docSnap = try await collRef.document("book1").getDocument()
    XCTAssertEqual(docSnap.data()?["score"] as? Int, 15)
  }

  func testUpdateWithVariadicSingleExpression() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "Book 1", "score": 10]]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .documents([collRef.document("book1")])
      .update(Constant(true).as("is_top_scorer"))
      .execute()
    XCTAssertNotNil(snapshot)

    let docSnap = try await collRef.document("book1").getDocument()
    XCTAssertEqual(docSnap.data()?["is_top_scorer"] as? Bool, true)
  }

  func testUpdateWithVariadicMultipleExpressions() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "Book 1", "score": 10]]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .documents([collRef.document("book1")])
      .update(
        Constant(true).as("is_top_scorer"),
        Field("score").add(10).as("score")
      )
      .execute()
    XCTAssertNotNil(snapshot)

    let docSnap = try await collRef.document("book1").getDocument()
    XCTAssertEqual(docSnap.data()?["is_top_scorer"] as? Bool, true)
    XCTAssertEqual(docSnap.data()?["score"] as? Int, 20)
  }

  func testUpdateWithArrayOfExpressions() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "Book 1", "score": 10]]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .documents([collRef.document("book1")])
      .update([
        Constant("reviewed").as("status"),
        Constant(100).as("score"),
      ])
      .execute()
    XCTAssertNotNil(snapshot)

    let docSnap = try await collRef.document("book1").getDocument()
    XCTAssertEqual(docSnap.data()?["status"] as? String, "reviewed")
    XCTAssertEqual(docSnap.data()?["score"] as? Int, 100)
  }

  func testUpdateNonExistingDocumentModifiesZeroDocuments() async throws {
    let collRef = collectionRef()
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .documents([collRef.document("non_existing")])
      .update(Constant("NoOp").as("title"))
      .execute()
    XCTAssertNotNil(snapshot)

    let docSnap = try await collRef.document("non_existing").getDocument()
    XCTAssertFalse(docSnap.exists)
  }

  func testUpdateAtomically() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "OldTitle"]]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .documents([collRef.document("book1")])
      .update(Constant("AtomicTitle").as("title"))
      .execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)

    let docSnap = try await collRef.document("book1").getDocument()
    XCTAssertEqual(docSnap.data()?["title"] as? String, "AtomicTitle")
  }

  // MARK: - Insert Stage (4 tests)

  func testInsertWithAutoGeneratedId() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "Source Book"]]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .documents([collRef.document("book1")])
      .removeFields(["__name__"])
      .insert(collectionPath: collRef.path)
      .execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)

    let querySnap = try await collRef.getDocuments()
    XCTAssertEqual(querySnap.documents.count, 2)
  }

  func testInsertWithDocumentIdExpression() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "SciFi"]]
    let sourceRef = collectionRef(withDocuments: testDocs)
    let db = sourceRef.firestore
    let targetRef = collectionRef()

    let snapshot = try await db.pipeline()
      .documents([sourceRef.document("book1")])
      .insert(
        collectionPath: targetRef.path,
        documentIdExpression: Constant("custom_fixed_id")
      )
      .execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)

    let docSnap = try await targetRef.document("custom_fixed_id").getDocument()
    XCTAssertTrue(docSnap.exists)
    XCTAssertEqual(docSnap.data()?["title"] as? String, "SciFi")
  }

  func testInsertFailsWhenDocumentAlreadyExists() async throws {
    let testDocs: [String: [String: Sendable]] = [
      "book1": ["title": "Book 1"],
      "book2": ["title": "Book 2"],
    ]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    do {
      _ = try await db.pipeline()
        .documents([collRef.document("book1")])
        .insert(
          collectionPath: collRef.path,
          documentIdExpression: Constant("book2")
        )
        .execute(options: .init(isAtomic: true))
      XCTFail("Expected insert on existing document ID to throw an error")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testInsertIntoDifferentCollection() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "SciFi"]]
    let sourceRef = collectionRef(withDocuments: testDocs)
    let db = sourceRef.firestore
    let targetRef = collectionRef()

    let snapshot = try await db.pipeline()
      .documents([sourceRef.document("book1")])
      .removeFields(["__name__"])
      .insert(collectionPath: targetRef.path)
      .execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)

    let targetDocs = try await targetRef.getDocuments()
    XCTAssertEqual(targetDocs.documents.count, 1)
    XCTAssertEqual(targetDocs.documents[0].data()["title"] as? String, "SciFi")
  }

  // MARK: - Upsert Stage (5 tests)

  func testUpsertUpdatesExistingDocumentWithVariadic() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "Old", "rating": 3.0]]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .documents([collRef.document("book1")])
      .upsert(
        Constant("Updated by Variadic Upsert").as("title"),
        Constant(4.5).as("rating")
      )
      .execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)

    let docSnap = try await collRef.document("book1").getDocument()
    XCTAssertEqual(docSnap.data()?["title"] as? String, "Updated by Variadic Upsert")
    XCTAssertEqual(docSnap.data()?["rating"] as? Double, 4.5)
  }

  func testUpsertUpdatesExistingDocumentWithArray() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "Old", "rating": 3.0]]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .documents([collRef.document("book1")])
      .upsert([
        Constant("Updated by Array Upsert").as("title"),
        Constant(5.0).as("rating"),
      ])
      .execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)

    let docSnap = try await collRef.document("book1").getDocument()
    XCTAssertEqual(docSnap.data()?["title"] as? String, "Updated by Array Upsert")
    XCTAssertEqual(docSnap.data()?["rating"] as? Double, 5.0)
  }

  func testUpsertInsertsNewDocumentWhenDoesNotExist() async throws {
    let testDocs: [String: [String: Sendable]] = ["source_doc": ["title": "Source"]]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let snapshot = try await db.pipeline()
      .documents([collRef.document("source_doc")])
      .upsert(
        collectionPath: collRef.path,
        documentIdExpression: Constant("new_upsert_doc"),
        additionalFields: [
          Constant("New Upserted Title").as("title"),
          Constant("Sci-Fi").as("genre"),
        ]
      )
      .execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)

    let docSnap = try await collRef.document("new_upsert_doc").getDocument()
    XCTAssertTrue(docSnap.exists)
    XCTAssertEqual(docSnap.data()?["title"] as? String, "New Upserted Title")
    XCTAssertEqual(docSnap.data()?["genre"] as? String, "Sci-Fi")
  }

  func testUpsertIntoDifferentCollectionWithAdditionalFields() async throws {
    let testDocs: [String: [String: Sendable]] = [
      "book1": ["title": "Base", "customId": "target_id_10"],
    ]
    let sourceRef = collectionRef(withDocuments: testDocs)
    let db = sourceRef.firestore
    let targetRef = collectionRef()

    let snapshot = try await db.pipeline()
      .documents([sourceRef.document("book1")])
      .upsert(
        collectionPath: targetRef.path,
        documentIdExpression: Field("customId"),
        additionalFields: [Constant("Target Title").as("title")]
      )
      .execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)

    let docSnap = try await targetRef.document("target_id_10").getDocument()
    XCTAssertTrue(docSnap.exists)
    XCTAssertEqual(docSnap.data()?["title"] as? String, "Target Title")
  }

  func testUpsertIntoDifferentCollectionWithoutAdditionalFields() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "Copied Title"]]
    let sourceRef = collectionRef(withDocuments: testDocs)
    let db = sourceRef.firestore
    let targetRef = collectionRef()

    let snapshot = try await db.pipeline()
      .documents([sourceRef.document("book1")])
      .upsert(
        collectionPath: targetRef.path,
        documentIdExpression: Constant("copied_doc_id")
      )
      .execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)

    let docSnap = try await targetRef.document("copied_doc_id").getDocument()
    XCTAssertTrue(docSnap.exists)
    XCTAssertEqual(docSnap.data()?["title"] as? String, "Copied Title")
  }

  // MARK: - Literals Stage (3 tests, using .union(with:) to satisfy Firebase Security Rules)

  func testLiteralsSourceBasicExecution() async throws {
    let emptyColl = collectionRef()
    let db = emptyColl.firestore
    let pipeline = db.pipeline()
      .literals([
        ["name": "Alice", "age": 30],
        ["name": "Bob", "age": 25],
      ])
      .union(with: db.pipeline().collection(emptyColl.path))

    let snapshot = try await pipeline.execute()
    XCTAssertEqual(snapshot.results.count, 2)
  }

  func testLiteralsSourceWithExpressions() async throws {
    let emptyColl = collectionRef()
    let db = emptyColl.firestore
    let pipeline = db.pipeline()
      .literals([
        ["base": 10, "computed": Constant(10).add(25)],
      ])
      .union(with: db.pipeline().collection(emptyColl.path))

    let snapshot = try await pipeline.execute()
    XCTAssertEqual(snapshot.results.count, 1)
    XCTAssertEqual(snapshot.results[0].data["computed"] as? Int, 35)
  }

  func testLiteralsCombinedWithInsert() async throws {
    let emptyColl = collectionRef()
    let targetRef = collectionRef()
    let db = targetRef.firestore

    let snapshot = try await db.pipeline()
      .literals([
        ["title": "Literal Inserted", "year": 2026],
      ])
      .union(with: db.pipeline().collection(emptyColl.path))
      .insert(
        collectionPath: targetRef.path,
        documentIdExpression: Constant("lit_doc_1")
      )
      .execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)

    let docSnap = try await targetRef.document("lit_doc_1").getDocument()
    XCTAssertTrue(docSnap.exists)
    XCTAssertEqual(docSnap.data()?["title"] as? String, "Literal Inserted")
    XCTAssertEqual(docSnap.data()?["year"] as? Int, 2026)
  }
}
