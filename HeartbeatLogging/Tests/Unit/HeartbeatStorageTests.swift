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

import XCTest
@testable import HeartbeatLogging

// TODO: Add additional validation (#8896 comments).

enum DummyError: Error {
  case error
}

class StorageFake: Storage {
  private var data: Data?

  var failOnNextRead = false
  var failOnNextWrite = false

  func read() throws -> Data {
    if failOnNextRead {
      failOnNextRead.toggle()
      throw DummyError.error
    } else {
      return try data ?? { throw DummyError.error }()
    }
  }

  func write(_ value: Data?) throws {
    if failOnNextWrite {
      failOnNextWrite.toggle()
      throw DummyError.error
    } else {
      data = value
    }
  }
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
      heartbeatStorage1 === heartbeatStorage1,
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
}

// MARK: - HeartbeatStorageProtocol

// test behavior not methods
// test<System Under Test>_<Condition Or State Change>_<Expected Result>()

extension HeartbeatStorageTests {
//  func testGetAndResetThrowsIfSaveFails() {
//    let heartbeatStorage = HeartbeatStorage(
//  }

  func testReadAndWrite_WhenLoadFails_GivesNilInfo() {}

  func testGetAndReset_WhenLoadFails_GivesNilInfo() {}

  func testReadAndWriteAndThenGetAndSet() {
    let storage = HeartbeatStorage(id: #file, storage: StorageFake())

    let expectation = expectation(description: #function)

    storage.readAndWriteAsync { heartbeatInfo in
      XCTAssertNil(heartbeatInfo)
      expectation.fulfill()
      return heartbeatInfo
    }

    wait(for: [expectation], timeout: 0.5)
  }

  func testOperationsAreSynrononizedSerially() throws {
    // Given
    var expectations: [XCTestExpectation] = []
    let heartbeatStorage = HeartbeatStorage(id: #file, storage: StorageFake())

    // When
    for i in 0 ... 1000 {
      let expectation = expectation(description: "\(#function)_\(i)")

      expectations.append(expectation)

      let transform: HeartbeatInfoTransform = { heartbeatInfo in
        expectation.fulfill()
        return heartbeatInfo
      }

      if /* randomChoice */ .random() {
        heartbeatStorage.readAndWriteAsync(using: transform)
      } else {
        try heartbeatStorage.getAndReset(using: transform)
      }
    }

    // Then
    wait(for: expectations, timeout: 1.0, enforceOrder: true)
  }
}

// MARK: - HeartbeatStorage + StorageFactory

// extension HeartbeatStorageTests {
//  func testOfferHeartbeatThenFlush() throws {
//    // Given
//    let storage = HeartbeatStorage(id: #file, storage: StorageFake())
//    XCTAssertNil(storage.flush())
//    // When
//    storage.offer(Heartbeat(info: #function))
//    // Then
//    XCTAssertNotNil(storage.flush())
//  }
//
//  func testOfferHeartbeatWithStorageReadError() throws {
//    // Given
//    let (storageFake, queue) = (StorageFake(), DispatchQueue(label: #function))
//    let storage = HeartbeatStorage(id: #file, storage: storageFake, queue: queue)
//    XCTAssertNil(storage.flush())
//    storageFake.failOnNextRead = true
//    // When
//    storage.offer(Heartbeat(info: #function))
//    // Then
//    drain(queue)
//    // Expect
//    XCTAssertNotNil(storage.flush())
//  }
//
//  func testOfferHeartbeatWithStorageWriteError() throws {
//    // Given
//    let (storageFake, queue) = (StorageFake(), DispatchQueue(label: #function))
//    let storage = HeartbeatStorage(id: #file, storage: storageFake, queue: queue)
//    XCTAssertNil(storage.flush())
//    storage.offer(Heartbeat(info: #function))
//    drain(queue)
//    storageFake.failOnNextWrite = true
//    // When
//    storage.offer(Heartbeat(info: #function))
//    // Then
//    drain(queue)
//    // Expect
//    XCTAssertNotNil(storage.flush())
//  }
//
//  func testOfferHeartbeatWithEncodingError() throws {
//    // Given
//    let coderFake = CoderFake()
//    let storage = HeartbeatStorage(id: #file, storage: StorageFake(), coder: coderFake)
//    XCTAssertNil(storage.flush())
//    coderFake.failOnNextEncode = true
//    // When
//    storage.offer(Heartbeat(info: #function))
//    // Then
//    XCTAssertNil(storage.flush())
//  }
//
//  func testOfferHeartbeatWithDecodingError() throws {
//    // Given
//    let coderFake = CoderFake()
//    let storage = HeartbeatStorage(id: #file, storage: StorageFake(), coder: coderFake)
//    coderFake.failOnNextDecode = true
//    // When
//    storage.offer(Heartbeat(info: #function))
//    // Then
//    XCTAssertNil(storage.flush())
//  }
//
//  func testOfferHeartbeatWithErrorThenOffer() throws {
//    // Given
//    let (storageFake, queue) = (StorageFake(), DispatchQueue(label: #function))
//    let storage = HeartbeatStorage(id: #file, storage: storageFake, queue: queue)
//    storageFake.failOnNextWrite = true
//    storage.offer(Heartbeat(info: #function))
//    drain(queue)
//    XCTAssertNil(storage.flush())
//    // When
//    storage.offer(Heartbeat(info: #function))
//    // Then
//    drain(queue)
//    // Expect
//    XCTAssertNotNil(storage.flush())
//  }
//
//  func testFlushWithStorageReadError() throws {
//    // Given
//    let (storageFake, queue) = (StorageFake(), DispatchQueue(label: #function))
//    let storage = HeartbeatStorage(id: #file, storage: storageFake, queue: queue)
//    // Storage is non-empty.
//    storage.offer(Heartbeat(info: #function))
//    drain(queue)
//    storageFake.failOnNextRead = true
//    // When
//    let flushed = storage.flush()
//    // Then
//    XCTAssertNil(flushed)
//    // Storage should empty on successful flush to recover for future reads.
//    XCTAssertNil(storage.flush())
//  }
//
//  func testFlushWithStorageWriteError() throws {
//    // Given
//    let (storageFake, queue) = (StorageFake(), DispatchQueue(label: #function))
//    let storage = HeartbeatStorage(id: #file, storage: storageFake, queue: queue)
//    // Storage is non-empty.
//    storage.offer(Heartbeat(info: #function))
//    drain(queue)
//    storageFake.failOnNextWrite = true
//    // When
//    let flushed = storage.flush()
//    // Then
//    XCTAssertNil(flushed)
//    // Flushing storage returns flushed contents when flush was successful.
//    XCTAssertNotNil(storage.flush())
//  }
// }
//
///// Dispatches a block to a given queue and returns when the block has executed.
///// - Parameter queue: The queue to drain.
// func drain(_ queue: DispatchQueue) {
//  queue.sync {}
// }
//
//// MARK: - Fakes
//
// private extension HeartbeatStorageTests {
//  enum DummyError: Error {
//    case error
//  }
//
//  class StorageFake: PersistentStorage {
//    private var data: Data?
//
//    var failOnNextRead = false
//    var failOnNextWrite = false
//
//    func read() throws -> Data {
//      if failOnNextRead {
//        failOnNextRead.toggle()
//        throw DummyError.error
//      } else {
//        return try data ?? { throw DummyError.error }()
//      }
//    }
//
//    func write(_ value: Data?) throws {
//      if failOnNextWrite {
//        failOnNextWrite.toggle()
//        throw DummyError.error
//      } else {
//        data = value
//      }
//    }
//  }
//
//  class CoderFake: Coder {
//    var failOnNextDecode = false
//    var failOnNextEncode = false
//
//    func decode<T>(_ type: T.Type,
//                   from data: Data) throws -> T where T: Decodable {
//      if failOnNextDecode {
//        failOnNextDecode.toggle()
//        throw DummyError.error
//      } else {
//        return try JSONDecoder().decode(type, from: data)
//      }
//    }
//
//    func encode<T>(_ value: T) throws -> Data where T: Encodable {
//      if failOnNextEncode {
//        failOnNextEncode.toggle()
//        throw DummyError.error
//      } else {
//        return try JSONEncoder().encode(value)
//      }
//    }
//  }
// }
