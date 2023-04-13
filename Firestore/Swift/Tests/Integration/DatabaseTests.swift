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
        MemoryCacheSettings(garbageCollectorSettings: MemoryLRUGCSettings(sizeBytes: 2_000_000))
      db.settings = settings

      try await db.document("coll/doc").setData(["foo": "bar"])
      let result = try? await db.document("coll/doc").getDocument(source: .cache)
      XCTAssertEqual(["foo": "bar"], result?.data() as! [String: String])
    }

    func testCannotGetDocumentWithMemoryEagerGCEnabled() async throws {
      let settings = db.settings
      settings
        .cacheSettings = MemoryCacheSettings(garbageCollectorSettings: MemoryEagerGCSetting())
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
  }
#endif
