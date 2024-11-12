// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import FirebaseCoreInternal
import XCTest

extension HeartbeatsBundle {
  static let testHeartbeatBundle: Self = {
    var heartbeatBundle = HeartbeatsBundle(capacity: 1)
    heartbeatBundle.append(Heartbeat(agent: "dummy_agent", date: Date()))
    return heartbeatBundle
  }()
}

class HeartbeatStorageTests: XCTestCase {
  // MARK: - Instance Management

  func testGettingInstance_WithSameID_ReturnsSameInstance() {
    // Given
    let heartbeatStorage1 = HeartbeatStorage.getInstance(id: "sparky")
    // When
    let heartbeatStorage2 = HeartbeatStorage.getInstance(id: "sparky")
    // Then
    XCTAssert(
      heartbeatStorage1 === heartbeatStorage2,
      "Instances should reference the same object."
    )

    addTeardownBlock { [weak heartbeatStorage1, weak heartbeatStorage2] in
      XCTAssertNil(heartbeatStorage1)
      XCTAssertNil(heartbeatStorage2)
    }
  }

  func testGettingInstance_WithDifferentID_ReturnsDifferentInstances() {
    // Given
    let heartbeatStorage1 = HeartbeatStorage.getInstance(id: "sparky_jr")
    // When
    let heartbeatStorage2 = HeartbeatStorage.getInstance(id: "sparky_sr")
    // Then
    XCTAssert(
      heartbeatStorage1 !== heartbeatStorage2,
      "Instances should NOT reference the same object."
    )

    addTeardownBlock { [weak heartbeatStorage1, weak heartbeatStorage2] in
      XCTAssertNil(heartbeatStorage1)
      XCTAssertNil(heartbeatStorage2)
    }
  }

  func testCachedInstancesCannotBeRetainedWeakly() {
    // Given
    var strongHeartbeatStorage: HeartbeatStorage? = .getInstance(id: "sparky")
    weak var weakHeartbeatStorage: HeartbeatStorage? = .getInstance(id: "sparky")
    XCTAssert(
      strongHeartbeatStorage === weakHeartbeatStorage,
      "Instances should reference the same object."
    )

    // When
    strongHeartbeatStorage = nil

    // Then
    XCTAssertNil(strongHeartbeatStorage)
    XCTAssertNil(weakHeartbeatStorage)
  }

  func testCachedInstancesAreRemovedUponDeinitAndCanBeRetainedStrongly() {
    // Given
    var heartbeatStorage1: HeartbeatStorage? = .getInstance(id: "sparky")
    var heartbeatStorage2: HeartbeatStorage? = .getInstance(id: "sparky")
    XCTAssert(
      heartbeatStorage1 === heartbeatStorage2,
      "Instances should reference the same object."
    )

    // When
    heartbeatStorage1 = nil
    XCTAssertNil(heartbeatStorage1)
    XCTAssertNotNil(heartbeatStorage2)

    // Then
    heartbeatStorage2 = nil
    XCTAssertNil(heartbeatStorage2)
  }

  // MARK: - HeartbeatStorageProtocol

