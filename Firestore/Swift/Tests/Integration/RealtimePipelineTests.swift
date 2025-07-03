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

import FirebaseFirestore
import Foundation

private let bookDocs: [String: [String: Any]] = [
  "book1": [
    "title": "The Hitchhiker's Guide to the Galaxy",
    "author": "Douglas Adams",
    "genre": "Science Fiction",
    "published": 1979,
    "rating": 4.2,
    "tags": ["comedy", "space", "adventure"], // Array literal
    "awards": ["hugo": true, "nebula": false], // Dictionary literal
    "nestedField": ["level.1": ["level.2": true]], // Nested dictionary literal
  ],
  "book2": [
    "title": "Pride and Prejudice",
    "author": "Jane Austen",
    "genre": "Romance",
    "published": 1813,
    "rating": 4.5,
    "tags": ["classic", "social commentary", "love"],
    "awards": ["none": true],
  ],
  "book3": [
    "title": "One Hundred Years of Solitude",
    "author": "Gabriel García Márquez",
    "genre": "Magical Realism",
    "published": 1967,
    "rating": 4.3,
    "tags": ["family", "history", "fantasy"],
    "awards": ["nobel": true, "nebula": false],
  ],
  "book4": [
    "title": "The Lord of the Rings",
    "author": "J.R.R. Tolkien",
    "genre": "Fantasy",
    "published": 1954,
    "rating": 4.7,
    "tags": ["adventure", "magic", "epic"],
    "awards": ["hugo": false, "nebula": false],
  ],
  "book5": [
    "title": "The Handmaid's Tale",
    "author": "Margaret Atwood",
    "genre": "Dystopian",
    "published": 1985,
    "rating": 4.1,
    "tags": ["feminism", "totalitarianism", "resistance"],
    "awards": ["arthur c. clarke": true, "booker prize": false],
  ],
  "book6": [
    "title": "Crime and Punishment",
    "author": "Fyodor Dostoevsky",
    "genre": "Psychological Thriller",
    "published": 1866,
    "rating": 4.3,
    "tags": ["philosophy", "crime", "redemption"],
    "awards": ["none": true],
  ],
  "book7": [
    "title": "To Kill a Mockingbird",
    "author": "Harper Lee",
    "genre": "Southern Gothic",
    "published": 1960,
    "rating": 4.2,
    "tags": ["racism", "injustice", "coming-of-age"],
    "awards": ["pulitzer": true],
  ],
  "book8": [
    "title": "1984",
    "author": "George Orwell",
    "genre": "Dystopian",
    "published": 1949,
    "rating": 4.2,
    "tags": ["surveillance", "totalitarianism", "propaganda"],
    "awards": ["prometheus": true],
  ],
  "book9": [
    "title": "The Great Gatsby",
    "author": "F. Scott Fitzgerald",
    "genre": "Modernist",
    "published": 1925,
    "rating": 4.0,
    "tags": ["wealth", "american dream", "love"],
    "awards": ["none": true],
  ],
  "book10": [
    "title": "Dune",
    "author": "Frank Herbert",
    "genre": "Science Fiction",
    "published": 1965,
    "rating": 4.6,
    "tags": ["politics", "desert", "ecology"],
    "awards": ["hugo": true, "nebula": true],
  ],
]

enum RaceResult<T> {
  case success(T)
  case timedOut
}

