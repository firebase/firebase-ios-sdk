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

import FirebaseDatabase
import Foundation
import XCTest

// MARK: - Test Helpers & Mocks

private enum TestError: Error, Equatable {
  case mockError
}

private final class MockDataSnapshot: DataSnapshot, @unchecked Sendable {
  private let mockKey: String
  private let mockValue: Any?

  init(key: String, value: Any? = nil) {
    mockKey = key
    mockValue = value
    super.init()
  }

  override var key: String {
    mockKey
  }

  override var value: Any? {
    mockValue
  }
}

private final class MockDatabaseQuery: DatabaseQuery, @unchecked Sendable {
  struct ValueObserver {
    let handle: DatabaseHandle
    let eventType: DataEventType
    let block: (DataSnapshot) -> Void
    let cancelBlock: ((Error) -> Void)?
  }

  struct SiblingObserver {
    let handle: DatabaseHandle
    let eventType: DataEventType
    let block: (DataSnapshot, String?) -> Void
    let cancelBlock: ((Error) -> Void)?
  }

  private let lock = NSLock()
  private var nextHandle: DatabaseHandle = 1
  private var _valueObservers: [ValueObserver] = []
  private var _siblingObservers: [SiblingObserver] = []
  private var _removedHandles: [DatabaseHandle] = []

  var observerAttachedExpectation: XCTestExpectation?
  var observerRemovedExpectation: XCTestExpectation?

  var valueObservers: [ValueObserver] {
    lock.lock()
    defer { lock.unlock() }
    return _valueObservers
  }

  var siblingObservers: [SiblingObserver] {
    lock.lock()
    defer { lock.unlock() }
    return _siblingObservers
  }

  var removedHandles: [DatabaseHandle] {
    lock.lock()
    defer { lock.unlock() }
    return _removedHandles
  }

  override func observe(_ eventType: DataEventType,
                        with block: @escaping (DataSnapshot) -> Void,
                        withCancel cancelBlock: ((any Error) -> Void)?) -> DatabaseHandle {
    lock.lock()
    let handle = nextHandle
    nextHandle += 1
    _valueObservers.append(
      ValueObserver(
        handle: handle,
        eventType: eventType,
        block: block,
        cancelBlock: cancelBlock
      )
    )
    let expectation = observerAttachedExpectation
    lock.unlock()

    expectation?.fulfill()
    return handle
  }

  override func observe(_ eventType: DataEventType,
                        andPreviousSiblingKeyWith block: @escaping (DataSnapshot, String?) -> Void,
                        withCancel cancelBlock: ((any Error) -> Void)?) -> DatabaseHandle {
    lock.lock()
    let handle = nextHandle
    nextHandle += 1
    _siblingObservers.append(
      SiblingObserver(
        handle: handle,
        eventType: eventType,
        block: block,
        cancelBlock: cancelBlock
      )
    )
    let expectation = observerAttachedExpectation
    lock.unlock()

    expectation?.fulfill()
    return handle
  }

  override func removeObserver(withHandle handle: DatabaseHandle) {
    lock.lock()
    _removedHandles.append(handle)
    _valueObservers.removeAll { $0.handle == handle }
    _siblingObservers.removeAll { $0.handle == handle }
    let expectation = observerRemovedExpectation
    lock.unlock()

    expectation?.fulfill()
  }

  func sendValue(_ snapshot: DataSnapshot, for eventType: DataEventType = .value) {
    let matching = valueObservers.filter { $0.eventType == eventType }
    for observer in matching {
      observer.block(snapshot)
    }
  }

  func sendSiblingEvent(_ eventType: DataEventType,
                        snapshot: DataSnapshot,
                        previousSiblingKey: String? = nil) {
    let matching = siblingObservers.filter { $0.eventType == eventType }
    for observer in matching {
      observer.block(snapshot, previousSiblingKey)
    }
  }

  func sendError(_ error: Error, for eventType: DataEventType) {
    for observer in valueObservers where observer.eventType == eventType {
      observer.cancelBlock?(error)
    }
    for observer in siblingObservers where observer.eventType == eventType {
      observer.cancelBlock?(error)
    }
  }
}

// MARK: - AsyncSequenceTests

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
final class AsyncSequenceTests: XCTestCase {
  private var mockQuery: MockDatabaseQuery!

