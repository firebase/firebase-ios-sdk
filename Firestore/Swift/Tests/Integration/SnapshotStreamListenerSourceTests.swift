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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class SnapshotStreamListenerSourceTests: FSTIntegrationTestCase {
  func assertQuerySnapshotDataEquals(_ snapshot: Any,
                                     _ expectedData: [[String: Any]]) throws {
    let extractedData = FIRQuerySnapshotGetData(snapshot as! QuerySnapshot)
    guard extractedData.count == expectedData.count else {
      XCTFail(
        "Result count mismatch: Expected \(expectedData.count), got \(extractedData.count)"
      )
      return
    }
    for index in 0 ..< extractedData.count {
      XCTAssertTrue(areDictionariesEqual(extractedData[index], expectedData[index]))
    }
  }

  // TODO(swift testing): update the function to be able to check other value types as well.
  func areDictionariesEqual(_ dict1: [String: Any], _ dict2: [String: Any]) -> Bool {
    guard dict1.count == dict2.count
    else { return false } // Check if the number of elements matches

    for (key, value1) in dict1 {
      guard let value2 = dict2[key] else { return false }

      // Value Checks (Assuming consistent types after the type check)
      if let str1 = value1 as? String, let str2 = value2 as? String {
        if str1 != str2 { return false }
      } else if let int1 = value1 as? Int, let int2 = value2 as? Int {
        if int1 != int2 { return false }
      } else {
        // Handle other potential types or return false for mismatch
        return false
      }
    }
    return true
  }

  func testSnapshotStreamReturnsNilAfterCancellation() async throws {
    // 1. Set up the collection.
    let collRef = collectionRef(withDocuments: ["a": ["k": "a"]])
    readDocumentSet(forRef: collRef) // populate the cache.

    // 2. Create the signal stream to coordinate cancellation timing.
    let (signalStream, signalContinuation) = AsyncStream.makeStream(of: Void.self)

    // 3. Wrap the asynchronous work in a Task.
    let task = Task {
      // Use a standard stream that stays open for new events.
      var iterator = collRef.snapshotStream().makeAsyncIterator()

      // Await the first snapshot to confirm the listener is active.
      let firstDefault = try await iterator.next()

      XCTAssertNotNil(firstDefault, "Expected an initial snapshot.")
      try assertQuerySnapshotDataEquals(firstDefault!, [["k": "a"]])
      XCTAssertEqual(firstDefault!.metadata.isFromCache, true)

      // 4. Send the signal that the first snapshot has been received.
      signalContinuation.yield(())
      signalContinuation.finish()

      // This await will be suspended until the task is cancelled.
      let secondDefault = try await iterator.next()

      // 5. Assert that the iterator returned nil as requested, because the
      //    task was cancelled while it was awaiting this event.
      XCTAssertNil(secondDefault, "iterator.next() should have returned nil after cancellation.")
    }

    // 6. Wait for the signal, ensuring we don't cancel prematurely.
    await signalStream.first { _ in true }

    // 7. Now that we know the first snapshot has been processed, cancel the task.
    task.cancel()
  }

  func testCanListenToDefaultSourceFirstAndThenCacheAsyncStream() async throws {
    let collRef = collectionRef(withDocuments: [
      "a": ["k": "a", "sort": 0],
      "b": ["k": "b", "sort": 1],
    ])

    let query = collRef.whereField("sort", isGreaterThanOrEqualTo: 1).order(by: "sort")

    // 1. Create a signal stream. The test will wait on this stream.
    //    The Task will write to it after receiving the first snapshot.
    let (signalStreamDefault, signalContinuationDefault) = AsyncStream.makeStream(of: Void.self)

    let streamDefault = query.snapshotStream()
    var iteratorDefault = streamDefault.makeAsyncIterator()

    let task = Task {
      // This task will now run and eventually signal its progress.
      let firstSnapshotDefault = try await iteratorDefault.next()

      // Assertions for the first snapshot
      XCTAssertNotNil(firstSnapshotDefault, "Expected an initial snapshot.")
      try assertQuerySnapshotDataEquals(firstSnapshotDefault!, [["k": "b", "sort": 1]])
      XCTAssertEqual(firstSnapshotDefault!.metadata.isFromCache, false)

      let streamCache = query.snapshotStream(
        options: SnapshotListenOptions().withSource(ListenSource.cache)
      )
      var iteratorCache = streamCache.makeAsyncIterator()
      // This task will now run and eventually signal its progress.
      let firstSnapshotCache = try await iteratorCache.next()
      // Assertions for the first snapshot
      XCTAssertNotNil(firstSnapshotCache, "Expected an initial snapshot.")
      try assertQuerySnapshotDataEquals(firstSnapshotCache!, [["k": "b", "sort": 1]])
      XCTAssertEqual(firstSnapshotCache!.metadata.isFromCache, false)

      // 2. Send the signal to the test function now that we have the first snapshot.
      signalContinuationDefault.yield(())
      signalContinuationDefault.finish() // We only need to signal once.

      // This next await will be suspended until it's cancelled.
      let secondDefault = try await iteratorDefault.next()

      // This next await will be suspended until it's cancelled.
      let secondCache = try await iteratorCache.next()

      // After cancellation, the iterator should terminate and return nil.
      XCTAssertNil(secondDefault, "iterator.next() should have returned nil after cancellation.")
      // After cancellation, the iterator should terminate and return nil.
      XCTAssertNil(secondCache, "iterator.next() should have returned nil after cancellation.")
    }

    // 3. Instead of sleeping, await the signal from the Task.
    //    This line will pause execution until `signalContinuation.yield()` is called.
    await signalStreamDefault.first { _ in true }

    // 4. As soon as we receive the signal, we know it's safe to cancel.
    task.cancel()
  }

  func testCanListenToDefaultSourceFirstAndThenCacheAsync2() async throws {
    let collRef = collectionRef(withDocuments: [
      "a": ["k": "a", "sort": 0],
      "b": ["k": "b", "sort": 1],
    ])
    let query = collRef.whereField("sort", isGreaterThanOrEqualTo: 1).order(by: "sort")

    // 1. Create iterators for both the default (server) and cache sources.
    var serverIterator = query.snapshotStream().makeAsyncIterator()

    // 2. Await the server snapshot first. This populates the cache.
    let serverSnapshot = try await serverIterator.next()
    XCTAssertNotNil(serverSnapshot)
    try assertQuerySnapshotDataEquals(serverSnapshot!, [["k": "b", "sort": 1]])
    XCTAssertFalse(
      serverSnapshot!.metadata.isFromCache,
      "The first snapshot should come from the server."
    )

    // 3. Now, await the snapshot from the cache iterator. It will immediately
    //    return the data that the server listener just populated.
    var cacheIterator = query
      .snapshotStream(options: SnapshotListenOptions().withSource(ListenSource.cache))
      .makeAsyncIterator()
    let cacheSnapshot = try await cacheIterator.next()

    XCTAssertNotNil(cacheSnapshot)
    try assertQuerySnapshotDataEquals(cacheSnapshot!, [["k": "b", "sort": 1]])

    // Because the server listener is active, the cache data is fresh,
    // so isFromCache will be false.
    XCTAssertFalse(
      cacheSnapshot!.metadata.isFromCache,
      "Cache snapshot metadata should be synced by the active server listener."
    )

    // Cleanup is handled automatically when the iterators go out of scope.
  }

  func testCanRaiseSnapshotFromCacheForQueryAsync() async throws {
    // 1. Set up the collection and populate the cache, same as the original.
    let collRef = collectionRef(withDocuments: ["a": ["k": "a"]])
    readDocumentSet(forRef: collRef) // populate the cache.

    // Create an async stream iterator that only listens to the cache.
    var iterator = collRef
      .snapshotStream(options: SnapshotListenOptions().withSource(ListenSource.cache))
      .makeAsyncIterator()

    // Await the snapshot from the iterator.
    guard let querySnap = try await iterator.next() else {
      XCTFail("Expected a snapshot from the cache but received nil.")
      return
    }

    // 4. Perform the same assertions as the original test.
    try assertQuerySnapshotDataEquals(querySnap, [["k": "a"]])
    XCTAssertTrue(querySnap.metadata.isFromCache, "Snapshot should have come from the cache.")
  }
}