/// Executes an async operation with a timeout.
///
/// - Parameters:
///   - duration: The maximum time to wait for the operation to complete.
///   - operation: The async operation to perform.
/// - Returns: The result of the operation if it completes within the time limit, otherwise `nil`.
/// - Throws: An error if the `operation` itself throws an error before the timeout.
func withTimeout<T: Sendable>(nanoSeconds: UInt64,
                              operation: @escaping @Sendable () async throws -> T) async throws
  -> T? {
  return try await withThrowingTaskGroup(of: RaceResult.self) { group in
    // Add a task for the long-running operation.
    group.addTask {
      let result = try await operation()
      return .success(result)
    }

    // Add a task that just sleeps for the duration.
    group.addTask {
      try await Task.sleep(nanoseconds: nanoSeconds)
      return .timedOut
    }

    // Await the first result that comes in.
    guard let firstResult = try await group.next() else {
      // This should not happen if the group has tasks.
      return nil
    }

    // Once we have a winner, cancel the other task.
    // This is CRUCIAL to prevent the losing task from running forever.
    group.cancelAll()

    // Switch on the result to return the value or nil.
    switch firstResult {
    case let .success(value):
      return value
    case .timedOut:
      return nil
    }
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class RealtimePipelineIntegrationTests: FSTIntegrationTestCase {
  override func setUp() {
    FSTIntegrationTestCase.switchToEnterpriseMode()
    super.setUp()
  }

  func testBasicAsyncStream() async throws {
    let db = self.db
    let collRef = collectionRef()
    writeAllDocuments(bookDocs, toCollection: collRef)

    let pipeline = db
      .realtimePipeline()
      .collection(collRef.path)
      .where(Field("rating").gte(4.5))

    let stream = pipeline.snapshotStream()
    var iterator = stream.makeAsyncIterator()

    let firstSnapshot = try await iterator.next()
    XCTAssertEqual(firstSnapshot!.metadata.isFromCache, true)
    XCTAssertEqual(firstSnapshot!.results().count, 3)
    XCTAssertEqual(firstSnapshot!.results().first?.get("title") as? String, "Dune")
    XCTAssertEqual(firstSnapshot!.results()[1].get("title") as? String, "Pride and Prejudice")
    XCTAssertEqual(firstSnapshot!.results()[2].get("title") as? String, "The Lord of the Rings")

    // dropping Dune out of the result set
    try await collRef.document("book10").updateData(["rating": 4.4])
    let secondSnapshot = try await iterator.next()
    XCTAssertEqual(secondSnapshot!.results().count, 2)
    XCTAssertEqual(secondSnapshot!.results()[0].get("title") as? String, "Pride and Prejudice")
    XCTAssertEqual(secondSnapshot!.results()[1].get("title") as? String, "The Lord of the Rings")

    // Adding book1 to the result
    try await collRef.document("book1").updateData(["rating": 4.7])
    let thirdSnapshot = try await iterator.next()
    XCTAssertEqual(thirdSnapshot!.results().count, 3)
    XCTAssertEqual(
      thirdSnapshot!.results()[0].get("title") as? String,
      "The Hitchhiker's Guide to the Galaxy"
    )

    // Adding book1 to the result
    try await collRef.document("book2").delete()
    let fourthSnapshot = try await iterator.next()
    XCTAssertEqual(fourthSnapshot!.results().count, 2)
    XCTAssertEqual(
      fourthSnapshot!.results()[0].get("title") as? String,
      "The Hitchhiker's Guide to the Galaxy"
    )
    XCTAssertEqual(fourthSnapshot!.results()[1].get("title") as? String, "The Lord of the Rings")
  }

  func testResultChanges() async throws {
    let collRef = collectionRef(
      withDocuments: bookDocs
    )
    let db = collRef.firestore

    let pipeline = db
      .realtimePipeline()
      .collection(collRef.path)
      .where(Field("rating").gte(4.5))

    let stream = pipeline.snapshotStream()
    var iterator = stream.makeAsyncIterator()

    let firstSnapshot = try await iterator.next()
    XCTAssertEqual(firstSnapshot!.changes.count, 3)
    XCTAssertEqual(firstSnapshot!.changes.first?.result.get("title") as? String, "Dune")
    XCTAssertEqual(firstSnapshot!.changes.first?.type, .added)
    XCTAssertEqual(firstSnapshot!.changes[1].result.get("title") as? String, "Pride and Prejudice")
    XCTAssertEqual(firstSnapshot!.changes[1].type, .added)
    XCTAssertEqual(
      firstSnapshot!.changes[2].result.get("title") as? String,
      "The Lord of the Rings"
    )
    XCTAssertEqual(firstSnapshot!.changes[2].type, .added)

    // dropping Dune out of the result set
    try await collRef.document("book10").updateData(["rating": 4.4])
    let secondSnapshot = try await iterator.next()
    XCTAssertEqual(secondSnapshot!.changes.count, 1)
    XCTAssertEqual(secondSnapshot!.changes.first?.result.get("title") as? String, "Dune")
    XCTAssertEqual(secondSnapshot!.changes.first?.type, .removed)
    XCTAssertEqual(secondSnapshot!.changes.first?.oldIndex, 0)
    XCTAssertEqual(secondSnapshot!.changes.first?.newIndex, nil)

    // Adding book1 to the result
    try await collRef.document("book1").updateData(["rating": 4.7])
    let thirdSnapshot = try await iterator.next()
    XCTAssertEqual(thirdSnapshot!.changes.count, 1)
    XCTAssertEqual(
      thirdSnapshot!.changes[0].result.get("title") as? String,
      "The Hitchhiker's Guide to the Galaxy"
    )
    XCTAssertEqual(thirdSnapshot!.changes[0].type, .added)
    XCTAssertEqual(thirdSnapshot!.changes[0].oldIndex, nil)
    XCTAssertEqual(thirdSnapshot!.changes[0].newIndex, 0)

    // Delete book 2
    try await collRef.document("book2").delete()
    let fourthSnapshot = try await iterator.next()
    XCTAssertEqual(fourthSnapshot!.changes.count, 1)
    XCTAssertEqual(
      fourthSnapshot!.changes[0].result.get("title") as? String,
      "Pride and Prejudice"
    )
    XCTAssertEqual(fourthSnapshot!.changes[0].oldIndex, 1)
    XCTAssertEqual(fourthSnapshot!.changes[0].newIndex, nil)
  }

  func testCanListenToCache() async throws {
    let db = self.db
    let collRef = collectionRef()
    writeAllDocuments(bookDocs, toCollection: collRef)

    let pipeline = db
      .realtimePipeline()
      .collection(collRef.path)
      .where(Field("rating").gte(4.5))

    let stream = pipeline.snapshotStream(
      options: PipelineListenOptions(includeMetadataChanges: true, source: .cache)
    )
    var iterator = stream.makeAsyncIterator()

    let firstSnapshot = try await iterator.next()
    XCTAssertEqual(firstSnapshot!.metadata.isFromCache, true)
    XCTAssertEqual(firstSnapshot!.results().count, 3)
    XCTAssertEqual(firstSnapshot!.results().first?.get("title") as? String, "Dune")
    XCTAssertEqual(firstSnapshot!.results()[1].get("title") as? String, "Pride and Prejudice")
    XCTAssertEqual(firstSnapshot!.results()[2].get("title") as? String, "The Lord of the Rings")

    disableNetwork()
    enableNetwork()

    let duration: UInt64 = 100 * 1_000_000 // 100ms
    let result = try await withTimeout(nanoSeconds: duration) {
      try await iterator.next()
    }

    XCTAssertNil(result as Any?)
  }

  func testCanListenToMetadataOnlyChanges() async throws {
    let db = self.db
    let collRef = collectionRef()
    writeAllDocuments(bookDocs, toCollection: collRef)

    let pipeline = db
      .realtimePipeline()
      .collection(collRef.path)
      .where(Field("rating").gte(4.5))

    let stream = pipeline.snapshotStream(
      options: PipelineListenOptions(includeMetadataChanges: true)
    )
    var iterator = stream.makeAsyncIterator()

    let firstSnapshot = try await iterator.next()
    XCTAssertEqual(firstSnapshot!.metadata.isFromCache, true)
    XCTAssertEqual(firstSnapshot!.results().count, 3)
    XCTAssertEqual(firstSnapshot!.results().first?.get("title") as? String, "Dune")
    XCTAssertEqual(firstSnapshot!.results()[1].get("title") as? String, "Pride and Prejudice")
    XCTAssertEqual(firstSnapshot!.results()[2].get("title") as? String, "The Lord of the Rings")

    disableNetwork()
    enableNetwork()

    let secondSnapshot = try await iterator.next()
    XCTAssertEqual(secondSnapshot!.metadata.isFromCache, false)
    XCTAssertEqual(secondSnapshot!.results().count, 3)
    XCTAssertEqual(secondSnapshot!.changes.count, 0)
  }

  func testCanReadServerTimestampEstimateProperly() async throws {
    let db = self.db
    let collRef = collectionRef()
    writeAllDocuments(bookDocs, toCollection: collRef)

    disableNetwork()

    // Using the non-async version
    collRef.document("book1").updateData([
      "rating": FieldValue.serverTimestamp(),
    ]) { _ in }

    let stream = db.realtimePipeline().collection(collRef.path)
      .where(Field("title").eq("The Hitchhiker's Guide to the Galaxy"))
      .snapshotStream(options: PipelineListenOptions(serverTimestamps: .estimate))

    var iterator = stream.makeAsyncIterator()

    let firstSnapshot = try await iterator.next()
    let result = firstSnapshot!.results()[0]
    XCTAssertEqual(firstSnapshot!.metadata.isFromCache, true)
    XCTAssertNotNil(result.get("rating") as? Timestamp)
    XCTAssertEqual(result.get("rating") as? Timestamp, result.data["rating"] as? Timestamp)

    enableNetwork()

    let secondSnapshot = try await iterator.next()
    XCTAssertEqual(secondSnapshot!.metadata.isFromCache, false)
    XCTAssertNotEqual(
      secondSnapshot!.results()[0].get("rating") as? Timestamp,
      result.data["rating"] as? Timestamp
    )
  }

  func testCanEvaluateServerTimestampEstimateProperly() async throws {
    let db = self.db
    let collRef = collectionRef()
    writeAllDocuments(bookDocs, toCollection: collRef)

    disableNetwork()

    let now = Constant(Timestamp(date: Date()))
    // Using the non-async version
    collRef.document("book1").updateData([
      "rating": FieldValue.serverTimestamp(),
    ]) { _ in }

    let stream = db.realtimePipeline().collection(collRef.path)
      .where(Field("rating").timestampAdd(Constant("second"), Constant(1)).gt(now))
      .snapshotStream(
        options: PipelineListenOptions(serverTimestamps: .estimate, includeMetadataChanges: true)
      )

    var iterator = stream.makeAsyncIterator()

    let firstSnapshot = try await iterator.next()
    let result = firstSnapshot!.results()[0]
    XCTAssertEqual(firstSnapshot!.metadata.isFromCache, true)
    XCTAssertNotNil(result.get("rating") as? Timestamp)
    XCTAssertEqual(result.get("rating") as? Timestamp, result.data["rating"] as? Timestamp)

    // TODO(pipeline): Enable this when watch supports timestampAdd
    //    enableNetwork()
    //
    //    let secondSnapshot = try await iterator.next()
    //    XCTAssertEqual(secondSnapshot!.metadata.isFromCache, false)
    //    XCTAssertNotEqual(
    //      secondSnapshot!.results()[0].get("rating") as? Timestamp,
    //      result.data["rating"] as? Timestamp
    //    )
  }

  func testCanReadServerTimestampPreviousProperly() async throws {
    let db = self.db
    let collRef = collectionRef()
    writeAllDocuments(bookDocs, toCollection: collRef)

    disableNetwork()

    // Using the non-async version
    collRef.document("book1").updateData([
      "rating": FieldValue.serverTimestamp(),
    ]) { _ in }

    let stream = db.realtimePipeline().collection(collRef.path)
      .where(Field("title").eq("The Hitchhiker's Guide to the Galaxy"))
      .snapshotStream(options: PipelineListenOptions(serverTimestamps: .previous))

    var iterator = stream.makeAsyncIterator()

    let firstSnapshot = try await iterator.next()
    let result = firstSnapshot!.results()[0]
    XCTAssertEqual(firstSnapshot!.metadata.isFromCache, true)
    XCTAssertNotNil(result.get("rating") as? Double)
    XCTAssertEqual(result.get("rating") as! Double, 4.2)
    XCTAssertEqual(result.get("rating") as! Double, result.data["rating"] as! Double)

    enableNetwork()

    let secondSnapshot = try await iterator.next()
    XCTAssertEqual(secondSnapshot!.metadata.isFromCache, false)
    XCTAssertNotNil(secondSnapshot!.results()[0].get("rating") as? Timestamp)
  }

  func testCanEvaluateServerTimestampPreviousProperly() async throws {
    let db = self.db
    let collRef = collectionRef()
    writeAllDocuments(bookDocs, toCollection: collRef)

    disableNetwork()

    // Using the non-async version
    collRef.document("book1").updateData([
      "title": FieldValue.serverTimestamp(),
    ]) { _ in }

    let stream = db.realtimePipeline().collection(collRef.path)
      .where(Field("title").eq("The Hitchhiker's Guide to the Galaxy"))
      .snapshotStream(
        options: PipelineListenOptions(serverTimestamps: .previous)
      )

    var iterator = stream.makeAsyncIterator()

    let firstSnapshot = try await iterator.next()
    let result = firstSnapshot!.results()[0]
    XCTAssertEqual(firstSnapshot!.metadata.isFromCache, true)
    XCTAssertEqual(result.get("title") as? String, "The Hitchhiker's Guide to the Galaxy")

    // TODO(pipeline): Enable this when watch supports timestampAdd
    //    enableNetwork()
  }

  func testCanReadServerTimestampNoneProperly() async throws {
    let db = self.db
    let collRef = collectionRef()
    writeAllDocuments(bookDocs, toCollection: collRef)

    disableNetwork()

    // Using the non-async version
    collRef.document("book1").updateData([
      "rating": FieldValue.serverTimestamp(),
    ]) { _ in }

    let stream = db.realtimePipeline().collection(collRef.path)
      .where(Field("title").eq("The Hitchhiker's Guide to the Galaxy"))
      // .none is the default behavior
      .snapshotStream()

    var iterator = stream.makeAsyncIterator()

    let firstSnapshot = try await iterator.next()
    let result = firstSnapshot!.results()[0]
    XCTAssertEqual(firstSnapshot!.metadata.isFromCache, true)
    XCTAssertNil(result.get("rating") as? Timestamp)
    XCTAssertEqual(result.get("rating") as? Timestamp, result.data["rating"] as? Timestamp)

    enableNetwork()

    let secondSnapshot = try await iterator.next()
    XCTAssertEqual(secondSnapshot!.metadata.isFromCache, false)
    XCTAssertNotNil(secondSnapshot!.results()[0].get("rating") as? Timestamp)
  }

  func testCanEvaluateServerTimestampNoneProperly() async throws {
    let db = self.db
    let collRef = collectionRef()
    writeAllDocuments(bookDocs, toCollection: collRef)

    disableNetwork()

    // Using the non-async version
    collRef.document("book1").updateData([
      "title": FieldValue.serverTimestamp(),
    ]) { _ in }

    let stream = db.realtimePipeline().collection(collRef.path)
      .where(Field("title").isNull())
      .snapshotStream(
      )

    var iterator = stream.makeAsyncIterator()

    let firstSnapshot = try await iterator.next()
    let result = firstSnapshot!.results()[0]
    XCTAssertEqual(firstSnapshot!.metadata.isFromCache, true)
    XCTAssertNil(result.get("title") as? String)

    // TODO(pipeline): Enable this when watch supports timestampAdd
    //    enableNetwork()
  }

  func testSamePipelineWithDifferetnOptions() async throws {
    let db = self.db
    let collRef = collectionRef()
    writeAllDocuments(bookDocs, toCollection: collRef)

    disableNetwork()

    // Using the non-async version
    collRef.document("book1").updateData([
      "title": FieldValue.serverTimestamp(),
    ]) { _ in }

    let pipeline = db.realtimePipeline().collection(collRef.path)
      .where(Field("title").isNotNull())
      .limit(1)

    let stream1 = pipeline
      .snapshotStream(
        options: PipelineListenOptions(serverTimestamps: .previous)
      )

    var iterator1 = stream1.makeAsyncIterator()

    let firstSnapshot1 = try await iterator1.next()
    var result1 = firstSnapshot1!.results()[0]
    XCTAssertEqual(firstSnapshot1!.metadata.isFromCache, true)
    XCTAssertEqual(result1.get("title") as? String, "The Hitchhiker's Guide to the Galaxy")

    let stream2 = pipeline
      .snapshotStream(
        options: PipelineListenOptions(serverTimestamps: .estimate)
      )

    var iterator2 = stream2.makeAsyncIterator()

    let firstSnapshot2 = try await iterator2.next()
    var result2 = firstSnapshot2!.results()[0]
    XCTAssertEqual(firstSnapshot2!.metadata.isFromCache, true)
    XCTAssertNotNil(result2.get("title") as? Timestamp)

    enableNetwork()

    let secondSnapshot1 = try await iterator1.next()
    result1 = secondSnapshot1!.results()[0]
    XCTAssertEqual(secondSnapshot1!.metadata.isFromCache, false)
    XCTAssertNotNil(result1.get("title") as? Timestamp)

    let secondSnapshot2 = try await iterator2.next()
    result2 = secondSnapshot2!.results()[0]
    XCTAssertEqual(secondSnapshot2!.metadata.isFromCache, false)
    XCTAssertNotNil(result2.get("title") as? Timestamp)
  }
}