  override func setUp() {
    super.setUp()
    mockQuery = MockDatabaseQuery()
  }

  override func tearDown() {
    mockQuery = nil
    super.tearDown()
  }

  // MARK: - snapshots Tests

  func testSnapshotsYieldsSingleValue() async throws {
    let attachedExpectation = expectation(description: "Value observer should be attached")
    let receivedExpectation = expectation(description: "Snapshot should be received")
    let removedExpectation = expectation(description: "Value observer should be removed on break")
    mockQuery.observerAttachedExpectation = attachedExpectation
    mockQuery.observerRemovedExpectation = removedExpectation

    let query = mockQuery!
    let task = Task {
      for try await snapshot in query.snapshots {
        XCTAssertEqual(snapshot.key, "user1")
        XCTAssertEqual(snapshot.value as? String, "Alice")
        receivedExpectation.fulfill()
        break
      }
    }

    await fulfillment(of: [attachedExpectation], timeout: 1.0)
    XCTAssertEqual(query.valueObservers.count, 1)
    XCTAssertEqual(query.valueObservers.first?.eventType, .value)

    query.sendValue(MockDataSnapshot(key: "user1", value: "Alice"))

    await fulfillment(of: [receivedExpectation], timeout: 1.0)
    try await task.value

    await fulfillment(of: [removedExpectation], timeout: 1.0)
    XCTAssertEqual(query.removedHandles, [1])
  }

  func testSnapshotsYieldsMultipleValues() async throws {
    let attachedExpectation = expectation(description: "Value observer should be attached")
    let receivedExpectation = expectation(description: "Three snapshots should be received")
    receivedExpectation.expectedFulfillmentCount = 3
    let removedExpectation = expectation(description: "Value observer should be removed on break")
    mockQuery.observerAttachedExpectation = attachedExpectation
    mockQuery.observerRemovedExpectation = removedExpectation

    let query = mockQuery!
    let task = Task { () -> [String] in
      var keys: [String] = []
      for try await snapshot in query.snapshots {
        keys.append(snapshot.key)
        receivedExpectation.fulfill()
        if keys.count == 3 {
          break
        }
      }
      return keys
    }

    await fulfillment(of: [attachedExpectation], timeout: 1.0)

    query.sendValue(MockDataSnapshot(key: "snap1", value: 1))
    query.sendValue(MockDataSnapshot(key: "snap2", value: 2))
    query.sendValue(MockDataSnapshot(key: "snap3", value: 3))

    await fulfillment(of: [receivedExpectation], timeout: 1.0)
    let receivedKeys = try await task.value
    XCTAssertEqual(receivedKeys, ["snap1", "snap2", "snap3"])

    await fulfillment(of: [removedExpectation], timeout: 1.0)
    XCTAssertEqual(query.removedHandles, [1])
  }

  func testSnapshotsThrowsErrorOnCancel() async throws {
    let attachedExpectation = expectation(description: "Value observer should be attached")
    let removedExpectation = expectation(description: "Value observer should be removed")
    mockQuery.observerAttachedExpectation = attachedExpectation
    mockQuery.observerRemovedExpectation = removedExpectation

    let query = mockQuery!
    let task = Task { () -> Error? in
      do {
        for try await _ in query.snapshots {
          XCTFail("Snapshots stream should not emit values when cancelled with error")
        }
        return nil
      } catch {
        return error
      }
    }

    await fulfillment(of: [attachedExpectation], timeout: 1.0)
    query.sendError(TestError.mockError, for: .value)

    let caughtError = await task.value
    XCTAssertEqual(caughtError as? TestError, .mockError)

    await fulfillment(of: [removedExpectation], timeout: 1.0)
    XCTAssertEqual(query.removedHandles, [1])
  }

  func testSnapshotsRemovesObserverOnTaskCancellation() async throws {
    let attachedExpectation = expectation(description: "Value observer should be attached")
    let removedExpectation = expectation(description: "Value observer should be removed")
    mockQuery.observerAttachedExpectation = attachedExpectation
    mockQuery.observerRemovedExpectation = removedExpectation

    let query = mockQuery!
    let task = Task {
      for try await _ in query.snapshots {
        XCTFail("Snapshots stream should not emit values")
      }
    }

    await fulfillment(of: [attachedExpectation], timeout: 1.0)
    let registeredHandle = try XCTUnwrap(query.valueObservers.first?.handle)

    task.cancel()

    await fulfillment(of: [removedExpectation], timeout: 1.0)
    XCTAssertEqual(query.removedHandles, [registeredHandle])
  }

