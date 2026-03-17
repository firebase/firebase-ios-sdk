/*
 * Copyright 2026 Google LLC
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
import XCTest

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
final class SearchIntegrationTests: FSTIntegrationTestCase {
  let restaurantData: [String: [String: Any]] = [
    "sunnySideUp": [
      "name": "The Sunny Side Up",
      "description": "A cozy neighborhood diner serving classic breakfast favorites all day long, from fluffy pancakes to savory omelets.",
      "location": GeoPoint(latitude: 39.7541, longitude: -105.0002),
      "menu": "<h3>Breakfast Classics</h3><ul><li>Denver Omelet - $12</li><li>Buttermilk Pancakes - $10</li><li>Steak and Eggs - $16</li></ul><h3>Sides</h3><ul><li>Hash Browns - $4</li><li>Thick-cut Bacon - $5</li><li>Drip Coffee - $2</li></ul>",
      "average_price_per_person": 15,
    ],
    "goldenWaffle": [
      "name": "The Golden Waffle",
      "description": "Specializing exclusively in Belgian-style waffles. Open daily from 6:00 AM to 11:00 AM.",
      "location": GeoPoint(latitude: 39.7183, longitude: -104.9621),
      "menu": "<h3>Signature Waffles</h3><ul><li>Strawberry Delight - $11</li><li>Chicken and Waffles - $14</li><li>Chocolate Chip Crunch - $10</li></ul><h3>Drinks</h3><ul><li>Fresh OJ - $4</li><li>Artisan Coffee - $3</li></ul>",
      "average_price_per_person": 13,
    ],
    "lotusBlossomThai": [
      "name": "Lotus Blossom Thai",
      "description": "Authentic Thai cuisine featuring hand-crushed spices and traditional family recipes from the Chiang Mai region.",
      "location": GeoPoint(latitude: 39.7315, longitude: -104.9847),
      "menu": "<h3>Appetizers</h3><ul><li>Spring Rolls - $7</li><li>Chicken Satay - $9</li></ul><h3>Main Course</h3><ul><li>Pad Thai - $15</li><li>Green Curry - $16</li><li>Drunken Noodles - $15</li></ul>",
      "average_price_per_person": 22,
    ],
    "mileHighCatch": [
      "name": "Mile High Catch",
      "description": "Freshly sourced seafood offering a wide variety of Pacific fish and Atlantic shellfish in an upscale atmosphere.",
      "location": GeoPoint(latitude: 39.7401, longitude: -104.9903),
      "menu": "<h3>From the Raw Bar</h3><ul><li>Oysters (Half Dozen) - $18</li><li>Lobster Cocktail - $22</li></ul><h3>Entrees</h3><ul><li>Pan-Seared Salmon - $28</li><li>King Crab Legs - $45</li><li>Fish and Chips - $19</li></ul>",
      "average_price_per_person": 45,
    ],
    "peakBurgers": [
      "name": "Peak Burgers",
      "description": "Casual burger joint focused on locally sourced Colorado beef and hand-cut fries.",
      "location": GeoPoint(latitude: 39.7622, longitude: -105.0125),
      "menu": "<h3>Burgers</h3><ul><li>The Peak Double - $12</li><li>Bison Burger - $15</li><li>Veggie Stack - $11</li></ul><h3>Sides</h3><ul><li>Truffle Fries - $6</li><li>Onion Rings - $5</li></ul>",
      "average_price_per_person": 18,
    ],
    "solTacos": [
      "name": "El Sol Tacos",
      "description": "A vibrant street-side taco stand serving up quick, delicious, and traditional Mexican street food.",
      "location": GeoPoint(latitude: 39.6952, longitude: -105.0274),
      "menu": "<h3>Tacos ($3.50 each)</h3><ul><li>Al Pastor</li><li>Carne Asada</li><li>Pollo Asado</li><li>Nopales (Cactus)</li></ul><h3>Beverages</h3><ul><li>Horchata - $4</li><li>Mexican Coke - $3</li></ul>",
      "average_price_per_person": 12,
    ],
    "eastsideTacos": [
      "name": "Eastside Cantina",
      "description": "Authentic street tacos and hand-shaken margaritas on the vibrant east side of the city.",
      "location": GeoPoint(latitude: 39.735, longitude: -104.885),
      "menu": "<h3>Tacos</h3><ul><li>Carnitas Tacos - $4</li><li>Barbacoa Tacos - $4.50</li><li>Shrimp Tacos - $5</li></ul><h3>Drinks</h3><ul><li>House Margarita - $9</li><li>Jarritos - $3</li></ul>",
      "average_price_per_person": 18,
    ],
    "eastsideChicken": [
      "name": "Eastside Chicken",
      "description": "Fried chicken to go - next to Eastside Cantina.",
      "location": GeoPoint(latitude: 39.735, longitude: -104.885),
      "menu": "<h3>Fried Chicken</h3><ul><li>Drumstick - $4</li><li>Wings - $1</li><li>Sandwich - $9</li></ul><h3>Drinks</h3><ul><li>House Margarita - $9</li><li>Jarritos - $3</li></ul>",
      "average_price_per_person": 12,
    ],
  ]

  override func setUp() async throws {
    try await super.setUp()

    // Skip tests if the backend edition is not supported
    if FSTIntegrationTestCase.backendEdition() == .standard {
      throw XCTSkip("Skipping search tests because backend is not compatible.")
    }

    // Now you can safely await your async setup logic
    setUpTestDocs()
  }

  func setUpTestDocs() {
    writeAllDocuments(restaurantData, toCollection: collectionRef())
  }

  override func collectionRef() -> CollectionReference {
    return db.collection("SearchIntegrationTests")
  }

  func testAllSearchFeatures() async throws {
    let firestore = db
    let queryLocation = GeoPoint(latitude: 0, longitude: 0)
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(
        query: Field("description").matches("breakfast") &&
          Field("location").geoDistance(queryLocation).lessThan(1000) &&
          Field("avgPrice").between(10, 20),
        limit: 50,
        retrievalDepth: 1000,
        sort: [
          Field("location").geoDistance(queryLocation).ascending(),
        ],
        addFields: [
          SearchScore().as("searchScore"),
        ],
        select: [
          Field("title"),
          Field("menu"),
          Field("description"),
          Field("location").geoDistance(queryLocation).as("distance"),
        ],
        offset: 0,
        queryEnhancement: .disabled
      )

    let snapshot = try await (pipeline.execute())
    XCTAssertEqual(snapshot.results.count, 1)
    XCTAssertEqual(snapshot.results[0].id, "goldenWaffle")
  }

  func testSearchFullDocument() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(query: DocumentMatches("waffles"))

    let snapshot = try await (pipeline.execute())
    XCTAssertEqual(snapshot.results.count, 1)
    XCTAssertEqual(snapshot.results[0].id, "goldenWaffle")
  }

  func testSearchSpecificField() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(query: Field("menu").matches("waffles"))

    let snapshot = try await (pipeline.execute())
    XCTAssertEqual(snapshot.results.count, 1)
    XCTAssertEqual(snapshot.results[0].id, "goldenWaffle")
  }

  func testGeoNearQuery() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(query: Field("location")
        .geoDistance(GeoPoint(latitude: 39.6985, longitude: -105.024))
        .lessThan(1000))

    let snapshot = try await (pipeline.execute())
    XCTAssertEqual(snapshot.results.count, 1)
    XCTAssertEqual(snapshot.results[0].id, "solTacos")
  }

  func testConjunctionOfTextSearchPredicates() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(query: Field("menu").matches("waffles") && Field("description").matches("diner"))

    let snapshot = try await (pipeline.execute())
    let docIDs = snapshot.results.map { $0.id ?? "" }.sorted()
    XCTAssertEqual(docIDs, ["goldenWaffle", "sunnySideUp"])
  }

  func testConjunctionOfTextSearchAndGeoNear() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(query: Field("menu").matches("tacos") &&
        Field("location")
        .geoDistance(GeoPoint(latitude: 39.6985, longitude: -105.024))
        .lessThan(10000))

    let snapshot = try await (pipeline.execute())
    XCTAssertEqual(snapshot.results.count, 1)
    XCTAssertEqual(snapshot.results[0].id, "solTacos")
  }

  func testNegateMatch() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(query: !Field("menu").matches("waffles"))
    let snapshot = try await (pipeline.execute())
    let docIDs = snapshot.results.map { $0.id ?? "" }.sorted()
    XCTAssertEqual(
      docIDs,
      [
        "eastsideChicken",
        "eastsideTacos",
        "lotusBlossomThai",
        "mileHighCatch",
        "peakBurgers",
        "solTacos",
        "sunnySideUp",
      ]
    )
  }

  func testRQuerySearchTheDocumentWithConjunctionAndDisjunction() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(query: DocumentMatches("(waffles OR pancakes) AND coffee"))

    let snapshot = try await (pipeline.execute())
    let docIDs = snapshot.results.map { $0.id ?? "" }.sorted()
    XCTAssertEqual(docIDs, ["goldenWaffle", "sunnySideUp"])
  }

  func testRQueryAsQueryParam() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(query: "(waffles OR pancakes) AND coffee")

    let snapshot = try await (pipeline.execute())
    let docIDs = snapshot.results.map { $0.id ?? "" }.sorted()
    XCTAssertEqual(docIDs, ["goldenWaffle", "sunnySideUp"])
  }

  func testRQuerySupportsFieldPaths() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(query: "menu:(waffles OR pancakes) AND description:\"breakfast all day\"")

    let snapshot = try await (pipeline.execute())
    XCTAssertEqual(snapshot.results.count, 1)
    XCTAssertEqual(snapshot.results[0].id, "sunnySideUp")
  }

  func testConjunctionOfRQueryAndExpression() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(query: DocumentMatches("tacos") && Field("average_price_per_person").between(8, 15))

    let snapshot = try await (pipeline.execute())
    XCTAssertEqual(snapshot.results.count, 1)
    XCTAssertEqual(snapshot.results[0].id, "solTacos")
  }

  func testAddTopicalityScoreAndSnippet() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(
        query: Field("menu").matches("waffles"),
        addFields: [
          SearchScore().as("searchScore"),
          Field("menu").snippet("waffles").as("snippet"),
        ]
      )
      .select([Field("name"), Field("searchScore"), Field("snippet")])

    let snapshot = try await (pipeline.execute())
    XCTAssertEqual(snapshot.results.count, 1)
    let doc = snapshot.results[0]
    XCTAssertEqual(doc.get("name") as? String, "The Golden Waffle")
    XCTAssertGreaterThan(doc.get("searchScore") as? Double ?? 0, 0)
    XCTAssertGreaterThan((doc.get("snippet") as? String)?.count ?? 0, 0)
  }

  func testSelectTopicalityScoreAndSnippet() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(
        query: Field("menu").matches("waffles"),
        select: [
          Field("name"),
          Field("location"),
          SearchScore().as("searchScore"),
          Field("menu").snippet("waffles").as("snippet"),
        ]
      )

    let snapshot = try await (pipeline.execute())
    XCTAssertEqual(snapshot.results.count, 1)
    let doc = snapshot.results[0]
    XCTAssertEqual(doc.get("name") as? String, "The Golden Waffle")
    XCTAssertEqual(
      doc.get("location") as? GeoPoint,
      GeoPoint(latitude: 39.7183, longitude: -104.9621)
    )
    XCTAssertGreaterThan(doc.get("searchScore") as? Double ?? 0, 0)
    XCTAssertGreaterThan((doc.get("snippet") as? String)?.count ?? 0, 0)
    XCTAssertEqual(doc.data.keys.sorted(), ["location", "name", "searchScore", "snippet"])
  }

  func testSortByTopicality() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(
        query: Field("menu").matches("tacos"),
        sort: [SearchScore().descending()]
      )

    let snapshot = try await (pipeline.execute())
    let docIDs = snapshot.results.map { $0.id }
    XCTAssertEqual(docIDs, ["eastsideTacos", "solTacos"])
  }

  func testSortByDistance() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(
        query: Field("menu").matches("tacos"),
        sort: [
          Field("location")
            .geoDistance(GeoPoint(latitude: 39.6985, longitude: -105.024))
            .ascending(),
        ]
      )

    let snapshot = try await (pipeline.execute())
    let docIDs = snapshot.results.map { $0.id }
    XCTAssertEqual(docIDs, ["solTacos", "eastsideTacos"])
  }

  func testSortByMultipleOrderings() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(
        query: Field("menu").matches("tacos OR chicken"),
        sort: [
          Field("location")
            .geoDistance(GeoPoint(latitude: 39.6985, longitude: -105.024))
            .ascending(),
          SearchScore().descending(),
        ]
      )

    let snapshot = try await (pipeline.execute())
    let docIDs = snapshot.results.map { $0.id }
    XCTAssertEqual(docIDs, ["solTacos", "eastsideTacos", "eastsideChicken"])
  }

  func testLimitTheNumberOfDocumentsReturned() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(
        limit: 3,
        sort: [
          Field("location")
            .geoDistance(GeoPoint(latitude: 39.6985, longitude: -105.024))
            .ascending(),
        ]
      )

    let snapshot = try await (pipeline.execute())
    let docIDs = snapshot.results.map { $0.id }
    XCTAssertEqual(docIDs, ["solTacos", "goldenWaffle", "lotusBlossomThai"])
  }

  func testLimitTheNumberOfDocumentsScored() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(
        query: Field("menu").matches("chicken OR tacos OR fish OR waffles"),
        retrievalDepth: 6
      )

    let snapshot = try await (pipeline.execute())
    let docIDs = snapshot.results.map { $0.id ?? "" }.sorted()
    XCTAssertEqual(docIDs, ["eastsideChicken", "eastsideTacos", "mileHighCatch", "solTacos"])
  }

  func testSkipsNDocuments() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(
        limit: 2,
        offset: 2
      )

    let snapshot = try await (pipeline.execute())
    let docIDs = snapshot.results.map { $0.id ?? "" }.sorted()
    XCTAssertEqual(docIDs, ["eastsideTacos", "goldenWaffle"])
  }

  func testSearchFullDocumentWithQueryExpansion() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(query: DocumentMatches("waffles"), queryEnhancement: .required)

    let snapshot = try await (pipeline.execute())
    let docIDs = snapshot.results.map { $0.id ?? "" }.sorted()
    XCTAssertEqual(docIDs, ["goldenWaffle", "sunnySideUp"])
  }

  func testSearchSpecificFieldWithQueryExpansion() async throws {
    let firestore = db
    let pipeline = firestore.pipeline().collection("restaurants")
      .search(query: Field("menu").matches("waffles"), queryEnhancement: .required)

    let snapshot = try await (pipeline.execute())
    let docIDs = snapshot.results.map { $0.id ?? "" }.sorted()
    XCTAssertEqual(docIDs, ["goldenWaffle", "sunnySideUp"])
  }

  func testSnippetOptions() async throws {
    let firestore = db
    let pipeline1 = firestore.pipeline().collection("restaurants")
      .search(
        query: Field("menu").matches("waffles"),
        addFields: [
          Field("menu").snippet("waffles", maxSnippetWidth: 10).as("snippet"),
        ]
      )

    let snapshot1 = try await (pipeline1.execute())
    XCTAssertEqual(snapshot1.results.count, 1)
    let doc1 = snapshot1.results[0]
    XCTAssertEqual(doc1.get("name") as? String, "The Golden Waffle")
    let snippet1 = doc1.get("snippet") as? String ?? ""
    XCTAssertGreaterThan(snippet1.count, 0)

    let pipeline2 = firestore.pipeline().collection("restaurants")
      .search(
        query: Field("menu").matches("waffles"),
        addFields: [
          Field("menu").snippet("waffles", maxSnippetWidth: 1000).as("snippet"),
        ]
      )
    let snapshot2 = try await (pipeline2.execute())
    XCTAssertEqual(snapshot2.results.count, 1)
    let doc2 = snapshot2.results[0]
    XCTAssertEqual(doc2.get("name") as? String, "The Golden Waffle")
    let snippet2 = doc2.get("snippet") as? String ?? ""
    XCTAssertGreaterThan(snippet2.count, 0)

    XCTAssertGreaterThan(snippet2.count, snippet1.count)
  }

  func testSnippetOnMultipleFields() async throws {
    let firestore = db
    let pipeline1 = firestore.pipeline().collection("restaurants")
      .search(
        query: DocumentMatches("waffle"),
        addFields: [
          Field("menu").snippet("waffles", maxSnippetWidth: 2000).as("snippet"),
        ]
      )

    let snapshot1 = try await (pipeline1.execute())
    XCTAssertEqual(snapshot1.results.count, 1)
    let doc1 = snapshot1.results[0]
    XCTAssertEqual(doc1.get("name") as? String, "The Golden Waffle")
    let snippet1 = doc1.get("snippet") as? String ?? ""
    XCTAssertGreaterThan(snippet1.count, 0)

    let pipeline2 = firestore.pipeline().collection("restaurants")
      .search(
        query: DocumentMatches("waffle"),
        addFields: [
          Field("menu").stringConcat([Field("description")])
            .snippet("waffles", maxSnippetWidth: 2000).as("snippet"),
        ]
      )
    let snapshot2 = try await (pipeline2.execute())
    XCTAssertEqual(snapshot2.results.count, 1)
    let doc2 = snapshot2.results[0]
    XCTAssertEqual(doc2.get("name") as? String, "The Golden Waffle")
    let snippet2 = doc2.get("snippet") as? String ?? ""
    XCTAssertGreaterThan(snippet2.count, 0)

    XCTAssertGreaterThan(snippet2.count, snippet1.count)
  }
}
