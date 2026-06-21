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

import FirebaseFirestore
import Foundation

class IndexingTests: FSTIntegrationTestCase {
  func testAutoIndexCreationSetSuccessfully() throws {
    // Use persistent disk cache (explicit)
    let settings = db.settings
    settings.cacheSettings = PersistentCacheSettings()
    db.settings = settings

    let coll = collectionRef()
    let testDocs = [
      "a": ["match": true],
      "b": ["match": false],
      "c": ["match": false],
    ]
    writeAllDocuments(testDocs, toCollection: coll)

    coll.whereField("match", isEqualTo: true)
      .getDocuments(source: .cache) { querySnapshot, err in
        XCTAssertNil(err)
        XCTAssertEqual(querySnapshot!.count, 1)
      }

    let enableIndexAutoCreation = {
      try FSTExceptionCatcher.catchException {
        self.db.persistentCacheIndexManager!.enableIndexAutoCreation()
      }
    }
    XCTAssertNoThrow(try enableIndexAutoCreation())
    coll.whereField("match", isEqualTo: true)
      .getDocuments(source: .cache) { querySnapshot, err in
        XCTAssertNil(err)
        XCTAssertEqual(querySnapshot!.count, 1)
      }

    let disableIndexAutoCreation = {
      try FSTExceptionCatcher.catchException {
        self.db.persistentCacheIndexManager!.disableIndexAutoCreation()
      }
    }
    XCTAssertNoThrow(try disableIndexAutoCreation())
    coll.whereField("match", isEqualTo: true)
      .getDocuments(source: .cache) { querySnapshot, err in
        XCTAssertNil(err)
        XCTAssertEqual(querySnapshot!.count, 1)
      }

    let deleteAllIndexes = {
      try FSTExceptionCatcher.catchException {
        self.db.persistentCacheIndexManager!.deleteAllIndexes()
      }
    }
    XCTAssertNoThrow(try deleteAllIndexes())
    coll.whereField("match", isEqualTo: true)
      .getDocuments(source: .cache) { querySnapshot, err in
        XCTAssertNil(err)
        XCTAssertEqual(querySnapshot!.count, 1)
      }
  }

  func testAutoIndexCreationSetSuccessfullyUsingDefault() throws {
    // Use persistent disk cache (default)
    let coll = collectionRef()
    let testDocs = [
      "a": ["match": true],
      "b": ["match": false],
      "c": ["match": false],
    ]
    writeAllDocuments(testDocs, toCollection: coll)

    coll.whereField("match", isEqualTo: true)
      .getDocuments(source: .cache) { querySnapshot, err in
        XCTAssertNil(err)
        XCTAssertEqual(querySnapshot!.count, 1)
      }

    let enableIndexAutoCreation = {
      try FSTExceptionCatcher.catchException {
        self.db.persistentCacheIndexManager!.enableIndexAutoCreation()
      }
    }
    XCTAssertNoThrow(try enableIndexAutoCreation())
    coll.whereField("match", isEqualTo: true)
      .getDocuments(source: .cache) { querySnapshot, err in
        XCTAssertNil(err)
        XCTAssertEqual(querySnapshot!.count, 1)
      }

    let disableIndexAutoCreation = {
      try FSTExceptionCatcher.catchException {
        self.db.persistentCacheIndexManager!.disableIndexAutoCreation()
      }
    }
    XCTAssertNoThrow(try disableIndexAutoCreation())
    coll.whereField("match", isEqualTo: true)
      .getDocuments(source: .cache) { querySnapshot, err in
        XCTAssertNil(err)
        XCTAssertEqual(querySnapshot!.count, 1)
      }

    let deleteAllIndexes = {
      try FSTExceptionCatcher.catchException {
        self.db.persistentCacheIndexManager!.deleteAllIndexes()
      }
    }
    XCTAssertNoThrow(try deleteAllIndexes())
    coll.whereField("match", isEqualTo: true)
      .getDocuments(source: .cache) { querySnapshot, err in
        XCTAssertNil(err)
        XCTAssertEqual(querySnapshot!.count, 1)
      }
  }
}
