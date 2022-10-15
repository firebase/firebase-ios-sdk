/*
 * Copyright 2022 Google LLC
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
import FirebaseFirestoreSwift
import Foundation

class QueryIntegrationTests: FSTIntegrationTestCase {
  /**
   * Checks that running the query while online (against the backend/emulator) results in the same
   * documents as running the query while offline. If expectedDocs is provided, it also checks
   * that both online and offline query result is equal to the expected documents.
   *
   * @param query The query to check.
   * @param expectedDocs Ordered list of document keys that are expected to match the query.
   */
  private func checkOnlineAndOfflineQuery(_ query: Query, matchesResult expectedDocs: [String]?) {
    let docsFromServer = readDocumentSet(forRef: query,
                                         source: FirestoreSource.server)

    let docsFromCache = readDocumentSet(forRef: query,
                                        source: FirestoreSource.cache)

    XCTAssertEqual(FIRQuerySnapshotGetIDs(docsFromServer),
                   FIRQuerySnapshotGetIDs(docsFromCache))
    if expectedDocs != nil {
      XCTAssertEqual(FIRQuerySnapshotGetIDs(docsFromCache), expectedDocs)
    }
  }

  func testOrQueries() throws {
    let collRef = collectionRef(
      withDocuments: ["doc1": ["a": 1, "b": 0],
                      "doc2": ["a": 2, "b": 1],
                      "doc3": ["a": 3, "b": 2],
                      "doc4": ["a": 1, "b": 3],
                      "doc5": ["a": 1, "b": 1]]
    )

    // Two equalities: a==1 || b==1.
    let filter1 = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 1),
       Filter.whereField("b", isEqualTo: 1)]
    )
    checkOnlineAndOfflineQuery(collRef.whereFilter(filter1),
                               matchesResult: ["doc1", "doc2", "doc4", "doc5"])

    // with one inequality: a>2 || b==1.
    let filter2 = Filter.orFilter(
      [Filter.whereField("a", isGreaterThan: 2),
       Filter.whereField("b", isEqualTo: 1)]
    )
    checkOnlineAndOfflineQuery(collRef.whereFilter(filter2),
                               matchesResult: ["doc5", "doc2", "doc3"])

    // (a==1 && b==0) || (a==3 && b==2)
    let filter3 = Filter.orFilter(
      [Filter.andFilter(
        [Filter.whereField("a", isEqualTo: 1),
         Filter.whereField("b", isEqualTo: 0)]
      ),
      Filter.andFilter(
        [Filter.whereField("a", isEqualTo: 3),
         Filter.whereField("b", isEqualTo: 2)]
      )]
    )
    checkOnlineAndOfflineQuery(collRef.whereFilter(filter3),
                               matchesResult: ["doc1", "doc3"])

    // a==1 && (b==0 || b==3).
    let filter4 = Filter.andFilter(
      [Filter.whereField("a", isEqualTo: 1),
       Filter.orFilter(
         [Filter.whereField("b", isEqualTo: 0),
          Filter.whereField("b", isEqualTo: 3)]
       )]
    )
    checkOnlineAndOfflineQuery(collRef.whereFilter(filter4),
                               matchesResult: ["doc1", "doc4"])

    // (a==2 || b==2) && (a==3 || b==3)
    let filter5 = Filter.andFilter(
      [Filter.orFilter(
        [Filter.whereField("a", isEqualTo: 2),
         Filter.whereField("b", isEqualTo: 2)]
      ),
      Filter.orFilter(
        [Filter.whereField("a", isEqualTo: 3),
         Filter.whereField("b", isEqualTo: 3)]
      )]
    )
    checkOnlineAndOfflineQuery(collRef.whereFilter(filter5),
                               matchesResult: ["doc3"])

    // Test with limits (implicit order by ASC): (a==1) || (b > 0) LIMIT 2
    let filter6 = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 1),
       Filter.whereField("b", isGreaterThan: 0)]
    )
    checkOnlineAndOfflineQuery(collRef.whereFilter(filter6).limit(to: 2),
                               matchesResult: ["doc1", "doc2"])

    // Test with limits (explicit order by): (a==1) || (b > 0) LIMIT_TO_LAST 2
    // Note: The public query API does not allow implicit ordering when limitToLast is used.
    let filter7 = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 1),
       Filter.whereField("b", isGreaterThan: 0)]
    )
    checkOnlineAndOfflineQuery(collRef.whereFilter(filter7)
      .limit(toLast: 2)
      .order(by: "b"),
      matchesResult: ["doc3", "doc4"])

    // Test with limits (explicit order by ASC): (a==2) || (b == 1) ORDER BY a LIMIT 1
    let filter8 = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 2),
       Filter.whereField("b", isEqualTo: 1)]
    )
    checkOnlineAndOfflineQuery(collRef.whereFilter(filter8).limit(to: 1)
      .order(by: "a"),
      matchesResult: ["doc5"])

    // Test with limits (explicit order by DESC): (a==2) || (b == 1) ORDER BY a LIMIT_TO_LAST 1
    let filter9 = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 2),
       Filter.whereField("b", isEqualTo: 1)]
    )
    checkOnlineAndOfflineQuery(collRef.whereFilter(filter9).limit(toLast: 1)
      .order(by: "a"),
      matchesResult: ["doc2"])

    // Test with limits without orderBy (the __name__ ordering is the tie breaker).
    let filter10 = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 2),
       Filter.whereField("b", isEqualTo: 1)]
    )
    checkOnlineAndOfflineQuery(collRef.whereFilter(filter10).limit(to: 1),
                               matchesResult: ["doc2"])
  }

  func testOrQueriesWithInAndNotIn() throws {
    let collRef = collectionRef(
      withDocuments: ["doc1": ["a": 1, "b": 0],
                      "doc2": ["b": 1],
                      "doc3": ["a": 3, "b": 2],
                      "doc4": ["a": 1, "b": 3],
                      "doc5": ["a": 1],
                      "doc6": ["a": 2]]
    )

    // a==2 || b in [2,3]
    let filter1 = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 2),
       Filter.whereField("b", in: [2, 3])]
    )
    checkOnlineAndOfflineQuery(collRef.whereFilter(filter1),
                               matchesResult: ["doc3", "doc4", "doc6"])

    // a==2 || b not-in [2,3]
    // Has implicit orderBy b.
    let filter2 = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 2),
       Filter.whereField("b", notIn: [2, 3])]
    )
    checkOnlineAndOfflineQuery(collRef.whereFilter(filter2),
                               matchesResult: ["doc1", "doc2"])
  }

  func testOrQueriesWithArrayMembership() throws {
    let collRef = collectionRef(
      withDocuments: ["doc1": ["a": 1, "b": [0]],
                      "doc2": ["b": 1],
                      "doc3": ["a": 3, "b": [2, 7]],
                      "doc4": ["a": 1, "b": [3, 7]],
                      "doc5": ["a": 1],
                      "doc6": ["a": 2]]
    )

    // a==2 || b array-contains 7
    let filter1 = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 2),
       Filter.whereField("b", arrayContains: 7)]
    )
    checkOnlineAndOfflineQuery(collRef.whereFilter(filter1),
                               matchesResult: ["doc3", "doc4", "doc6"])

    // a==2 || b array-contains-any [0, 3]
    let filter2 = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 2),
       Filter.whereField("b", arrayContainsAny: [0, 3])]
    )
    checkOnlineAndOfflineQuery(collRef.whereFilter(filter2),
                               matchesResult: ["doc1", "doc4", "doc6"])
  }
}
