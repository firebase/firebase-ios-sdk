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

@testable import FirebaseFirestore
import XCTest

// MARK: - Mock Objects for Testing

private class MockListenerRegistration: ListenerRegistration {
  var isRemoved = false
  func remove() {
    isRemoved = true
  }
}

private typealias SnapshotListener = (QuerySnapshot?, Error?) -> Void
private typealias DocumentSnapshotListener = (DocumentSnapshot?, Error?) -> Void

private class MockQuery: Query {
  var capturedListener: SnapshotListener?
  let mockListenerRegistration = MockListenerRegistration()

  override func addSnapshotListener(_ listener: @escaping SnapshotListener)
    -> ListenerRegistration {
    capturedListener = listener
    return mockListenerRegistration
  }

  override func addSnapshotListener(includeMetadataChanges: Bool,
                                    listener: @escaping SnapshotListener) -> ListenerRegistration {
    capturedListener = listener
    return mockListenerRegistration
  }
}

private class MockDocumentReference: DocumentReference {
  var capturedListener: DocumentSnapshotListener?
  let mockListenerRegistration = MockListenerRegistration()

  override func addSnapshotListener(_ listener: @escaping DocumentSnapshotListener)
    -> ListenerRegistration {
    capturedListener = listener
    return mockListenerRegistration
  }

  override func addSnapshotListener(includeMetadataChanges: Bool,
                                    listener: @escaping DocumentSnapshotListener)
    -> ListenerRegistration {
    capturedListener = listener
    return mockListenerRegistration
  }
}

// MARK: - AsyncSequenceTests

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AsyncSequenceTests: XCTestCase {
  func testQuerySnapshotsYieldsValues() async throws {
    let mockQuery = MockQuery()
    let expectation = XCTestExpectation(description: "Received snapshot")

    let task = Task {
      for try await _ in mockQuery.snapshots {
        expectation.fulfill()
        break // Exit after first result
      }
    }

    // Ensure the listener has been set up
    XCTAssertNotNil(mockQuery.capturedListener)

    // Simulate a snapshot event
    mockQuery.capturedListener?(QuerySnapshot(), nil)

    await fulfillment(of: [expectation], timeout: 1.0)
    task.cancel()
  }

  func testQuerySnapshotsThrowsErrors() async throws {
    let mockQuery = MockQuery()
    let expectedError = NSError(domain: "TestError", code: 123, userInfo: nil)
    var receivedError: Error?

    let task = Task {
      do {
        for try await _ in mockQuery.snapshots {
          XCTFail("Should not have received a value.")
        }
      } catch {
        receivedError = error
      }
    }

    // Ensure the listener has been set up
    XCTAssertNotNil(mockQuery.capturedListener)

    // Simulate an error event
    mockQuery.capturedListener?(nil, expectedError)

    // Allow the task to process the error
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertNotNil(receivedError)
    XCTAssertEqual((receivedError as NSError?)?.domain, expectedError.domain)
    XCTAssertEqual((receivedError as NSError?)?.code, expectedError.code)
    task.cancel()
  }

  func testQuerySnapshotsCancellationRemovesListener() async throws {
    let mockQuery = MockQuery()

    let task = Task {
      for try await _ in mockQuery.snapshots {
        XCTFail("Should not receive any values as the task is cancelled immediately.")
      }
    }

    // Ensure the listener was attached before we cancel
    XCTAssertNotNil(mockQuery.capturedListener)
    XCTAssertFalse(mockQuery.mockListenerRegistration.isRemoved)

    task.cancel()

    // Allow time for the cancellation handler to execute
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertTrue(mockQuery.mockListenerRegistration.isRemoved)
  }

  func testDocumentReferenceSnapshotsYieldsValues() async throws {
    let mockDocRef = MockDocumentReference()
    let expectation = XCTestExpectation(description: "Received document snapshot")

    let task = Task {
      for try await _ in mockDocRef.snapshots {
        expectation.fulfill()
        break
      }
    }

    XCTAssertNotNil(mockDocRef.capturedListener)
    mockDocRef.capturedListener?(DocumentSnapshot(), nil)

    await fulfillment(of: [expectation], timeout: 1.0)
    task.cancel()
  }

  func testDocumentReferenceSnapshotsCancellationRemovesListener() async throws {
    let mockDocRef = MockDocumentReference()

    let task = Task {
      for try await _ in mockDocRef.snapshots {
        XCTFail("Should not receive values.")
      }
    }

    XCTAssertNotNil(mockDocRef.capturedListener)
    XCTAssertFalse(mockDocRef.mockListenerRegistration.isRemoved)

    task.cancel()
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertTrue(mockDocRef.mockListenerRegistration.isRemoved)
  }
}
