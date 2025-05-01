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

class QueryIntegrationTests: FSTIntegrationTestCase {
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
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter1),
                                    matchesResult: ["doc1", "doc2", "doc4", "doc5"])

    // (a==1 && b==0) || (a==3 && b==2)
    let filter2 = Filter.orFilter(
      [Filter.andFilter(
        [Filter.whereField("a", isEqualTo: 1),
         Filter.whereField("b", isEqualTo: 0)]
      ),
      Filter.andFilter(
        [Filter.whereField("a", isEqualTo: 3),
         Filter.whereField("b", isEqualTo: 2)]
      )]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter2),
                                    matchesResult: ["doc1", "doc3"])

    // a==1 && (b==0 || b==3).
    let filter3 = Filter.andFilter(
      [Filter.whereField("a", isEqualTo: 1),
       Filter.orFilter(
         [Filter.whereField("b", isEqualTo: 0),
          Filter.whereField("b", isEqualTo: 3)]
       )]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter3),
                                    matchesResult: ["doc1", "doc4"])

    // (a==2 || b==2) && (a==3 || b==3)
    let filter4 = Filter.andFilter(
      [Filter.orFilter(
        [Filter.whereField("a", isEqualTo: 2),
         Filter.whereField("b", isEqualTo: 2)]
      ),
      Filter.orFilter(
        [Filter.whereField("a", isEqualTo: 3),
         Filter.whereField("b", isEqualTo: 3)]
      )]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter4),
                                    matchesResult: ["doc3"])

    // Test with limits without orderBy (the __name__ ordering is the tie breaker).
    let filter5 = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 2),
       Filter.whereField("b", isEqualTo: 1)]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter5).limit(to: 1),
                                    matchesResult: ["doc2"])
  }

  func testOrQueriesWithCompositeIndexes() throws {
    // TODO(orquery): Enable this test against production when possible.
    try XCTSkipIf(!FSTIntegrationTestCase.isRunningAgainstEmulator(),
                  "Skip this test if running against production because it results in" +
                    "a 'missing index' error. The Firestore Emulator, however, does serve these queries.")

    let collRef = collectionRef(
      withDocuments: ["doc1": ["a": 1, "b": 0],
                      "doc2": ["a": 2, "b": 1],
                      "doc3": ["a": 3, "b": 2],
                      "doc4": ["a": 1, "b": 3],
                      "doc5": ["a": 1, "b": 1]]
    )

    // with one inequality: a>2 || b==1.
    let filter1 = Filter.orFilter(
      [Filter.whereField("a", isGreaterThan: 2),
       Filter.whereField("b", isEqualTo: 1)]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter1),
                                    matchesResult: ["doc5", "doc2", "doc3"])

    // Test with limits (implicit order by ASC): (a==1) || (b > 0) LIMIT 2
    let filter2 = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 1),
       Filter.whereField("b", isGreaterThan: 0)]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter2).limit(to: 2),
                                    matchesResult: ["doc1", "doc2"])

    // Test with limits (explicit order by): (a==1) || (b > 0) LIMIT_TO_LAST 2
    // Note: The public query API does not allow implicit ordering when limitToLast is used.
    let filter3 = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 1),
       Filter.whereField("b", isGreaterThan: 0)]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter3)
      .limit(toLast: 2)
      .order(by: "b"),
      matchesResult: ["doc3", "doc4"])

    // Test with limits (explicit order by ASC): (a==2) || (b == 1) ORDER BY a LIMIT 1
    let filter4 = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 2),
       Filter.whereField("b", isEqualTo: 1)]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter4).limit(to: 1)
      .order(by: "a"),
      matchesResult: ["doc5"])

    // Test with limits (explicit order by DESC): (a==2) || (b == 1) ORDER BY a LIMIT_TO_LAST 1
    let filter5 = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 2),
       Filter.whereField("b", isEqualTo: 1)]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter5).limit(toLast: 1)
      .order(by: "a"),
      matchesResult: ["doc2"])
  }

  func testOrQueriesWithIn() throws {
    let collRef = collectionRef(
      withDocuments: ["doc1": ["a": 1, "b": 0],
                      "doc2": ["b": 1],
                      "doc3": ["a": 3, "b": 2],
                      "doc4": ["a": 1, "b": 3],
                      "doc5": ["a": 1],
                      "doc6": ["a": 2]]
    )

    // a==2 || b in [2,3]
    let filter = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 2),
       Filter.whereField("b", in: [2, 3])]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter),
                                    matchesResult: ["doc3", "doc4", "doc6"])
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
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter1),
                                    matchesResult: ["doc3", "doc4", "doc6"])

    // a==2 || b array-contains-any [0, 3]
    let filter2 = Filter.orFilter(
      [Filter.whereField("a", isEqualTo: 2),
       Filter.whereField("b", arrayContainsAny: [0, 3])]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter2),
                                    matchesResult: ["doc1", "doc4", "doc6"])
  }

  func testMultipleInOps() throws {
    let collRef = collectionRef(
      withDocuments: ["doc1": ["a": 1, "b": 0],
                      "doc2": ["b": 1],
                      "doc3": ["a": 3, "b": 2],
                      "doc4": ["a": 1, "b": 3],
                      "doc5": ["a": 1],
                      "doc6": ["a": 2]]
    )

    // Two IN operations on different fields with disjunction.
    let filter1 = Filter.orFilter(
      [Filter.whereField("a", in: [2, 3]),
       Filter.whereField("b", in: [0, 2])]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter1).order(by: "a"),
                                    matchesResult: ["doc1", "doc6", "doc3"])

    // Two IN operations on same fields with disjunction.
    // a IN [0,3] || a IN [0,2] should union them (similar to: a IN [0,2,3]).
    let filter2 = Filter.orFilter(
      [Filter.whereField("a", in: [0, 3]),
       Filter.whereField("a", in: [0, 2])]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter2),
                                    matchesResult: ["doc3", "doc6"])
  }

  func testUsingInWithArrayContainsAny() throws {
    let collRef = collectionRef(
      withDocuments: ["doc1": ["a": 1, "b": [0]],
                      "doc2": ["b": [1]],
                      "doc3": ["a": 3, "b": [2, 7], "c": 10],
                      "doc4": ["a": 1, "b": [3, 7]],
                      "doc5": ["a": 1],
                      "doc6": ["a": 2, "c": 20]]
    )

    let filter1 = Filter.orFilter(
      [Filter.whereField("a", in: [2, 3]),
       Filter.whereField("b", arrayContainsAny: [0, 7])]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter1),
                                    matchesResult: ["doc1", "doc3", "doc4", "doc6"])

    let filter2 = Filter.orFilter(
      [Filter.andFilter(
        [Filter.whereField("a", in: [2, 3]),
         Filter.whereField("c", isEqualTo: 10)]
      ),
      Filter.whereField("b", arrayContainsAny: [0, 7])]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter2),
                                    matchesResult: ["doc1", "doc3", "doc4"])
  }

  func testUseInWithArrayContains() throws {
    let collRef = collectionRef(
      withDocuments: ["doc1": ["a": 1, "b": [0]],
                      "doc2": ["b": [1]],
                      "doc3": ["a": 3, "b": [2, 7]],
                      "doc4": ["a": 1, "b": [3, 7]],
                      "doc5": ["a": 1],
                      "doc6": ["a": 2]]
    )

    let filter1 = Filter.orFilter(
      [Filter.whereField("a", in: [2, 3]),
       Filter.whereField("b", arrayContainsAny: [3])]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter1),
                                    matchesResult: ["doc3", "doc4", "doc6"])

    let filter2 = Filter.andFilter(
      [Filter.whereField("a", in: [2, 3]),
       Filter.whereField("b", arrayContains: 7)]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter2),
                                    matchesResult: ["doc3"])

    let filter3 = Filter.orFilter(
      [Filter.whereField("a", in: [2, 3]),
       Filter.andFilter(
         [Filter.whereField("b", arrayContains: 3),
          Filter.whereField("a", isEqualTo: 1)]
       )]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter3),
                                    matchesResult: ["doc3", "doc4", "doc6"])

    let filter4 = Filter.andFilter(
      [Filter.whereField("a", in: [2, 3]),
       Filter.orFilter(
         [Filter.whereField("b", arrayContains: 7),
          Filter.whereField("a", isEqualTo: 1)]
       )]
    )
    checkOnlineAndOfflineCollection(collRef, query: collRef.whereFilter(filter4),
                                    matchesResult: ["doc3"])
  }

  func testOrderByEquality() throws {
    // TODO(orquery): Enable this test against production when possible.
    try XCTSkipIf(!FSTIntegrationTestCase.isRunningAgainstEmulator(),
                  "Skip this test if running against production because order-by-equality is not supported yet.")

    let collRef = collectionRef(
      withDocuments: ["doc1": ["a": 1, "b": [0]],
                      "doc2": ["b": [1]],
                      "doc3": ["a": 3, "b": [2, 7], "c": 10],
                      "doc4": ["a": 1, "b": [3, 7]],
                      "doc5": ["a": 1],
                      "doc6": ["a": 2, "c": 20]]
    )

    checkOnlineAndOfflineCollection(
      collRef,
      query: collRef.whereFilter(Filter.whereField("a", isEqualTo: 1)),
      matchesResult: ["doc1", "doc4", "doc5"]
    )

    checkOnlineAndOfflineCollection(
      collRef,
      query: collRef.whereFilter(Filter.whereField("a", in: [2, 3])).order(by: "a"),
      matchesResult: ["doc6", "doc3"]
    )
  }
}
