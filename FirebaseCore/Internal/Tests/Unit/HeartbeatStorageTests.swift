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

    var dummyHeartbeatsBundle = HeartbeatsBundle(capacity: 1)
    dummyHeartbeatsBundle.append(Heartbeat(agent: "dummy_agent", date: Date()))

    // When
    heartbeatStorage.readAndWriteAsync { heartbeatsBundle in
      // Assert that heartbeat storage is empty.
      XCTAssertNil(heartbeatsBundle)
      // Write new value.
      return dummyHeartbeatsBundle
    }

    heartbeatStorage.readAndWriteAsync { heartbeatsBundle in
      expectation.fulfill()
      // Assert old value is read.
      XCTAssertEqual(
        heartbeatsBundle?.makeHeartbeatsPayload(),
        dummyHeartbeatsBundle.makeHeartbeatsPayload()
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

    var dummyHeartbeatsBundle = HeartbeatsBundle(capacity: 1)
    dummyHeartbeatsBundle.append(Heartbeat(agent: "dummy_agent", date: Date()))

    // When
    storageFake.onWrite = { _ in
      expectation.fulfill() // Fulfilled 2 times.
      throw StorageError.writeError
    }

    heartbeatStorage.readAndWriteAsync { heartbeatsBundle in
      expectation.fulfill()
      return dummyHeartbeatsBundle
    }

    // Then
    heartbeatStorage.readAndWriteAsync { heartbeatsBundle in
      expectation.fulfill()
      XCTAssertNotEqual(
        heartbeatsBundle?.makeHeartbeatsPayload(),
        dummyHeartbeatsBundle.makeHeartbeatsPayload(),
        "They should not be equal because the previous save failed."
      )
      return dummyHeartbeatsBundle
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

  func testOperationsAreSynrononizedSerially() throws {
    // Given
    let heartbeatStorage = HeartbeatStorage(id: #function, storage: StorageFake())

    // When
    let expectations: [XCTestExpectation] = try (0 ... 1000).map { i in
      let expectation = expectation(description: "\(#function)_\(i)")

      let transform: (HeartbeatsBundle?) -> HeartbeatsBundle? = { heartbeatsBundle in
        expectation.fulfill()
        return heartbeatsBundle
      }

      if /* randomChoice */ .random() {
        heartbeatStorage.readAndWriteAsync(using: transform)
      } else {
        XCTAssertNoThrow(try heartbeatStorage.getAndSet(using: transform))
      }

      return expectation
    }

    // Then
    wait(for: expectations, timeout: 1.0, enforceOrder: true)
  }
}

private class StorageFake: Storage {
  var fakeFile: Data?
  var onRead: (() throws -> Data)?
  var onWrite: ((Data?) throws -> Void)?

  func read() throws -> Data {
    if let onRead = onRead {
      return try onRead()
    } else if let data = fakeFile {
      return data
    } else {
      throw StorageError.readError
    }
  }

  func write(_ data: Data?) throws {
    if let onWrite = onWrite {
      return try onWrite(data)
    } else {
      fakeFile = data
    }
  }
}