  // MARK: - childEvents Tests

  func testChildEventsYieldsAllEventTypes() async throws {
    let attachedExpectation = expectation(description: "All 4 child observers should be attached")
    attachedExpectation.expectedFulfillmentCount = 4
    let receivedExpectation = expectation(description: "All 4 child events should be received")
    receivedExpectation.expectedFulfillmentCount = 4
    let removedExpectation = expectation(
      description: "All 4 child observers should be removed on break"
    )
    removedExpectation.expectedFulfillmentCount = 4
    mockQuery.observerAttachedExpectation = attachedExpectation
    mockQuery.observerRemovedExpectation = removedExpectation

    let query = mockQuery!
    let task = Task { () -> [ChildEvent] in
      var events: [ChildEvent] = []
      for try await event in query.childEvents {
        events.append(event)
        receivedExpectation.fulfill()
        if events.count == 4 {
          break
        }
      }
      return events
    }

    await fulfillment(of: [attachedExpectation], timeout: 1.0)
    XCTAssertEqual(
      query.siblingObservers.map(\.eventType),
      [.childAdded, .childChanged, .childMoved]
    )
    XCTAssertEqual(query.valueObservers.map(\.eventType), [.childRemoved])

    query.sendSiblingEvent(
      .childAdded,
      snapshot: MockDataSnapshot(key: "item1", value: "A"),
      previousSiblingKey: nil
    )
    query.sendSiblingEvent(
      .childChanged,
      snapshot: MockDataSnapshot(key: "item1", value: "B"),
      previousSiblingKey: "item0"
    )
    query.sendSiblingEvent(
      .childMoved,
      snapshot: MockDataSnapshot(key: "item1", value: "B"),
      previousSiblingKey: "item2"
    )
    query.sendValue(
      MockDataSnapshot(key: "item1", value: "B"),
      for: .childRemoved
    )

    await fulfillment(of: [receivedExpectation], timeout: 1.0)
    let events = try await task.value
    XCTAssertEqual(events.count, 4)

    await fulfillment(of: [removedExpectation], timeout: 1.0)
    XCTAssertEqual(query.removedHandles, [1, 2, 3, 4])

    if case let .added(snapshot, previousKey) = events[0] {
      XCTAssertEqual(snapshot.key, "item1")
      XCTAssertEqual(snapshot.value as? String, "A")
      XCTAssertNil(previousKey)
    } else {
      XCTFail("Expected .added at index 0")
    }

    if case let .changed(snapshot, previousKey) = events[1] {
      XCTAssertEqual(snapshot.key, "item1")
      XCTAssertEqual(snapshot.value as? String, "B")
      XCTAssertEqual(previousKey, "item0")
    } else {
      XCTFail("Expected .changed at index 1")
    }

    if case let .moved(snapshot, previousKey) = events[2] {
      XCTAssertEqual(snapshot.key, "item1")
      XCTAssertEqual(snapshot.value as? String, "B")
      XCTAssertEqual(previousKey, "item2")
    } else {
      XCTFail("Expected .moved at index 2")
    }

    if case let .removed(snapshot) = events[3] {
      XCTAssertEqual(snapshot.key, "item1")
      XCTAssertEqual(snapshot.value as? String, "B")
    } else {
      XCTFail("Expected .removed at index 3")
    }
  }

