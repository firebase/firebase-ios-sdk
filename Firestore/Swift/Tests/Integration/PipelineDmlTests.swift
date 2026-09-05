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

  // Test 1: Delete Stage
  func testDeleteStage() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "ToDelete"]]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("__name__").equal(Expression.constant("book1")))
      .delete()

    let snapshot = try await pipeline.execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)
  }

  // Test 2: Update Stage
  func testUpdateStageWithTransforms() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "OldTitle", "rating": 4.0]]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("__name__").equal(Expression.constant("book1")))
      .update(Expression.constant("NewTitle").as("title"))

    let snapshot = try await pipeline.execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)
  }

  // Test 3: Insert stage using a field value as document ID
  func testInsertWithFieldAsDocumentId() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "SciFi", "targetId": "custom_doc_1"]]
    let sourceRef = collectionRef(withDocuments: testDocs)
    let db = sourceRef.firestore
    let targetRef = collectionRef()

    let pipeline = db.pipeline()
      .collection(sourceRef.path)
      .where(Field("__name__").equal(Expression.constant("book1")))
      .insert(collectionPath: targetRef.path, documentIdExpression: Field("targetId"))

    let snapshot = try await pipeline.execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)
  }

  // Test 4: Insert stage using an expression as document ID
  func testInsertWithExpressionAsDocumentId() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "SciFi"]]
    let sourceRef = collectionRef(withDocuments: testDocs)
    let db = sourceRef.firestore
    let targetRef = collectionRef()

    let pipeline = db.pipeline()
      .collection(sourceRef.path)
      .where(Field("__name__").equal(Expression.constant("book1")))
      .insert(collectionPath: targetRef.path, documentIdExpression: Expression.constant("custom_fixed_id"))

    let snapshot = try await pipeline.execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)
  }

  // Test 5: Upsert (insert) a new document if it does not exist
  func testUpsertInsertsNewDocument() async throws {
    let collRef = collectionRef()
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .documents([collRef.document("new_upsert_doc")])
      .upsert([
        Expression.constant("New Upserted Title").as("title"),
        Expression.constant("Sci-Fi").as("genre")
      ])

    let snapshot = try await pipeline.execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)
  }

  // Test 6: Upsert (update) an existing document by modifying fields
  func testUpsertUpdatesExistingDocument() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "Old", "rating": 3.0]]
    let collRef = collectionRef(withDocuments: testDocs)
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .collection(collRef.path)
      .where(Field("__name__").equal(Expression.constant("book1")))
      .upsert([
        Expression.constant("Updated by Upsert").as("title"),
        Expression.constant(4.5).as("rating")
      ])

    let snapshot = try await pipeline.execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)
  }

  // Test 7: Upsert with custom target collection and document ID field
  func testUpsertWithCustomCollectionAndDocumentId() async throws {
    let testDocs: [String: [String: Sendable]] = ["book1": ["title": "Base", "customId": "target_id_10"]]
    let sourceRef = collectionRef(withDocuments: testDocs)
    let db = sourceRef.firestore
    let targetRef = collectionRef()

    let pipeline = db.pipeline()
      .collection(sourceRef.path)
      .where(Field("__name__").equal(Expression.constant("book1")))
      .upsert(
        [Expression.constant("Target Title").as("title")],
        collectionPath: targetRef.path,
        documentIdExpression: Field("customId")
      )

    let snapshot = try await pipeline.execute(options: .init(isAtomic: true))
    XCTAssertNotNil(snapshot)
  }

  // Test 8: Execute pipeline with literals stage source
  func testLiteralsSourceBasicExecution() async throws {
    let db = collectionRef().firestore
    let pipeline = db.pipeline()
      .literals([
        ["name": "Alice", "age": 30],
        ["name": "Bob", "age": 25]
      ])

    let snapshot = try await pipeline.execute()
    XCTAssertNotNil(snapshot)
  }

  // Test 9: Execute literals stage containing expression transforms
  func testLiteralsSourceWithExpressions() async throws {
    let db = collectionRef().firestore
    let pipeline = db.pipeline()
      .literals([
        ["base": 10, "doubled": Expression.constant(20)]
      ])

    let snapshot = try await pipeline.execute()
    XCTAssertNotNil(snapshot)
  }

  // Test 10: Non-transactional insert from literals source
  func testNonTransactionalInsertFromLiterals() async throws {
    let collRef = collectionRef()
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .literals([
        ["title": "Literal Inserted", "year": 2026]
      ])
      .insert(collectionPath: collRef.path, documentIdExpression: Expression.constant("lit_doc_1"))

    let snapshot = try await pipeline.execute()
    XCTAssertNotNil(snapshot)
  }

  // Test 11: Non-transactional upsert from literals source
  func testNonTransactionalUpsertFromLiterals() async throws {
    let collRef = collectionRef()
    let db = collRef.firestore

    let pipeline = db.pipeline()
      .literals([
        ["id": "doc1", "title": "Literal Upserted"]
      ])
      .upsert(
        [Expression.constant("Literal Upserted Modified").as("title")],
        collectionPath: collRef.path,
        documentIdExpression: Expression.constant("doc1")
      )

    let snapshot = try await pipeline.execute()
    XCTAssertNotNil(snapshot)
  }
}
