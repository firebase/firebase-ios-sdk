/*
 * Copyright 2023 Google LLC
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

import Foundation
import XCTest

import FirebaseCore
import FirebaseFirestore

#if swift(>=5.5.2)
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  class DatabaseTests: FSTIntegrationTestCase {
    func testCanStillUseDisablePersistenceSettings() async throws {
      let settings = db.settings
      settings.isPersistenceEnabled = false
      db.settings = settings

      try await db.document("coll/doc").setData(["foo": "bar"])
      let result = try? await db.document("coll/doc").getDocument(source: .cache)
      XCTAssertEqual(["foo": "bar"], result?.data() as! [String: String])
    }

    func testCanStillUseEnablePersistenceSettings() async throws {
      let settings = db.settings
      settings.isPersistenceEnabled = true
      db.settings = settings

      try await db.document("coll/doc").setData(["foo": "bar"])
      let result = try? await db.document("coll/doc").getDocument(source: .cache)
      XCTAssertEqual(["foo": "bar"], result?.data() as! [String: String])
    }

    func testCanUseMemoryCacheSettings() async throws {
      let settings = db.settings
      settings.cacheSettings = MemoryCacheSettings()
      db.settings = settings

      try await db.document("coll/doc").setData(["foo": "bar"])
      let result = try? await db.document("coll/doc").getDocument(source: .cache)
      XCTAssertEqual(["foo": "bar"], result?.data() as! [String: String])
    }

    func testCanGetDocumentWithMemoryLruGCEnabled() async throws {
      let settings = db.settings
      settings
        .cacheSettings =
        MemoryCacheSettings(
          garbageCollectorSettings: MemoryLRUGCSettings(sizeBytes: 2_000_000)
        )
      db.settings = settings

      try await db.document("coll/doc").setData(["foo": "bar"])
      let result = try? await db.document("coll/doc").getDocument(source: .cache)
      XCTAssertEqual(["foo": "bar"], result?.data() as! [String: String])
    }

    func testCannotGetDocumentWithMemoryEagerGCEnabled() async throws {
      let settings = db.settings
      settings
        .cacheSettings =
        MemoryCacheSettings(garbageCollectorSettings: MemoryEagerGCSetting())
      db.settings = settings

      try await db.document("coll/doc").setData(["foo": "bar"])
      let result = try? await db.document("coll/doc").getDocument(source: .cache)
      XCTAssertNil(result)
    }

    func testCanUsePersistentCacheSettings() async throws {
      let settings = db.settings
      settings.cacheSettings = PersistentCacheSettings()
      db.settings = settings

      try await db.document("coll/doc").setData(["foo": "bar"])
      let result = try? await db.document("coll/doc").getDocument(source: .cache)
      XCTAssertEqual(["foo": "bar"], result?.data() as! [String: String])
    }

    func testCanSetCacheSettingsMultipleTimes() async throws {
      let settings = db.settings
      settings.cacheSettings = PersistentCacheSettings()
      settings.cacheSettings = MemoryCacheSettings()
      db.settings = settings

      try await db.document("coll/doc").setData(["foo": "bar"])
      let result = try? await db.document("coll/doc").getDocument(source: .cache)
      XCTAssertEqual(["foo": "bar"], result?.data() as! [String: String])
    }

    func testGetValidPersistentCacheIndexManager() async throws {
      // [FIRApp resetApps] is an internal api, while Swift test can only test again public api.
      // So `FirebaseApp.configure()` can only be called once for the whole test class.
      FirebaseApp.configure()

      let db1 = Firestore.firestore(database: "SwiftPersistentCacheIndexManagerDB1")
      let settings1 = db1.settings
      settings1.cacheSettings = PersistentCacheSettings()
      db1.settings = settings1

      XCTAssertNotNil(db1.persistentCacheIndexManager)

      // Use persistent disk cache (default)
      let db2 = Firestore.firestore(database: "SwiftPersistentCacheIndexManagerDB2")
      XCTAssertNotNil(db2.persistentCacheIndexManager)

      // Disable persistent disk cache
      let db3 = Firestore.firestore(database: "SwiftMemoryCacheIndexManagerDB1")
      let settings3 = db3.settings
      settings3.cacheSettings = MemoryCacheSettings()
      db3.settings = settings3
      XCTAssertNil(db3.persistentCacheIndexManager)

      // Disable persistent disk cache (deprecated)
      let db4 = Firestore.firestore(database: "SwiftPersistentCacheIndexManagerDB4")
      let settings4 = db4.settings
      settings4.isPersistenceEnabled = false
      db4.settings = settings4
      XCTAssertNil(db4.persistentCacheIndexManager)

      let db5 = Firestore.firestore(database: "SwiftPersistentCacheIndexManagerDB5")
      let settings5 = db5.settings
      settings5.cacheSettings = PersistentCacheSettings()
      db5.settings = settings5
      XCTAssertEqual(db5.persistentCacheIndexManager, db5.persistentCacheIndexManager)

      // Use persistent disk cache (default)
      let db6 = Firestore.firestore(database: "SwiftPersistentCacheIndexManagerDB6")
      XCTAssertEqual(db6.persistentCacheIndexManager, db6.persistentCacheIndexManager)

      let db7 = Firestore.firestore(database: "SwiftMemoryCacheIndexManagerDB2")
      let settings7 = db7.settings
      settings7.cacheSettings = PersistentCacheSettings()
      db7.settings = settings7
      XCTAssertNotEqual(db5.persistentCacheIndexManager, db7.persistentCacheIndexManager)
      XCTAssertNotEqual(db6.persistentCacheIndexManager, db7.persistentCacheIndexManager)

      // Use persistent disk cache (default)
      let db8 = Firestore.firestore(database: "SwiftPersistentCacheIndexManagerDB8")
      XCTAssertNotEqual(db5.persistentCacheIndexManager, db8.persistentCacheIndexManager)
      XCTAssertNotEqual(db6.persistentCacheIndexManager, db8.persistentCacheIndexManager)
      XCTAssertNotEqual(db7.persistentCacheIndexManager, db8.persistentCacheIndexManager)
    }

    /// Regression test for https://github.com/firebase/firebase-ios-sdk/issues/16149
    ///
    /// Invariant: after an offline-queued setData(merge: true) against a
    /// concurrently server-deleted document, once the merge is acked by the
    /// backend the local cache MUST reflect what the backend actually holds.
    /// This must hold regardless of the order in which sibling target CURRENTs
    /// and the merge's document_change arrive on the watch stream.
    ///
    /// Backend-agnostic: ground truth comes from an independent Firestore
    /// client, not from REST or emulator-specific introspection.
    func testCacheMatchesBackendAfterOfflineMergeOverServerDelete() async throws {
      for iteration in 0 ..< 5 {
        let readerDB = firestore()
        let writerDB = firestore()

        let path = "regression-16149/doc-\(UUID().uuidString)"
        let readerRef = readerDB.document(path)
        let writerRef = writerDB.document(path)

        // Seed.
        try await writerRef.setData(["status": "seed", "iter": iteration])

        // Establish sibling targets on reader. These are what later pollute
        // the reconnect batch's global snapshot_version.
        let siblingsPath = "regression-16149-siblings-\(UUID().uuidString)"
        let siblings = readerDB.collection(siblingsPath)
        try await withThrowingTaskGroup(of: Void.self) { group in
          for i in 0 ..< 10 {
            group.addTask {
              try await siblings.document("doc-\(i)")
                .setData(["status": "active", "n": i])
            }
          }
          try await group.waitForAll()
        }
        let siblingListener = siblings
          .whereField("status", isEqualTo: "active")
          .addSnapshotListener { _, _ in }

        // Attach the doc listener while online so the seed lands in cache.
        let saw = expectation(description: "reader saw seed")
        var sawFulfilled = false
        let docListener = readerRef.addSnapshotListener { snap, _ in
          if let snap, snap.exists, !sawFulfilled {
            sawFulfilled = true
            saw.fulfill()
          }
        }
        await fulfillment(of: [saw], timeout: 10)

        // Offline ; concurrent server-side delete ; offline-queued merge.
        try await readerDB.disableNetwork()
        try await writerRef.delete()

        let acked = expectation(description: "merge acked")
        readerRef.setData(["merged": true, "iter": iteration], merge: true) {
          XCTAssertNil($0)
          acked.fulfill()
        }

        // Reconnect — the bug, if present, is born here.
        try await readerDB.enableNetwork()
        await fulfillment(of: [acked], timeout: 15)
        try await readerDB.waitForPendingWrites()
        try await Task.sleep(nanoseconds: 500_000_000)

        // Independent ground truth.
        let truth = try await writerRef.getDocument(source: .server)
        let cached = try await readerRef.getDocument(source: .cache)

        XCTAssertEqual(
          cached.exists, truth.exists,
          "iter \(iteration): cache.exists=\(cached.exists) backend.exists=\(truth.exists) — #16149"
        )
        if truth.exists {
          XCTAssertEqual(
            (cached.data() ?? [:]) as NSDictionary,
            (truth.data() ?? [:]) as NSDictionary,
            "iter \(iteration): cache and backend disagree on contents"
          )
        }

        docListener.remove()
        siblingListener.remove()
        try? await writerRef.delete()
        for i in 0 ..< 10 {
          try? await siblings.document("doc-\(i)").delete()
        }
        try await readerDB.terminate()
        try await writerDB.terminate()
      }
    }

    func testCacheConvergesToDeletedWhenServerDeletesWhileOfflineWithNoLocalWrite()
      async throws {
      let readerDB = firestore()
      let writerDB = firestore()
      let path = "regression-16149-companion/doc-\(UUID().uuidString)"
      let readerRef = readerDB.document(path)
      let writerRef = writerDB.document(path)

      try await writerRef.setData(["status": "alive"])

      let saw = expectation(description: "reader saw seed")
      var sawFulfilled = false
      let listener = readerRef.addSnapshotListener { snap, _ in
        if let snap, snap.exists, !sawFulfilled {
          sawFulfilled = true
          saw.fulfill()
        }
      }
      await fulfillment(of: [saw], timeout: 10)

      try await readerDB.disableNetwork()
      try await writerRef.delete()
      try await readerDB.enableNetwork()
      try await Task.sleep(nanoseconds: 1_500_000_000)

      let cached = try await readerRef.getDocument(source: .cache)
      XCTAssertFalse(
        cached.exists,
        "Cache must converge to 'deleted' after server-side delete during offline."
      )

      listener.remove()
      try await readerDB.terminate()
      try await writerDB.terminate()
    }
  }
#endif