  func testChildEventsThrowsErrorOnCancel() async throws {
    let attachedExpectation = expectation(description: "All 4 child observers should be attached")
    attachedExpectation.expectedFulfillmentCount = 4
    let removedExpectation = expectation(description: "All 4 child observers should be removed")
    removedExpectation.expectedFulfillmentCount = 4
    mockQuery.observerAttachedExpectation = attachedExpectation
    mockQuery.observerRemovedExpectation = removedExpectation

    let query = mockQuery!
    let task = Task { () -> Error? in
      do {
        for try await _ in query.childEvents {
          XCTFail("Child events stream should not emit values when cancelled with error")
        }
        return nil
      } catch {
        return error
      }
    }

    await fulfillment(of: [attachedExpectation], timeout: 1.0)
    for eventType: DataEventType in [.childAdded, .childChanged, .childRemoved, .childMoved] {
      query.sendError(TestError.mockError, for: eventType)
    }

    let caughtError = await task.value
    XCTAssertEqual(caughtError as? TestError, .mockError)

    await fulfillment(of: [removedExpectation], timeout: 1.0)
    XCTAssertEqual(Set(query.removedHandles), Set([1, 2, 3, 4]))
  }

  func testChildEventsRemovesAllObserversOnTaskCancellation() async throws {
    let attachedExpectation = expectation(description: "All 4 child observers should be attached")
    attachedExpectation.expectedFulfillmentCount = 4
    let removedExpectation = expectation(description: "All 4 child observers should be removed")
    removedExpectation.expectedFulfillmentCount = 4
    mockQuery.observerAttachedExpectation = attachedExpectation
    mockQuery.observerRemovedExpectation = removedExpectation

    let query = mockQuery!
    let task = Task {
      for try await _ in query.childEvents {
        XCTFail("Child events stream should not emit values")
      }
    }

    await fulfillment(of: [attachedExpectation], timeout: 1.0)
    task.cancel()

    await fulfillment(of: [removedExpectation], timeout: 1.0)
    XCTAssertEqual(query.removedHandles, [1, 2, 3, 4])
  }

  func testSnapshotsRemovesObserverAndDeallocatesQueryOnBreak() async throws {
    let attachedExpectation = expectation(description: "Value observer should be attached")
    let removedExpectation = expectation(description: "Value observer should be removed on break")

    weak var weakQuery: MockDatabaseQuery?
    do {
      let localQuery = MockDatabaseQuery()
      weakQuery = localQuery
      localQuery.observerAttachedExpectation = attachedExpectation
      localQuery.observerRemovedExpectation = removedExpectation

      let task = Task {
        for try await snapshot in localQuery.snapshots {
          XCTAssertEqual(snapshot.key, "user1")
          break
        }
      }

      await fulfillment(of: [attachedExpectation], timeout: 1.0)
      localQuery.sendValue(MockDataSnapshot(key: "user1", value: "Alice"))

      try await task.value
      await fulfillment(of: [removedExpectation], timeout: 1.0)
      XCTAssertEqual(localQuery.removedHandles, [1])
      XCTAssertTrue(localQuery.valueObservers.isEmpty)
    }

    XCTAssertNil(weakQuery, "MockDatabaseQuery should be deallocated without retain cycles")
  }

  func testChildEventsRemovesObserversAndDeallocatesQueryOnBreak() async throws {
    let attachedExpectation = expectation(description: "All 4 child observers should be attached")
    attachedExpectation.expectedFulfillmentCount = 4
    let removedExpectation = expectation(
      description: "All 4 child observers should be removed on break"
    )
    removedExpectation.expectedFulfillmentCount = 4

    weak var weakQuery: MockDatabaseQuery?
    do {
      let localQuery = MockDatabaseQuery()
      weakQuery = localQuery
      localQuery.observerAttachedExpectation = attachedExpectation
      localQuery.observerRemovedExpectation = removedExpectation

      let task = Task {
        for try await event in localQuery.childEvents {
          if case let .added(snapshot, _) = event {
            XCTAssertEqual(snapshot.key, "item1")
          } else {
            XCTFail("Expected .added event")
          }
          break
        }
      }

      await fulfillment(of: [attachedExpectation], timeout: 1.0)
      localQuery.sendSiblingEvent(
        .childAdded,
        snapshot: MockDataSnapshot(key: "item1", value: "A"),
        previousSiblingKey: nil
      )

      try await task.value
      await fulfillment(of: [removedExpectation], timeout: 1.0)
      XCTAssertEqual(localQuery.removedHandles, [1, 2, 3, 4])
      XCTAssertTrue(localQuery.valueObservers.isEmpty)
      XCTAssertTrue(localQuery.siblingObservers.isEmpty)
    }

    XCTAssertNil(weakQuery, "MockDatabaseQuery should be deallocated without retain cycles")
  }
}