  func testReadAndWrite_ReadsOldValueAndWritesNewValue() throws {
    // Given
    let expectation = expectation(description: #function)
    let heartbeatStorage = HeartbeatStorage(id: #function, storage: StorageFake())

    // When
    heartbeatStorage.readAndWriteAsync { heartbeatsBundle in
      // Assert that heartbeat storage is empty.
      XCTAssertNil(heartbeatsBundle)
      // Write new value.
      return HeartbeatsBundle.testHeartbeatBundle
    }

    heartbeatStorage.readAndWriteAsync { heartbeatsBundle in
      expectation.fulfill()
      // Assert old value is read.
      XCTAssertEqual(
        heartbeatsBundle?.makeHeartbeatsPayload(),
        HeartbeatsBundle.testHeartbeatBundle.makeHeartbeatsPayload()
      )
      // Write some new value.
      return heartbeatsBundle
    }

    // Then
    wait(for: [expectation], timeout: 0.5)
  }

  func testReadAndWrite_WhenLoadFails_PassesNilToBlock() throws {
    // Given
    let expectation = expectation(description: #function)
    let heartbeatStorage = HeartbeatStorage(id: #function, storage: StorageFake())

    // When
    heartbeatStorage.readAndWriteAsync { heartbeatsBundle in
      expectation.fulfill()
      XCTAssertNil(heartbeatsBundle)
      return heartbeatsBundle
    }

    // Then
    wait(for: [expectation], timeout: 0.5)
  }

  func testReadAndWrite_WhenSaveFails_DoesNotAttemptRecovery() throws {
    // Given
    let expectation = expectation(description: #function)
    expectation.expectedFulfillmentCount = 4

    let storageFake = StorageFake()
    let heartbeatStorage = HeartbeatStorage(id: #function, storage: storageFake)

    // When
    storageFake.onWrite = { _ in
      expectation.fulfill() // Fulfilled 2 times.
      throw StorageError.writeError
    }

    heartbeatStorage.readAndWriteAsync { heartbeatsBundle in
      expectation.fulfill()
      return HeartbeatsBundle.testHeartbeatBundle
    }

    // Then
    heartbeatStorage.readAndWriteAsync { heartbeatsBundle in
      expectation.fulfill()
      XCTAssertNotEqual(
        heartbeatsBundle?.makeHeartbeatsPayload(),
        HeartbeatsBundle.testHeartbeatBundle.makeHeartbeatsPayload(),
        "They should not be equal because the previous save failed."
      )
      return HeartbeatsBundle.testHeartbeatBundle
    }

    wait(for: [expectation], timeout: 0.5)
  }

  func testGetAndSet_ReturnsOldValueAndSetsNewValue() throws {
    // Given
    let expectation = expectation(description: #function)
    let heartbeatStorage = HeartbeatStorage(id: #function, storage: StorageFake())

    var dummyHeartbeatsBundle = HeartbeatsBundle(capacity: 1)
    dummyHeartbeatsBundle.append(Heartbeat(agent: "dummy_agent", date: Date()))

    // When
    XCTAssertNoThrow(
      try heartbeatStorage.getAndSet { heartbeatsBundle in
        // Assert that heartbeat storage is empty.
        XCTAssertNil(heartbeatsBundle)
        // Write new value.
        return dummyHeartbeatsBundle
      }
    )

    // Then
    XCTAssertNoThrow(
      try heartbeatStorage.getAndSet { heartbeatsBundle in
        expectation.fulfill()
        // Assert old value is read.
        XCTAssertEqual(
          heartbeatsBundle?.makeHeartbeatsPayload(),
          dummyHeartbeatsBundle.makeHeartbeatsPayload()
        )
        // Write some new value.
        return heartbeatsBundle
      }
    )

    wait(for: [expectation], timeout: 0.5)
  }

  func testGetAndSetAsync_ReturnsOldValueAndSetsNewValue() throws {
    // Given
    let heartbeatStorage = HeartbeatStorage(id: #function, storage: StorageFake())

    // When
    let expectation1 = expectation(description: #function + "_1")
    heartbeatStorage.getAndSetAsync { heartbeatsBundle in
      // Assert that heartbeat storage is empty.
      XCTAssertNil(heartbeatsBundle)
      // Write new value.
      return HeartbeatsBundle.testHeartbeatBundle
    } completion: { result in
      switch result {
      case .success: break
      case let .failure(error): XCTFail("Error: \(error)")
      }
      expectation1.fulfill()
    }

    // Then
    let expectation2 = expectation(description: #function + "_2")
    XCTAssertNoThrow(
      try heartbeatStorage.getAndSet { heartbeatsBundle in
        // Assert old value is read.
        XCTAssertEqual(
          heartbeatsBundle?.makeHeartbeatsPayload(),
          HeartbeatsBundle.testHeartbeatBundle.makeHeartbeatsPayload()
        )
        // Write some new value.
        expectation2.fulfill()
        return heartbeatsBundle
      }
    )

    wait(for: [expectation1, expectation2], timeout: 0.5, enforceOrder: true)
  }

  func testGetAndSet_WhenLoadFails_PassesNilToBlockAndReturnsNil() throws {
    // Given
    let expectation = expectation(description: #function)
    expectation.expectedFulfillmentCount = 2

    let storageFake = StorageFake()
    let heartbeatStorage = HeartbeatStorage(id: #function, storage: storageFake)

    // When
    storageFake.onRead = {
      expectation.fulfill()
      return try XCTUnwrap("BAD_DATA".data(using: .utf8))
    }

    // Then
    try heartbeatStorage.getAndSet { heartbeatsBundle in
      expectation.fulfill()
      XCTAssertNil(heartbeatsBundle)
      return heartbeatsBundle
    }

    wait(for: [expectation], timeout: 0.5)
  }

  func testGetAndSetAsync_WhenLoadFails_PassesNilToBlockAndReturnsNil() throws {
    // Given
    let readExpectation = expectation(description: #function + "_1")
    let transformExpectation = expectation(description: #function + "_2")
    let completionExpectation = expectation(description: #function + "_3")

    let storageFake = StorageFake()
    let heartbeatStorage = HeartbeatStorage(id: #function, storage: storageFake)

    // When
    storageFake.onRead = {
      readExpectation.fulfill()
      return try XCTUnwrap("BAD_DATA".data(using: .utf8))
    }

    // Then
    heartbeatStorage.getAndSetAsync { heartbeatsBundle in
      XCTAssertNil(heartbeatsBundle)
      transformExpectation.fulfill()
      return heartbeatsBundle
    } completion: { result in
      switch result {
      case .success: break
      case let .failure(error): XCTFail("Error: \(error)")
      }
      completionExpectation.fulfill()
    }

    wait(
      for: [readExpectation, transformExpectation, completionExpectation],
      timeout: 0.5,
      enforceOrder: true
    )
  }

  func testGetAndSet_WhenSaveFails_ThrowsError() throws {
    // Given
    let expectation = expectation(description: #function)
    let storageFake = StorageFake()
    let heartbeatStorage = HeartbeatStorage(id: #function, storage: storageFake)

    // When
    storageFake.onWrite = { _ in
      expectation.fulfill()
      throw StorageError.writeError
    }

    // Then
    XCTAssertThrowsError(try heartbeatStorage.getAndSet { $0 })

    wait(for: [expectation], timeout: 0.5)
  }

  func testGetAndSetAsync_WhenSaveFails_ThrowsError() throws {
    // Given
    let transformExpectation = expectation(description: #function + "_1")
    let writeExpectation = expectation(description: #function + "_2")
    let completionExpectation = expectation(description: #function + "_3")

    let storageFake = StorageFake()
    let heartbeatStorage = HeartbeatStorage(id: #function, storage: storageFake)

    // When
    storageFake.onWrite = { _ in
      writeExpectation.fulfill()
      throw StorageError.writeError
    }

    // Then
    heartbeatStorage.getAndSetAsync { heartbeatsBundle in
      transformExpectation.fulfill()
      XCTAssertNil(heartbeatsBundle)
      return heartbeatsBundle
    } completion: { result in
      switch result {
      case .success: XCTFail("Error: unexpected success")
      case .failure: break
      }
      completionExpectation.fulfill()
    }

    wait(
      for: [transformExpectation, writeExpectation, completionExpectation],
      timeout: 0.5,
      enforceOrder: true
    )
  }

  func testOperationsAreSyncrononizedSerially() throws {
    // Given
    let heartbeatStorage = HeartbeatStorage(id: #function, storage: StorageFake())

    // When
    let expectations: [XCTestExpectation] = try (0 ... 1000).map { i in
      let expectation = expectation(description: "\(#function)_\(i)")

      let transform: @Sendable (HeartbeatsBundle?) -> HeartbeatsBundle? = { heartbeatsBundle in
        expectation.fulfill()
        return heartbeatsBundle
      }

      switch Int.random(in: 1 ... 3) {
      case 1:
        heartbeatStorage.readAndWriteAsync(using: transform)
      case 2:
        XCTAssertNoThrow(try heartbeatStorage.getAndSet(using: transform))
      case 3:
        let getAndSet = self.expectation(description: "GetAndSetAsync_\(i)")
        heartbeatStorage.getAndSetAsync(using: transform) { result in
          switch result {
          case .success: break
          case let .failure(error):
            XCTFail("Unexpected: Error occurred in getAndSet_\(i), \(error)")
          }
          getAndSet.fulfill()
        }
        wait(for: [getAndSet], timeout: 1.0)
      default:
        XCTFail("Unexpected: Random number is out of range.")
      }

      return expectation
    }

    // Then
    wait(for: expectations, timeout: 1.0, enforceOrder: true)
  }

  func testForMemoryLeakInInstanceManager() {
    // This unchecked Sendable class is used to avoid passing a non-sendable
    // type '[WeakContainer<HeartbeatStorage>]' to a `@Sendable` closure
    // (`DispatchQueue.global().async { ... }`).
    final class WeakRefs: @unchecked Sendable {
      private(set) var weakRefs: [WeakContainer<HeartbeatStorage>] = []
      // Lock is used to synchronize `weakRefs` during concurrent access.
      private let weakRefsLock = NSLock()

      func append(_ weakRef: WeakContainer<HeartbeatStorage>) {
        weakRefsLock.withLock {
          weakRefs.append(weakRef)
        }
      }
    }

    // Given
    let id = "testID"
    let weakRefs = WeakRefs()

    // When
    // Simulate concurrent access. This will help expose race conditions that could cause a crash.
    let group = DispatchGroup()
    for _ in 0 ..< 100 {
      group.enter()
      DispatchQueue.global().async {
        let instance = HeartbeatStorage.getInstance(id: id)
        weakRefs.append(WeakContainer(object: instance))
        group.leave()
      }
    }
    group.wait()

    // Then
    // The `weakRefs` array's references should all be nil; otherwise, something is being
    // unexpectedly strongly retained.
    for weakRef in weakRefs.weakRefs {
      XCTAssertNil(weakRef.object, "Potential memory leak detected.")
    }
  }
}

private final class StorageFake: Storage, @unchecked Sendable {
  // The unchecked Sendable conformance is used to prevent warnings for the below var, which
  // violates the class's Sendable conformance. Ignoring this violation should be okay for
  // testing purposes.
  var fakeFile: Data?
  var onRead: (() throws -> Data)?
  var onWrite: ((Data?) throws -> Void)?

  func read() throws -> Data {
    if let onRead {
      return try onRead()
    } else if let data = fakeFile {
      return data
    } else {
      throw StorageError.readError
    }
  }

  func write(_ data: Data?) throws {
    if let onWrite {
      return try onWrite(data)
    } else {
      fakeFile = data
    }
  }
}
