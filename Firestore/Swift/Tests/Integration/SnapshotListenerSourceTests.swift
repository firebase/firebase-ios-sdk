/*
 * Copyright 2024 Google LLC
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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class SnapshotListenerSourceTests: FSTIntegrationTestCase {
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

  func testCanRaiseSnapshotFromCacheForQuery() throws {
    let collRef = collectionRef(withDocuments: ["a": ["k": "a"]])
    readDocumentSet(forRef: collRef) // populate the cache.

    let options = SnapshotListenOptions().withSource(ListenSource.cache)
    let registration = collRef.addSnapshotListener(
      options: options,
      listener: eventAccumulator.valueEventHandler
    )

    let querySnap = eventAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, [["k": "a"]])
    XCTAssertEqual(querySnap.metadata.isFromCache, true)

    eventAccumulator.assertNoAdditionalEvents()
    registration.remove()
  }

  func testCanRaiseSnapshotFromCacheForDocumentReference() throws {
    let docRef = documentRef()
    docRef.setData(["k": "a"])
    readDocument(forRef: docRef) // populate the cache.

    let options = SnapshotListenOptions().withSource(ListenSource.cache)
    let registration = docRef.addSnapshotListener(
      options: options,
      listener: eventAccumulator.valueEventHandler
    )

    let docSnap = eventAccumulator.awaitEvent(withName: "snapshot") as! DocumentSnapshot
    XCTAssertEqual(docSnap.data() as! [String: String], ["k": "a"])
    XCTAssertEqual(docSnap.metadata.isFromCache, true)

    eventAccumulator.assertNoAdditionalEvents()
    registration.remove()
  }

  func testListenToCacheShouldNotBeAffectedByOnlineStatusChange() throws {
    let collRef = collectionRef(withDocuments: ["a": ["k": "a"]])
    readDocumentSet(forRef: collRef) // populate the cache.

    let options = SnapshotListenOptions().withSource(ListenSource.cache)
      .withIncludeMetadataChanges(true)
    let registration = collRef.addSnapshotListener(
      options: options,
      listener: eventAccumulator.valueEventHandler
    )

    let querySnap = eventAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, [["k": "a"]])
    XCTAssertEqual(querySnap.metadata.isFromCache, true)

    disableNetwork()
    enableNetwork()

    eventAccumulator.assertNoAdditionalEvents()
    registration.remove()
  }

  func testMultipleListenersSourcedFromCacheCanWorkIndependently() throws {
    let collRef = collectionRef(withDocuments: [
      "a": ["k": "a", "sort": 0],
      "b": ["k": "b", "sort": 1],
    ])
    readDocumentSet(forRef: collRef) // populate the cache.

    let query = collRef.whereField("sort", isGreaterThan: 0).order(by: "sort")

    let options = SnapshotListenOptions().withSource(ListenSource.cache)
    let registration1 = query.addSnapshotListener(
      options: options,
      listener: eventAccumulator.valueEventHandler
    )
    let registration2 = query.addSnapshotListener(
      options: options,
      listener: eventAccumulator.valueEventHandler
    )

    var expected = [["k": "b", "sort": 1]]
    var querySnap = eventAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, expected)
    XCTAssertEqual(querySnap.metadata.isFromCache, true)
    querySnap = eventAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, expected)
    XCTAssertEqual(querySnap.metadata.isFromCache, true)

    // Do a local mutation
    addDocumentRef(collRef, data: ["k": "c", "sort": 2])

    expected = [["k": "b", "sort": 1], ["k": "c", "sort": 2]]
    querySnap = eventAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, expected)
    XCTAssertEqual(querySnap.metadata.isFromCache, true)
    querySnap = eventAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, expected)
    XCTAssertEqual(querySnap.metadata.isFromCache, true)

    // Detach one listener, and do a local mutation. The other listener
    // should not be affected.
    registration1.remove()
    addDocumentRef(collRef, data: ["k": "d", "sort": 3])

    expected = [["k": "b", "sort": 1], ["k": "c", "sort": 2], ["k": "d", "sort": 3]]
    querySnap = eventAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, expected)
    XCTAssertEqual(querySnap.metadata.isFromCache, true)

    eventAccumulator.assertNoAdditionalEvents()
    registration2.remove()
  }

  // Two queries that mapped to the same target ID are referred to as
  // "mirror queries". An example for a mirror query is a limitToLast()
  // query and a limit() query that share the same backend Target ID.
  // Since limitToLast() queries are sent to the backend with a modified
  // orderBy() clause, they can map to the same target representation as
  // limit() query, even if both queries appear separate to the user.
  func testListenUnlistenRelistenToMirrorQueriesFromCache() throws {
    let collRef = collectionRef(withDocuments: [
      "a": ["k": "a", "sort": 0],
      "b": ["k": "b", "sort": 1],
      "c": ["k": "c", "sort": 1],
    ])
    readDocumentSet(forRef: collRef) // populate the cache.
    let options = SnapshotListenOptions().withSource(ListenSource.cache)

    // Setup a `limit` query.
    let limit = collRef.order(by: "sort", descending: false).limit(to: 2)
    let limitAccumulator = FSTEventAccumulator<QuerySnapshot>(forTest: self)
    var limitRegistration = limit.addSnapshotListener(
      options: options,
      listener: limitAccumulator.valueEventHandler
    )
    // Setup a mirroring `limitToLast` query.
    let limitToLast = collRef.order(by: "sort", descending: true).limit(toLast: 2)
    let limitToLastAccumulator = FSTEventAccumulator<QuerySnapshot>(forTest: self)
    var limitToLastRegistration = limitToLast.addSnapshotListener(
      options: options,
      listener: limitToLastAccumulator.valueEventHandler
    )

    // Verify both queries get expected result.
    var querySnap = limitAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, [["k": "a", "sort": 0], ["k": "b", "sort": 1]])
    XCTAssertEqual(querySnap.metadata.isFromCache, true)

    querySnap = limitToLastAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, [["k": "b", "sort": 1], ["k": "a", "sort": 0]])
    XCTAssertEqual(querySnap.metadata.isFromCache, true)

    // Un-listen then re-listen to the limit query.
    limitRegistration.remove()
    limitRegistration = limit.addSnapshotListener(
      options: options,
      listener: limitAccumulator.valueEventHandler
    )
    querySnap = limitAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(
      querySnap,
      [["k": "a", "sort": 0], ["k": "b", "sort": 1]]
    )
    XCTAssertEqual(querySnap.metadata.isFromCache, true)

    // Add a document that would change the result set.
    addDocumentRef(collRef, data: ["k": "d", "sort": -1])

    // Verify both queries get expected result.
    querySnap = limitAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, [["k": "d", "sort": -1], ["k": "a", "sort": 0]])
    XCTAssertEqual(querySnap.metadata.isFromCache, true)
    XCTAssertEqual(querySnap.metadata.hasPendingWrites, true)
    querySnap = limitToLastAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, [["k": "a", "sort": 0], ["k": "d", "sort": -1]])
    XCTAssertEqual(querySnap.metadata.isFromCache, true)
    XCTAssertEqual(querySnap.metadata.hasPendingWrites, true)

    // Un-listen to limitToLast, update a doc, then re-listen to limitToLast
    limitToLastRegistration.remove()
    updateDocumentRef(collRef.document("a"), data: ["k": "a", "sort": -2])
    limitToLastRegistration = limitToLast.addSnapshotListener(
      options: options,
      listener: limitToLastAccumulator.valueEventHandler
    )

    // Verify both queries get expected result.
    querySnap = limitAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, [["k": "a", "sort": -2], ["k": "d", "sort": -1]])
    XCTAssertEqual(querySnap.metadata.isFromCache, true)
    XCTAssertEqual(querySnap.metadata.hasPendingWrites, true)
    querySnap = limitToLastAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, [["k": "d", "sort": -1], ["k": "a", "sort": -2]])
    XCTAssertEqual(querySnap.metadata.isFromCache, true)
    // We listened to LimitToLast query after the doc update.
    XCTAssertEqual(querySnap.metadata.hasPendingWrites, false)
  }

  func testCanListenToDefaultSourceFirstAndThenCache() throws {
    let collRef = collectionRef(withDocuments: [
      "a": ["k": "a", "sort": 0],
      "b": ["k": "b", "sort": 1],
    ])
    let query = collRef.whereField("sort", isGreaterThanOrEqualTo: 1).order(by: "sort")

    // Listen to the query with default options, which will also populates the cache
    let defaultAccumulator = FSTEventAccumulator<QuerySnapshot>(forTest: self)
    let defaultRegistration = query.addSnapshotListener(defaultAccumulator.valueEventHandler)

    var querySnap = defaultAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, [["k": "b", "sort": 1]])
    XCTAssertEqual(querySnap.metadata.isFromCache, false)

    // Listen to the same query from cache
    let cacheAccumulator = FSTEventAccumulator<QuerySnapshot>(forTest: self)
    let options = SnapshotListenOptions().withSource(ListenSource.cache)
    let cacheRegistration = query.addSnapshotListener(
      options: options,
      listener: cacheAccumulator.valueEventHandler
    )
    querySnap = cacheAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, [["k": "b", "sort": 1]])
    // The metadata is sync with server due to the default listener
    XCTAssertEqual(querySnap.metadata.isFromCache, false)

    defaultAccumulator.assertNoAdditionalEvents()
    cacheAccumulator.assertNoAdditionalEvents()
    defaultRegistration.remove()
    cacheRegistration.remove()
  }

  func testCanListenToCacheSourceFirstAndThenDefault() throws {
    let collRef = collectionRef(withDocuments: [
      "a": ["k": "a", "sort": 0],
      "b": ["k": "b", "sort": 1],
    ])
    let query = collRef.whereField("sort", isNotEqualTo: 0).order(by: "sort")

    // Listen to the cache
    let cacheAccumulator = FSTEventAccumulator<QuerySnapshot>(forTest: self)
    let options = SnapshotListenOptions().withSource(ListenSource.cache)
    let cacheRegistration = query.addSnapshotListener(
      options: options,
      listener: cacheAccumulator.valueEventHandler
    )
    var querySnap = cacheAccumulator.awaitEvent(withName: "snapshot")
    // Cache is empty
    try assertQuerySnapshotDataEquals(querySnap, [])
    XCTAssertEqual(querySnap.metadata.isFromCache, true)

    // Listen to the same query from server
    let defaultAccumulator = FSTEventAccumulator<QuerySnapshot>(forTest: self)
    let defaultRegistration = query.addSnapshotListener(defaultAccumulator.valueEventHandler)
    querySnap = defaultAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, [["k": "b", "sort": 1]])
    XCTAssertEqual(querySnap.metadata.isFromCache, false)

    // Default listener updates the cache, whish triggers cache listener to raise snapshot.
    querySnap = cacheAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, [["k": "b", "sort": 1]])
    // The metadata is sync with server due to the default listener
    XCTAssertEqual(querySnap.metadata.isFromCache, false)

    defaultAccumulator.assertNoAdditionalEvents()
    cacheAccumulator.assertNoAdditionalEvents()
    defaultRegistration.remove()
    cacheRegistration.remove()
  }

  func testWillNotGetMetadataOnlyUpdatesIfListeningToCacheOnly() throws {
    let collRef = collectionRef(withDocuments: [
      "a": ["k": "a", "sort": 0],
      "b": ["k": "b", "sort": 1],
    ])
    readDocumentSet(forRef: collRef) // populate the cache.

    let query = collRef.whereField("sort", isNotEqualTo: 0).order(by: "sort")
    let options = SnapshotListenOptions().withSource(ListenSource.cache)

    let registration = query.addSnapshotListener(
      options: options,
      listener: eventAccumulator.valueEventHandler
    )

    var querySnap = eventAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, [["k": "b", "sort": 1]])
    XCTAssertEqual(querySnap.metadata.isFromCache, true)

    // Do a local mutation
    addDocumentRef(collRef, data: ["k": "c", "sort": 2])

    querySnap = eventAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, [["k": "b", "sort": 1], ["k": "c", "sort": 2]])
    XCTAssertEqual(querySnap.metadata.isFromCache, true)
    XCTAssertEqual(querySnap.metadata?.hasPendingWrites, true)

    // As we are not listening to server, the listener will not get notified
    // when local mutation is acknowledged by server.
    eventAccumulator.assertNoAdditionalEvents()
    registration.remove()
  }

  func testWillHaveSynceMetadataUpdatesWhenListeningToBothCacheAndDefaultSource() throws {
    let collRef = collectionRef(withDocuments: [
      "a": ["k": "a", "sort": 0],
      "b": ["k": "b", "sort": 1],
    ])
    readDocumentSet(forRef: collRef) // populate the cache.
    let query = collRef.whereField("sort", isNotEqualTo: 0).order(by: "sort")

    // Listen to the cache
    let cacheAccumulator = FSTEventAccumulator<QuerySnapshot>(forTest: self)
    let options = SnapshotListenOptions().withSource(ListenSource.cache)
      .withIncludeMetadataChanges(true)
    let cacheRegistration = query.addSnapshotListener(
      options: options,
      listener: cacheAccumulator.valueEventHandler
    )
    var querySnap = cacheAccumulator.awaitEvent(withName: "snapshot")
    var expected = [["k": "b", "sort": 1]]
    try assertQuerySnapshotDataEquals(querySnap, expected)
    XCTAssertEqual(querySnap.metadata.isFromCache, true)

    // Listen to the same query from server
    let defaultAccumulator = FSTEventAccumulator<QuerySnapshot>(forTest: self)
    let defaultRegistration = query.addSnapshotListener(
      includeMetadataChanges: true,
      listener: defaultAccumulator.valueEventHandler
    )

    querySnap = defaultAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, expected)
    // First snapshot will be raised from cache.
    XCTAssertEqual(querySnap.metadata.isFromCache, true)
    querySnap = defaultAccumulator.awaitEvent(withName: "snapshot")
    // Second snapshot will be raised from server result
    XCTAssertEqual(querySnap.metadata.isFromCache, false)

    // As listening to metadata changes, the cache listener also gets triggered and synced
    // with default listener.
    querySnap = cacheAccumulator.awaitEvent(withName: "snapshot")
    // The metadata is sync with server due to the default listener
    XCTAssertEqual(querySnap.metadata.isFromCache, false)

    // Do a local mutation
    addDocumentRef(collRef, data: ["k": "c", "sort": 2])

    // snapshot gets triggered by local mutation
    expected = [["k": "b", "sort": 1], ["k": "c", "sort": 2]]
    querySnap = defaultAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, expected)
    XCTAssertEqual(querySnap.metadata.hasPendingWrites, true)
    XCTAssertEqual(querySnap.metadata.isFromCache, false)
    querySnap = cacheAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, expected)
    XCTAssertEqual(querySnap.metadata.hasPendingWrites, true)
    XCTAssertEqual(querySnap.metadata.isFromCache, false)

    // Local mutation gets acknowledged by the server
    querySnap = defaultAccumulator.awaitEvent(withName: "snapshot")
    XCTAssertEqual(querySnap.metadata.hasPendingWrites, false)
    XCTAssertEqual(querySnap.metadata.isFromCache, false)
    querySnap = cacheAccumulator.awaitEvent(withName: "snapshot")
    XCTAssertEqual(querySnap.metadata.hasPendingWrites, false)
    XCTAssertEqual(querySnap.metadata.isFromCache, false)

    defaultAccumulator.assertNoAdditionalEvents()
    cacheAccumulator.assertNoAdditionalEvents()
    defaultRegistration.remove()
    cacheRegistration.remove()
  }

  func testCanUnlistenToDefaultSourceWhileStillListeningToCache() throws {
    let collRef = collectionRef(withDocuments: [
      "a": ["k": "a", "sort": 0],
      "b": ["k": "b", "sort": 1],
    ])
    let query = collRef.whereField("sort", isNotEqualTo: 0).order(by: "sort")

    // Listen to the query with both source options
    let defaultAccumulator = FSTEventAccumulator<QuerySnapshot>(forTest: self)
    let defaultRegistration = query.addSnapshotListener(defaultAccumulator.valueEventHandler)
    defaultAccumulator.awaitEvent(withName: "snapshot")
    let cacheAccumulator = FSTEventAccumulator<QuerySnapshot>(forTest: self)
    let options = SnapshotListenOptions().withSource(ListenSource.cache)
    let cacheRegistration = query.addSnapshotListener(
      options: options,
      listener: cacheAccumulator.valueEventHandler
    )
    cacheAccumulator.awaitEvent(withName: "snapshot")

    // Un-listen to the default listener.
    defaultRegistration.remove()

    // Add a document and verify listener to cache works as expected
    addDocumentRef(collRef, data: ["k": "c", "sort": -1])
    defaultAccumulator.assertNoAdditionalEvents()

    let querySnap = cacheAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(
      querySnap,
      [["k": "c", "sort": -1], ["k": "b", "sort": 1]]
    )

    cacheAccumulator.assertNoAdditionalEvents()
    cacheRegistration.remove()
  }

  func testCanUnlistenToCacheSourceWhileStillListeningToServer() throws {
    let collRef = collectionRef(withDocuments: [
      "a": ["k": "a", "sort": 0],
      "b": ["k": "b", "sort": 1],
    ])
    let query = collRef.whereField("sort", isNotEqualTo: 0).order(by: "sort")

    // Listen to the query with both source options
    let defaultAccumulator = FSTEventAccumulator<QuerySnapshot>(forTest: self)
    let defaultRegistration = query.addSnapshotListener(defaultAccumulator.valueEventHandler)
    defaultAccumulator.awaitEvent(withName: "snapshot")
    let cacheAccumulator = FSTEventAccumulator<QuerySnapshot>(forTest: self)
    let options = SnapshotListenOptions().withSource(ListenSource.cache)
    let cacheRegistration = query.addSnapshotListener(
      options: options,
      listener: cacheAccumulator.valueEventHandler
    )
    cacheAccumulator.awaitEvent(withName: "snapshot")

    // Un-listen to cache.
    cacheRegistration.remove()

    // Add a document and verify listener to server works as expected.
    addDocumentRef(collRef, data: ["k": "c", "sort": -1])
    cacheAccumulator.assertNoAdditionalEvents()

    let querySnap = defaultAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(
      querySnap,
      [["k": "c", "sort": -1], ["k": "b", "sort": 1]]
    )

    defaultAccumulator.assertNoAdditionalEvents()
    defaultRegistration.remove()
  }

  func testCanListenUnlistenRelistenToSameQueryWithDifferentSourceOptions() throws {
    let collRef = collectionRef(withDocuments: [
      "a": ["k": "a", "sort": 0],
      "b": ["k": "b", "sort": 1],
    ])
    let query = collRef.whereField("sort", isGreaterThan: 0).order(by: "sort")

    // Listen to the query with default options, which will also populates the cache
    let defaultAccumulator = FSTEventAccumulator<QuerySnapshot>(forTest: self)
    var defaultRegistration = query.addSnapshotListener(defaultAccumulator.valueEventHandler)
    var querySnap = defaultAccumulator.awaitEvent(withName: "snapshot")
    var expected = [["k": "b", "sort": 1]]
    try assertQuerySnapshotDataEquals(querySnap, expected)

    // Listen to the same query from cache
    let cacheAccumulator = FSTEventAccumulator<QuerySnapshot>(forTest: self)
    let options = SnapshotListenOptions().withSource(ListenSource.cache)
    var cacheRegistration = query.addSnapshotListener(
      options: options,
      listener: cacheAccumulator.valueEventHandler
    )
    querySnap = cacheAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, expected)

    // Un-listen to the default listener, add a doc and re-listen.
    defaultRegistration.remove()
    addDocumentRef(collRef, data: ["k": "c", "sort": 2])

    expected = [["k": "b", "sort": 1], ["k": "c", "sort": 2]]
    querySnap = cacheAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, expected)

    defaultRegistration = query.addSnapshotListener(defaultAccumulator.valueEventHandler)
    querySnap = defaultAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, expected)

    // Un-listen to cache, update a doc, then re-listen to cache.
    cacheRegistration.remove()
    updateDocumentRef(collRef.document("b"), data: ["k": "b", "sort": 3])

    expected = [["k": "c", "sort": 2], ["k": "b", "sort": 3]]
    querySnap = defaultAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(
      querySnap, expected
    )

    cacheRegistration = query.addSnapshotListener(
      options: options,
      listener: cacheAccumulator.valueEventHandler
    )
    querySnap = cacheAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(
      querySnap, expected
    )

    defaultAccumulator.assertNoAdditionalEvents()
    cacheAccumulator.assertNoAdditionalEvents()
    defaultRegistration.remove()
    cacheRegistration.remove()
  }

  func testCanListenToCompositeIndexQueriesFromCache() throws {
    let collRef = collectionRef(withDocuments: [
      "a": ["k": "a", "sort": 0],
      "b": ["k": "b", "sort": 1],
    ])
    readDocumentSet(forRef: collRef) // populate the cache.

    let query = collRef.whereField("k", isLessThanOrEqualTo: "a")
      .whereField("sort", isGreaterThanOrEqualTo: 0)

    let options = SnapshotListenOptions().withSource(ListenSource.cache)
    let registration = query.addSnapshotListener(
      options: options,
      listener: eventAccumulator.valueEventHandler
    )

    let querySnap = eventAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, [["k": "a", "sort": 0]])

    eventAccumulator.assertNoAdditionalEvents()
    registration.remove()
  }

  func testCanRaiseInitialSnapshotFromCachedEmptyResults() throws {
    let collRef = collectionRef()

    // Populate the cache with empty query result.
    var querySnap = readDocumentSet(forRef: collRef)
    try assertQuerySnapshotDataEquals(querySnap, [])

    // Add a snapshot listener whose first event should be raised from cache.
    let options = SnapshotListenOptions().withSource(ListenSource.cache)
    let registration = collRef.addSnapshotListener(
      options: options,
      listener: eventAccumulator.valueEventHandler
    )

    querySnap = eventAccumulator.awaitEvent(withName: "initial event") as! QuerySnapshot
    try assertQuerySnapshotDataEquals(querySnap, [])
    XCTAssertEqual(querySnap.metadata.isFromCache, true)

    eventAccumulator.assertNoAdditionalEvents()
    registration.remove()
  }

  func testWillNotBeTriggeredByTransactionsWhileListeningToCache() throws {
    let collRef = collectionRef()

    // Add a snapshot listener whose first event should be raised from cache.
    let options = SnapshotListenOptions().withSource(ListenSource.cache)
    let registration = collRef.addSnapshotListener(
      options: options,
      listener: eventAccumulator.valueEventHandler
    )
    let querySnap = eventAccumulator.awaitEvent(withName: "initial event")
    try assertQuerySnapshotDataEquals(querySnap, [])

    let docRef = documentRef()
    // Use a transaction to perform a write without triggering any local events.
    runTransaction(docRef.firestore, block: { transaction, errorPointer -> Any? in
      transaction.updateData(["K": "a"], forDocument: docRef)
      return nil
    })

    // There should be no events raised
    eventAccumulator.assertNoAdditionalEvents()
    registration.remove()
  }

  func testSharesServerSideUpdatesWhenListeningToBothCacheAndDefault() throws {
    let collRef = collectionRef(withDocuments: [
      "a": ["k": "a", "sort": 0],
      "b": ["k": "b", "sort": 1],
    ])
    let query = collRef.whereField("sort", isGreaterThan: 0).order(by: "sort")

    // Listen to the query with default options, which will also populates the cache
    let defaultAccumulator = FSTEventAccumulator<QuerySnapshot>(forTest: self)
    let defaultRegistration = query.addSnapshotListener(defaultAccumulator.valueEventHandler)
    var querySnap = defaultAccumulator.awaitEvent(withName: "snapshot")
    var expected = [["k": "b", "sort": 1]]
    try assertQuerySnapshotDataEquals(querySnap, expected)

    // Listen to the same query from cache
    let cacheAccumulator = FSTEventAccumulator<QuerySnapshot>(forTest: self)
    let options = SnapshotListenOptions().withSource(ListenSource.cache)
    let cacheRegistration = query.addSnapshotListener(
      options: options,
      listener: cacheAccumulator.valueEventHandler
    )
    querySnap = cacheAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, expected)

    // Use a transaction to mock server side updates
    let docRef = collRef.document()
    runTransaction(docRef.firestore, block: { transaction, errorPointer -> Any? in
      transaction.setData(["k": "c", "sort": 2], forDocument: docRef)
      return nil
    })

    // Default listener receives the server update
    querySnap = defaultAccumulator.awaitEvent(withName: "snapshot")
    expected = [["k": "b", "sort": 1], ["k": "c", "sort": 2]]
    try assertQuerySnapshotDataEquals(querySnap, expected)
    XCTAssertEqual(querySnap.metadata.isFromCache, false)

    // Cache listener raises snapshot as well
    querySnap = cacheAccumulator.awaitEvent(withName: "snapshot")
    try assertQuerySnapshotDataEquals(querySnap, expected)
    XCTAssertEqual(querySnap.metadata.isFromCache, false)

    defaultAccumulator.assertNoAdditionalEvents()
    cacheAccumulator.assertNoAdditionalEvents()
    defaultRegistration.remove()
    cacheRegistration.remove()
  }

  func testListenToDocumentsWithVectors() throws {
    let collection = collectionRef()
    let doc = collection.document()

    let registration = collection.whereField("purpose", isEqualTo: "vector tests")
      .addSnapshotListener(eventAccumulator.valueEventHandler)

    var querySnap = eventAccumulator.awaitEvent(withName: "snapshot") as! QuerySnapshot
    XCTAssertEqual(querySnap.isEmpty, true)

    doc.setData([
      "purpose": "vector tests",
      "vector0": FieldValue.vector([0.0]),
      "vector1": FieldValue.vector([1, 2, 3.99]),
    ])

    querySnap = eventAccumulator.awaitEvent(withName: "snapshot") as! QuerySnapshot
    XCTAssertEqual(querySnap.isEmpty, false)
    XCTAssertEqual(
      querySnap.documents[0].data()["vector0"] as! VectorValue,
      FieldValue.vector([0.0])
    )
    XCTAssertEqual(
      querySnap.documents[0].data()["vector1"] as! VectorValue,
      FieldValue.vector([1, 2, 3.99])
    )

    doc.setData([
      "purpose": "vector tests",
      "vector0": FieldValue.vector([0.0]),
      "vector1": FieldValue.vector([1, 2, 3.99]),
      "vector2": FieldValue.vector([0.0, 0, 0]),
    ])

    querySnap = eventAccumulator.awaitEvent(withName: "snapshot") as! QuerySnapshot
    XCTAssertEqual(querySnap.isEmpty, false)
    XCTAssertEqual(
      querySnap.documents[0].data()["vector0"] as! VectorValue,
      FieldValue.vector([0.0])
    )
    XCTAssertEqual(
      querySnap.documents[0].data()["vector1"] as! VectorValue,
      FieldValue.vector([1, 2, 3.99])
    )
    XCTAssertEqual(
      querySnap.documents[0].data()["vector2"] as! VectorValue,
      FieldValue.vector([0.0, 0, 0])
    )

    doc.updateData([
      "vector3": FieldValue.vector([-1, -200, -999.0]),
    ])

    querySnap = eventAccumulator.awaitEvent(withName: "snapshot") as! QuerySnapshot
    XCTAssertEqual(querySnap.isEmpty, false)
    XCTAssertEqual(
      querySnap.documents[0].data()["vector0"] as! VectorValue,
      FieldValue.vector([0.0])
    )
    XCTAssertEqual(
      querySnap.documents[0].data()["vector1"] as! VectorValue,
      FieldValue.vector([1, 2, 3.99])
    )
    XCTAssertEqual(
      querySnap.documents[0].data()["vector2"] as! VectorValue,
      FieldValue.vector([0.0, 0, 0])
    )
    XCTAssertEqual(
      querySnap.documents[0].data()["vector3"] as! VectorValue,
      FieldValue.vector([-1, -200, -999.0])
    )

    doc.delete()
    querySnap = eventAccumulator.awaitEvent(withName: "snapshot") as! QuerySnapshot
    XCTAssertEqual(querySnap.isEmpty, true)

    eventAccumulator.assertNoAdditionalEvents()
    registration.remove()
  }
}
