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

import FirebaseFirestore
import Foundation
import XCTest

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class LargeDocIntegrationTests: FSTIntegrationTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()

    // Skip by default to prevent slowing down CI.
    // Add environment variable FIRESTORE_RUN_LARGE_DOC_TESTS = YES.
    let runLargeTests = ProcessInfo.processInfo.environment["FIRESTORE_RUN_LARGE_DOC_TESTS"]
    if runLargeTests != "YES" && runLargeTests != "true" {
      throw XCTSkip("Skipping large doc tests. Set FIRESTORE_RUN_LARGE_DOC_TESTS=YES to run.")
    }

    // Skip tests if the backend edition is not supported or if not nightly
    if FSTIntegrationTestCase.targetBackend() != .nightly || FSTIntegrationTestCase
      .backendEdition() == .standard {
      throw XCTSkip("Skipping large document tests because backend is not compatible.")
    }
  }

  override class func tearDown() {
    super.tearDown()
  }

  // MARK: - Helper Methods

  private func generateString(sizeInBytes: Int, character: Character = "a") -> String {
    return String(repeating: character, count: sizeInBytes)
  }

  private static var largeDocument: [String: Sendable] =
    ["chunk": String(repeating: "a", count: Int(15.9 * 1024 * 1024))]

  // MARK: - Test Cases

  // NOTE: This test is currently expected to fail, because the payload
  // size exceeds the gRPC message size limit. The Unicode character is
  // encoded as 4 bytes, which causes the 16 MB document to be encoded
  // as 64 MB.
  func testReadAndCacheLargeUnicodeDocument() async throws {
    throw XCTSkip("Skipping unicode document test.")

    let colRef = collectionRef()
    let db = colRef.firestore
    let docRef = colRef.document("doc_15_9MB_unicode")
    try await docRef
      .setData(["chunk": generateString(sizeInBytes: Int(15.9 * 1024 * 1024), character: "🚀")])

    let serverSnapshot = try await docRef.getDocument(source: .server)
    XCTAssertTrue(serverSnapshot.exists)

    try await db.disableNetwork()
    defer { Task { try? await db.enableNetwork() } }

    let cacheSnapshot = try await docRef.getDocument(source: .cache)
    XCTAssertTrue(cacheSnapshot.exists)

    let serverData = serverSnapshot.data() as NSDictionary?
    let cacheData = cacheSnapshot.data() as NSDictionary?
    XCTAssertEqual(serverData, cacheData)
  }

  func testQueryLargeDocumentsForcesLocalScan() async throws {
    let colRef = collectionRef()
    let db = colRef.firestore
    let docRefA = colRef.document("doc_a")
    let docRefB = colRef.document("doc_b")
    try await docRefA.setData(LargeDocIntegrationTests.largeDocument)
    try await docRefB.setData(LargeDocIntegrationTests.largeDocument)

    try await docRefA.getDocument(source: .server)
    try await docRefB.getDocument(source: .server)

    try await db.disableNetwork()
    defer { Task { try? await db.enableNetwork() } }

    // Execute offline query which requires full local index scan
    let query = colRef.order(by: FieldPath.documentID()).limit(to: 2)
    let cacheSnapshot = try await query.getDocuments(source: .cache)

    XCTAssertEqual(cacheSnapshot.documents.count, 2)
    if let firstDoc = cacheSnapshot.documents.first {
      XCTAssertTrue(firstDoc.data().count > 0)
    }
  }

  func testWatchStreamInitializationAndDiff() async throws {
    let colRef = collectionRef()
    let db = colRef.firestore
    let docRef = colRef.document("doc_a")
    try await docRef.setData(LargeDocIntegrationTests.largeDocument)

    let expectation = XCTestExpectation(description: "Wait for differential update payload")

    let listener = docRef.addSnapshotListener { snapshot, error in
      XCTAssertNil(error)
      guard let snapshot = snapshot else { return }

      if snapshot.exists && snapshot.data()?["differential_field"] != nil {
        expectation.fulfill()
      }
    }
    defer { listener.remove() }

    try await docRef.updateData(["differential_field": "updated_value"])
    await fulfillment(of: [expectation], timeout: 60)
  }

  func testOversizedPayloadRejection() async throws {
    let docRef = collectionRef().document("temp_oversized_doc")
    let targetBytes = (16 * 1024 * 1024) + 102_400
    let largePayload = generateString(sizeInBytes: targetBytes)

    do {
      try await docRef.setData(["largeField": largePayload])
      XCTFail("Setting a document exceeding the 16MB limit should fail.")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, FirestoreErrorDomain)
      // Must map to standard InvalidArgument error, not a crash.
      XCTAssertEqual(nsError.code, FirestoreErrorCode.invalidArgument.rawValue)
    }
  }

  func testQueryLargeDocuments() async throws {
    let colRef = collectionRef()
    let db = colRef.firestore
    let docRefA = colRef.document("doc_a")
    let docRefB = colRef.document("doc_b")
    try await docRefA.setData(LargeDocIntegrationTests.largeDocument)
    try await docRefB.setData(LargeDocIntegrationTests.largeDocument)

    let query = colRef.whereField(FieldPath.documentID(), in: ["doc_a", "doc_b"])

    let serverSnapshot = try await query.getDocuments(source: .server)
    XCTAssertEqual(serverSnapshot.documents.count, 2)

    try await db.disableNetwork()
    defer { Task { try? await db.enableNetwork() } }

    let cacheSnapshot = try await query.getDocuments(source: .cache)
    XCTAssertEqual(cacheSnapshot.documents.count, 2)

    let serverFirstData = serverSnapshot.documents.first?.data() as NSDictionary?
    let cacheFirstData = cacheSnapshot.documents.first?.data() as NSDictionary?
    XCTAssertEqual(serverFirstData, cacheFirstData)
  }

  func testTransactionReadModifyWrite() async throws {
    let colRef = collectionRef()
    let db = colRef.firestore
    let docRef = colRef.document("doc_a")
    try await docRef.setData(LargeDocIntegrationTests.largeDocument)

    do {
      _ = try await db.runTransaction { transaction, errorPointer -> Any? in
        do {
          _ = try transaction.getDocument(docRef)
          transaction.updateData(
            ["transaction_timestamp": FieldValue.serverTimestamp()],
            forDocument: docRef
          )
        } catch let fetchError as NSError {
          errorPointer?.pointee = fetchError
        }
        return nil
      }
    } catch {
      XCTFail("Transaction failed with error: \(error)")
    }
  }
}
