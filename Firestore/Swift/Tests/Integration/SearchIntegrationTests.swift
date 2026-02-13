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
        .search(query: SearchDocumentFor("waffles"))

    // Search with field containsText
    _ =
      firestore.pipeline().collection("restaurants")
        .search(query: Field("menu").searchFor("waffles"))

    // Semantic search
    _ =
      firestore.pipeline().collection("restaurants")
        .search(query: SearchDocumentFor("waffles", mode: .semantic))

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
          query: Field("menu").searchFor("waffles") &&
            Field("description").searchFor("diner")
        )

    // Search with logical AND and geoDistance
    _ =
      firestore.pipeline().collection("restaurants")
        .search(
          query: Field("menu").searchFor("waffles") &&
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
      .search(query: !Field("menu").searchFor("waffles"))

    // With RQuery minus (`-`)
    _ =
      firestore.pipeline().collection("restaurants")
        .search(query: !Field("menu").searchFor("waffles"))

    // Search with OR and AND in query string
    _ =
      firestore.pipeline().collection("restaurants")
        .search(query: SearchDocumentFor("(waffles OR pancakes) AND eggs"))

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
        .search(query: SearchDocumentFor("gaming laptop") &&
          Field("ram").between(32, 48))

    // Search with exclusion and OR
    _ = firestore.pipeline().collection("restaurants")
      .search(query:
        Field("menu").searchFor("-shellfish AND (hamburger OR steak)"))

    // Search with addFields for score and snippet
    _ =
      firestore.pipeline().collection("restaurants")
        .search(
          query: Field("menu").searchFor("waffles"),
          addFields: [
            TopicalityScore().as("searchScore"),
            Field("menu").snippet("waffles").as("snippet"),
          ]
        )

    // Search with select
    _ =
      firestore.pipeline().collection("restaurants")
        .search(
          query: Field("menu").searchFor("waffles"),
          select: [
            Field("menu"),
            Field("location"), // No string shorthand here
            Field(FieldPath.documentID()),
            TopicalityScore().as("searchScore"),
          ]
        )
  }

  func testSortingAndPagination() async throws {
    // create variable named firestore for consistent code snippets in proposal
    let firestore = db

    // Sort by topicality score
    _ = firestore.pipeline().collection("restaurants")
      .search(
        query: Field("menu").searchFor("waffles"),
        sort: [TopicalityScore().descending()]
      )

    // Sort by geo distance
    _ = firestore.pipeline().collection("restaurants")
      .search(
        query: Field("menu").searchFor("waffles"),
        sort: [
          Field("location")
            .geoDistance(GeoPoint(latitude: 38.989177, longitude: -107.065076))
            .ascending(),
        ]
      )

    // Sort by distance bracket then score
    _ = firestore.pipeline().collection("restaurants")
      .search(
        query: Field("menu").searchFor("waffles"),
        sort: [
          Field("location")
            .geoDistance(GeoPoint(latitude: 38.989177, longitude: -107.065076))
            .divide(10000)
            .floor()
            .ascending(),
          TopicalityScore().descending(),
        ]
      )

    // Limit results
    _ =
      firestore.pipeline().collection("restaurants")
        .search(
          query: Field("menu").searchFor("waffles"),
          limit: 10,
          sort: [TopicalityScore().descending()]
        )

    // Limit with maxToScore
    _ =
      firestore.pipeline().collection("foodBlogPosts")
        .search(
          query: SearchDocumentFor("kona coffee"),
          limit: 10,
          maxToScore: 1000,
          sort: [TopicalityScore().descending()]
        )

    // Pagination with offset
    let currentPage = 2
    _ =
      firestore.pipeline().collection("restaurants")
        .search(
          query: Field("menu").searchFor("waffles"),
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
          query: Field("body").searchFor("kona coffee"),
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

    // Snippet with document-level highlighting
    let rqueryWithFields = "body:\"mac and cheese\" AND tags:quick"

    _ = firestore.pipeline().collection("foodBlogPosts")
      .search(
        query: rqueryWithFields,
        addFields: [
          DocumentSnippet(rqueryWithFields).as("snippet"),
        ]
      )

    // Snippet with multiple fields and OR
    _ =
      firestore.pipeline().collection("restaurants")
        .search(
          query: Field("menu").searchFor("waffles") ||
            Field("description").searchFor("\"breakfast all day\""),
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
          query: Field("menu").searchFor("waffles", mode: .semantic),
          addFields: [
            Field("menu")
              .snippet(
                "waffles",
                maxSnippetWidth: 2000,
                maxSnippets: 2,
                separator: "...",
                searchMode: .semantic
              )
              .as("snippet"),
          ]
        )
  }

  func testPartitioning() async throws {
    // create variable named firestore for consistent code snippets in proposal
    let firestore = db

    // Partition with a single key
    _ = firestore.pipeline().collection("emails")
      .search(
        query: Field("body").searchFor("urgent"),
        partition: [
          "email": "user@domain",
        ]
      )

    // Partition with multiple keys
    _ = firestore.pipeline().collection("emails")
      .search(
        query: Field("body").searchFor("urgent"),
        partition: [
          "email": "user@domain",
          "folder": "inbox",
        ]
      )
  }
}
