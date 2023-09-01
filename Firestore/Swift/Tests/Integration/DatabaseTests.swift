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
      XCTAssertNil(result)
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
      XCTAssertNil(result)
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
      XCTAssertNil(result)
    }

    func testGetValidPersistentCacheIndexManager() async throws {
      FirebaseApp.configure()

      let db1 = Firestore.firestore(database: "PersistentCacheIndexManagerDB1")
      let settings1 = db1.settings
      settings1.cacheSettings = PersistentCacheSettings()
      db1.settings = settings1

      XCTAssertNotNil(db1.persistentCacheIndexManager)

      // Use persistent disk cache (default)
      let db2 = Firestore.firestore(database: "PersistentCacheIndexManagerDB2")
      XCTAssertNotNil(db2.persistentCacheIndexManager)

      // Disable persistent disk cache
      let db3 = Firestore.firestore(database: "MemoryCacheIndexManagerDB1")
      let settings3 = db3.settings
      settings3.cacheSettings = MemoryCacheSettings()
      db3.settings = settings3
      XCTAssertNil(db3.persistentCacheIndexManager)

      // Disable persistent disk cache (deprecated)
      let db4 = Firestore.firestore(database: "PersistentCacheIndexManagerDB4")
      let settings4 = db4.settings
      settings4.isPersistenceEnabled = false
      db4.settings = settings4
      XCTAssertNil(db4.persistentCacheIndexManager)
    }

    func testCanGetSameOrDifferentPersistentCacheIndexManager() async throws {
      FirebaseApp.configure()

      let db1 = Firestore.firestore(database: "PersistentCacheIndexManagerDB5")
      let settings1 = db1.settings
      settings1.cacheSettings = PersistentCacheSettings()
      db1.settings = settings1
      XCTAssertEqual(db1.persistentCacheIndexManager, db1.persistentCacheIndexManager)

      // Use persistent disk cache (default)
      let db2 = Firestore.firestore(database: "PersistentCacheIndexManagerDB6")
      XCTAssertEqual(db2.persistentCacheIndexManager, db2.persistentCacheIndexManager)

      let db3 = Firestore.firestore(database: "MemoryCacheIndexManagerDB7")
      let settings3 = db3.settings
      settings3.cacheSettings = PersistentCacheSettings()
      db3.settings = settings3
      XCTAssertNotEqual(db1.persistentCacheIndexManager, db3.persistentCacheIndexManager)
      XCTAssertNotEqual(db2.persistentCacheIndexManager, db3.persistentCacheIndexManager)

      // Use persistent disk cache (default)
      let db4 = Firestore.firestore(database: "PersistentCacheIndexManagerDB8")
      XCTAssertNotEqual(db1.persistentCacheIndexManager, db4.persistentCacheIndexManager)
      XCTAssertNotEqual(db2.persistentCacheIndexManager, db4.persistentCacheIndexManager)
      XCTAssertNotEqual(db3.persistentCacheIndexManager, db4.persistentCacheIndexManager)
    }
  }
#endif
