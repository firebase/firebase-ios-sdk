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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class PipelineIntegrationTests: FSTIntegrationTestCase {
  func testCount() async throws {
    try await firestore().collection("foo").document("bar").setData(["foo": "bar", "x": 42])
    let snapshot = try await firestore()
      .pipeline()
      .collection("/foo")
      .where(Field("foo") == Constant("bar"))
      .execute()

    print(snapshot)
  }

  func testEmptyResults() async throws {
    let collRef = collectionRef(
      withDocuments: bookDocs
    )
    let db = collRef.firestore

    let snapshot = try await db
      .pipeline()
      .collection("/" + collRef.path)
      .limit(0)
      .execute()

    XCTAssertTrue(snapshot.results.isEmpty)
  }
}
