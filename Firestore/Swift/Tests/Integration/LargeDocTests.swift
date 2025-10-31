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

import Combine
import FirebaseFirestore
import Foundation

// iOS 15 required for test implementation, not BSON types
@available(iOS 15, tvOS 15, macOS 12.0, macCatalyst 13, watchOS 7, *)
class LargeDocIntegrationTests: FSTIntegrationTestCase {
  /**
   * Returns a dictionary containing a Data object (blob) with a size approaching
   * the maximum allowed in a Firestore document.
   */
  func getLargestDocContent() -> [String: Any] {
    let maxBytesPerFieldValue = 1_048_487

    // Subtract 8 for '__name__', 20 for its value, and 4 for 'blob'.
    let numBytesToUse = maxBytesPerFieldValue - 8 - 20 - 4

    // Create a buffer to hold the random bytes.
    var bytes = [UInt8](repeating: 0, count: numBytesToUse)

    // Fill the buffer with random bytes.
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    let blobData = Data(bytes)

    return ["blob": blobData]
  }

  func testCanCRUDAndQueryLargeDocuments() async throws {
    let collRef = collectionRef()
    let docRef = collRef.document()
    let data = getLargestDocContent()

    // Set
    try await docRef.setData(data)

    // Get
    var snapshot = try await docRef.getDocument()
    XCTAssertEqual(snapshot.data() as? NSDictionary, data as NSDictionary)

    // Update
    let newData = getLargestDocContent()
    try await docRef.updateData(newData)
    snapshot = try await docRef.getDocument()
    XCTAssertEqual(snapshot.data() as? NSDictionary, newData as NSDictionary)

    // Query
    let querySnapshot = try await collRef.getDocuments()
    XCTAssertEqual(querySnapshot.count, 1)
    XCTAssertEqual(querySnapshot.documents.first?.data() as? NSDictionary, newData as NSDictionary)

    // Delete
    try await docRef.delete()
    snapshot = try await docRef.getDocument()
    XCTAssertFalse(snapshot.exists)
  }

  func testCanCRUDLargeDocumentsInsideTransaction() async throws {
    let collRef = collectionRef()
    let docRef1 = collRef.document()
    let docRef2 = collRef.document()
    let docRef3 = collRef.document()
    let data = getLargestDocContent()
    let newData = getLargestDocContent()

    try await docRef1.setData(data)
    try await docRef3.setData(data)

    _ = try await collRef.firestore.runTransaction { transaction, err -> Any? in
      do {
        // Get and update
        let snapshot = try transaction.getDocument(docRef1)
        XCTAssertEqual(snapshot.data() as? NSDictionary, data as NSDictionary)
        transaction.updateData(newData, forDocument: docRef1)

        // Set
        transaction.setData(data, forDocument: docRef2)

        // Delete
        transaction.deleteDocument(docRef3)

      } catch let fetchError as NSError {
        err?.pointee = fetchError
        return nil
      }
      return nil
    }

    // Verification
    var snapshot = try await docRef1.getDocument()
    XCTAssertEqual(snapshot.data() as? NSDictionary, newData as NSDictionary)

    snapshot = try await docRef2.getDocument()
    XCTAssertEqual(snapshot.data() as? NSDictionary, data as NSDictionary)

    snapshot = try await docRef3.getDocument()
    XCTAssertFalse(snapshot.exists)
  }

  func testListenToLargeQuerySnapshot() throws {
    let collRef = collectionRef()
    let data = getLargestDocContent()

    writeDocumentRef(collRef.document(), data: data)

    // Fulfill an expectation when the listener receives its first snapshot
    let expectation = self.expectation(description: "Query snapshot listener received data")
    var querySnapshot: QuerySnapshot?

    let registration = collRef.addSnapshotListener { snapshot, error in
      XCTAssertNil(error, "Listener returned an error")
      querySnapshot = snapshot!
      expectation.fulfill()
    }

    // Wait for the expectation to be fulfilled
    waitForExpectations(timeout: 5.0)
    registration.remove()

    XCTAssertEqual(querySnapshot!.documents.count, 1)
    XCTAssertEqual(querySnapshot!.documents.first?.data() as? NSDictionary, data as NSDictionary)
  }

  func testListenToLargeDocumentSnapshot() throws {
    let docRef = collectionRef().document()
    let data = getLargestDocContent()

    writeDocumentRef(docRef, data: data)

    // Fulfill an expectation when the listener receives its first snapshot
    let expectation = self.expectation(description: "Document snapshot listener received data")
    var documentSnapshot: DocumentSnapshot?

    let registration = docRef.addSnapshotListener { snapshot, error in
      XCTAssertNil(error, "Listener returned an error")
      documentSnapshot = snapshot
      expectation.fulfill()
    }

    // Wait for the expectation to be fulfilled
    waitForExpectations(timeout: 5.0)
    registration.remove()

    XCTAssertTrue(documentSnapshot!.exists)
    XCTAssertEqual(documentSnapshot!.data() as? NSDictionary, data as NSDictionary)
  }
}
