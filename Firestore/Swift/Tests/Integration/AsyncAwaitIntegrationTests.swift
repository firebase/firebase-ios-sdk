/*
 * Copyright 2021 Google LLC
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

let emptyBundle = """
{\
   "metadata":{\
      "id":"test",\
      "createTime":{\
         "seconds":0,\
         "nanos":0\
      },\
      "version":1,\
      "totalDocuments":0,\
      "totalBytes":0\
   }\
}
"""

#if swift(>=5.5.2)
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  class AsyncAwaitIntegrationTests: FSTIntegrationTestCase {
    func testAddData() async throws {
      let collection = collectionRef()
      let document = try await collection.addDocument(data: [:])
      let snapshot = try await document.getDocument()
      XCTAssertTrue(snapshot.exists)
    }

    func testLoadBundleFromData() async throws {
      let bundle = "\(emptyBundle.count)\(emptyBundle)"
      let bundleProgress = try await db.loadBundle(Data(bundle.utf8))
      XCTAssertEqual(LoadBundleTaskState.success, bundleProgress.state)
    }

    func testLoadBundleFromEmptyDataFails() async throws {
      do {
        _ = try await db.loadBundle(Data())
        XCTFail("Bundle loading should have failed")
      } catch {
        XCTAssertEqual((error as NSError).domain, FirestoreErrorDomain)
        XCTAssertEqual((error as NSError).code, FirestoreErrorCode.unknown.rawValue)
      }
    }

    func testLoadBundleFromStream() async throws {
      let bundle = "\(emptyBundle.count)\(emptyBundle)"
      let bundleProgress = try await db
        .loadBundle(InputStream(data: bundle.data(using: String.Encoding.utf8)!))
      XCTAssertEqual(LoadBundleTaskState.success, bundleProgress.state)
    }

    func testRunTransactionDoesNotCrashOnNilSuccess() async throws {
      let value = try await db.runTransaction { transact, error in
        nil // should not crash
      }

      XCTAssertNil(value, "value should be nil on success")
    }

    func testQuery() async throws {
      let collRef = collectionRef(
        withDocuments: ["doc1": ["a": 1, "b": 0],
                        "doc2": ["a": 2, "b": 1],
                        "doc3": ["a": 3, "b": 2],
                        "doc4": ["a": 1, "b": 3],
                        "doc5": ["a": 1, "b": 1]]
      )

      // Two equalities: a==1 || b==1.
      let filter = Filter.orFilter(
        [Filter.whereField("a", isEqualTo: 1),
         Filter.whereField("b", isEqualTo: 1)]
      )
      let query = collRef.whereFilter(filter)
      let snapshot = try await query.getDocuments(source: FirestoreSource.server)
      XCTAssertEqual(FIRQuerySnapshotGetIDs(snapshot),
                     ["doc1", "doc2", "doc4", "doc5"])
    }

    func testAutoIndexCreationAfterFailsTermination() async throws {
      try await db.terminate()

      let enableIndexAutoCreation = {
        try FSTExceptionCatcher.catchException {
          self.db.persistentCacheIndexManager?.enableIndexAutoCreation()
        }
      }
      XCTAssertThrowsError(try enableIndexAutoCreation(), "The client has already been terminated.")

      let disableIndexAutoCreation = {
        try FSTExceptionCatcher.catchException {
          self.db.persistentCacheIndexManager?.disableIndexAutoCreation()
        }
      }
      XCTAssertThrowsError(
        try disableIndexAutoCreation(),
        "The client has already been terminated."
      )

      let deleteAllIndexes = {
        try FSTExceptionCatcher.catchException {
          self.db.persistentCacheIndexManager?.deleteAllIndexes()
        }
      }
      XCTAssertThrowsError(try deleteAllIndexes(), "The client has already been terminated.")
    }
  }
#endif
