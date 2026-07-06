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
final class LargeDocIntegrationTests: FSTIntegrationTestCase {
  private static var seedCollection: String?
  private static var sharedDb: Firestore?

  override func setUp() async throws {
    try await super.setUp()
    LargeDocIntegrationTests.sharedDb = self.db 

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

    if LargeDocIntegrationTests.seedCollection == nil {
      LargeDocIntegrationTests.seedCollection = "large_doc_tests_ios_\(UUID().uuidString)"
    }
    let col = LargeDocIntegrationTests.seedCollection!

    // Self-seeding check: ensure prerequisite documents exist for read tests.
    let docRef = db.collection(col).document("doc_15_9MB_unicode")
    let docA = db.collection(col).document("doc_a")
    let docB = db.collection(col).document("doc_b")

    if try await docRef.getDocument(source: .server).exists != true {
      let targetBytes = Int(15.9 * 1024 * 1024)
      let payload = generateString(sizeInBytes: targetBytes)
      try await docRef.setData(["chunk": payload])
      try await docA.setData(["chunk": payload])
      try await docB.setData(["chunk": payload])
    }
  }

  override class func tearDown() {
    if let db = sharedDb, let col = seedCollection {
      let sem = DispatchSemaphore(value: 0)
      Task {
        try? await db.collection(col).document("doc_15_9MB_unicode").delete()
        try? await db.collection(col).document("doc_a").delete()
        try? await db.collection(col).document("doc_b").delete()
        sem.signal()
      }
      _ = sem.wait(timeout: .now() + 30)
    }
    super.tearDown()
  }

  // MARK: - Helper Methods

  private func generateString(sizeInBytes: Int) -> String {
    return String(repeating: "a", count: sizeInBytes)
  }

  override func collectionRef() -> CollectionReference {
    return db.collection(LargeDocIntegrationTests.seedCollection!)
  }

  // MARK: - Test Cases

  func testReadAndCacheLargeUnicodeDocument() async throws {
    let docRef = collectionRef().document("doc_15_9MB_unicode")
    defer { Task { try? await db.enableNetwork() } }

    let serverSnapshot = try await docRef.getDocument(source: .server)
    XCTAssertTrue(serverSnapshot.exists)

    try await db.disableNetwork()

    let cacheSnapshot = try await docRef.getDocument(source: .cache)
    XCTAssertTrue(cacheSnapshot.exists)

    let serverData = serverSnapshot.data() as NSDictionary?
    let cacheData = cacheSnapshot.data() as NSDictionary?
    XCTAssertEqual(serverData, cacheData)
  }

  func testQueryLargeDocumentsForcesLocalScan() async throws {
    let colRef = collectionRef()
    defer { Task { try? await db.enableNetwork() } }

    // Populate cache
    _ = try await colRef.document("doc_a").getDocument(source: .server)
    _ = try await colRef.document("doc_b").getDocument(source: .server)

    try await db.disableNetwork()

    // Execute offline query which requires full local index scan
    let query = colRef.order(by: FieldPath.documentID()).limit(to: 2)
    let cacheSnapshot = try await query.getDocuments(source: .cache)

    XCTAssertEqual(cacheSnapshot.documents.count, 2)
    if let firstDoc = cacheSnapshot.documents.first {
      XCTAssertTrue(firstDoc.data().count > 0)
    }
  }

  func testWatchStreamInitializationAndDiff() async throws {
    let docRef = collectionRef().document("doc_15_9MB_unicode")
    let expectation = XCTestExpectation(description: "Wait for differential update payload")

    // Attach listener, must not enter a CANCELLED retry loop
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
      // Must map to standard InvalidArgument/MongoDB compatibility error, not a crash.
      XCTAssertEqual(nsError.code, FirestoreErrorCode.invalidArgument.rawValue)
    }
  }

  func testWriteValidLargeDocument() async throws {
    let tempDocId = "temp_valid_large_doc_\(UUID().uuidString)"
    let docRef = collectionRef().document(tempDocId)
    defer { Task { try? await docRef.delete() } }

    let targetBytes = Int(15.9 * 1024 * 1024)
    let largePayload = generateString(sizeInBytes: targetBytes)

    try await docRef.setData(["chunk": largePayload])

    let snapshot = try await docRef.getDocument(source: .server)
    XCTAssertTrue(snapshot.exists)
    XCTAssertEqual(snapshot.data()?["chunk"] as? String, largePayload)
  }

  func testQueryLargeDocuments() async throws {
    let colRef = collectionRef()
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
    let docRef = collectionRef().document("doc_15_9MB_unicode")

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
