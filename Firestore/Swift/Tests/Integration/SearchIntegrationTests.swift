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
import XCTest

final class SearchIntegrationTests: FSTIntegrationTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()
    // Skip tests if the backend edition is not supported, similar to other integration tests.
    if FSTIntegrationTestCase.backendEdition() == .standard {
      throw XCTSkip("Skipping search tests because backend is not compatible.")
    }
  }

  func testSearchQueries() async throws {
    // create variable named firestore for consistent code snippets in proposal
    let firestore = db

    // Search with documentContainsText
    _ =
      firestore.pipeline().collection("restaurants")
        .search(query: DocumentMatches("waffles"))

    // Search with field containsText
    _ =
      firestore.pipeline().collection("restaurants")
        .search(query: Field("menu").matches("waffles"))

    // Semantic search
    _ =
      firestore.pipeline().collection("restaurants")
        .search(query: DocumentMatches("waffles"))

    // Search with geoDistance
    _ =
      firestore.pipeline().collection("restaurants")
        .search(
          query: Field("location")
            .geoDistance(GeoPoint(latitude: 38.989177, longitude: -107.065076))
            .lessThan(1000)
        )

    // Search with logical AND
    _ =
      firestore.pipeline().collection("restaurants")
        .search(
          query: Field("menu").matches("waffles") &&
            Field("description").matches("diner")
        )

    // Search with logical AND and geoDistance
    _ =
      firestore.pipeline().collection("restaurants")
        .search(
          query: Field("menu").matches("waffles") &&
            Field("location")
            .geoDistance(GeoPoint(
              latitude: 38.989177,
              longitude: -107.065076
            ))
            .lessThan(1000)
        )

    // Search with logical NOT
    _ =
      // With Not expression
      firestore.pipeline().collection("restaurants")
      .search(query: !Field("menu").matches("waffles"))

    // With RQuery minus (`-`)
    _ =
      firestore.pipeline().collection("restaurants")
        .search(query: !Field("menu").matches("waffles"))

    // Search with OR and AND in query string
    _ =
      firestore.pipeline().collection("restaurants")
        .search(query: DocumentMatches("(waffles OR pancakes) AND eggs"))

    // Search with string query
    _ =
      firestore.pipeline().collection("restaurants")
        .search(query: "(waffles OR pancakes) AND eggs")

    // Search with field-scoped string query
    _ = firestore.pipeline().collection("restaurants")
      .search(query: "menu:(waffles OR pancakes) AND description:\"breakfast all day\"")

    // Search with AND and between
    _ =
      firestore.pipeline().collection("products")
        .search(query: DocumentMatches("gaming laptop") &&
          Field("ram").between(32, 48))

    // Search with exclusion and OR
    _ = firestore.pipeline().collection("restaurants")
      .search(query:
        Field("menu").matches("-shellfish AND (hamburger OR steak)"))

    // Search with addFields for score and snippet
    _ =
      firestore.pipeline().collection("restaurants")
        .search(
          query: Field("menu").matches("waffles"),
          addFields: [
            SearchScore().as("searchScore"),
            Field("menu").snippet("waffles").as("snippet"),
          ]
        )

    // Search with select
    _ =
      firestore.pipeline().collection("restaurants")
        .search(
          query: Field("menu").matches("waffles"),
          select: [
            Field("menu"),
            Field("location"), // No string shorthand here
            Field(FieldPath.documentID()),
            SearchScore().as("searchScore"),
          ]
        )
  }

  func testSortingAndPagination() async throws {
    // create variable named firestore for consistent code snippets in proposal
    let firestore = db

    // Sort by topicality score
    _ = firestore.pipeline().collection("restaurants")
      .search(
        query: Field("menu").matches("waffles"),
        sort: [SearchScore().descending()]
      )

    // Sort by geo distance
    _ = firestore.pipeline().collection("restaurants")
      .search(
        query: Field("menu").matches("waffles"),
        sort: [
          Field("location")
            .geoDistance(GeoPoint(latitude: 38.989177, longitude: -107.065076))
            .ascending(),
        ]
      )

    // Sort by distance bracket then score
    _ = firestore.pipeline().collection("restaurants")
      .search(
        query: Field("menu").matches("waffles"),
        sort: [
          Field("location")
            .geoDistance(GeoPoint(latitude: 38.989177, longitude: -107.065076))
            .divide(10000)
            .floor()
            .ascending(),
          SearchScore().descending(),
        ]
      )

    // Limit results
    _ =
      firestore.pipeline().collection("restaurants")
        .search(
          query: Field("menu").matches("waffles"),
          limit: 10,
          sort: [SearchScore().descending()]
        )

    // Limit with retrievalDepth
    _ =
      firestore.pipeline().collection("foodBlogPosts")
        .search(
          query: DocumentMatches("kona coffee"),
          limit: 10,
          retrievalDepth: 1000,
          sort: [SearchScore().descending()]
        )

    // Pagination with offset
    let currentPage = 2
    _ =
      firestore.pipeline().collection("restaurants")
        .search(
          query: Field("menu").matches("waffles"),
          limit: 10,
          offset: 10 * (currentPage - 1)
        )
  }

  func testSnippets() async throws {
    let firestore = db

    // Snippet on a single field
    _ =
      firestore.pipeline().collection("foodBlogPosts")
        .search(
          query: Field("body").matches("kona coffee"),
          addFields: [
            Field("body").snippet("kona coffee").as("snippet"),
          ]
        )

    // Snippet on concatenated fields
    let rquery = "\"mac and cheese\""
    _ =
      firestore.pipeline().collection("foodBlogPosts")
        .search(
          query: rquery,
          addFields: [
            Field("description")
              .stringConcat([Field("summary")])
              .snippet(rquery)
              .as("snippet"),
          ]
        )


    // Snippet with multiple fields and OR
    _ =
      firestore.pipeline().collection("restaurants")
        .search(
          query: Field("menu").matches("waffles") ||
            Field("description").matches("\"breakfast all day\""),
          addFields: [
            Field("menu").snippet("waffles")
              .stringConcat([
                Constant("\n"),
                Field("description").snippet("breakfast all day"),
              ])
              .as("snippet"),
          ]
        )

    // Snippet with options
    _ =
      firestore.pipeline().collection("restaurants")
        .search(
          query: Field("menu").matches("waffles"),
          addFields: [
            Field("menu")
              .snippet(
                "waffles",
                maxSnippetWidth: 2000,
                maxSnippets: 2,
                separator: "..."
              )
              .as("snippet"),
          ]
        )
  }
}
