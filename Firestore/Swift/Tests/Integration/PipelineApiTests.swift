// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import XCTest

import FirebaseFirestore

final class PipelineTests: FSTIntegrationTestCase {
  override func setUp() {
    FSTIntegrationTestCase.switchToEnterpriseMode()
    super.setUp()
  }

  func testCreatePipeline() async throws {
    let pipelineSource: PipelineSource = db.pipeline()

    let pipeline: Pipeline = pipelineSource.documents(
      [db.collection("foo").document("bar"), db.document("foo/baz")]
    )
    let _: Pipeline = pipelineSource.collection("foo")
    let _: Pipeline = pipelineSource.collectionGroup("foo")
    let _: Pipeline = pipelineSource.database()

    let query: Query = db.collection("foo").limit(to: 2)
    let _: Pipeline = pipelineSource.create(from: query)

    let _: PipelineSnapshot = try await pipeline.execute()
  }

  func testWhereStage() async throws {
    _ = db.pipeline().collection("books")
      .where(
        Field("rating").gt(4.0) && Field("genre").eq("Science Fiction") || ArrayContains(
          fieldName: "fieldName",
          values: "rating"
        )
      )
  }

  func testAddFieldStage() async throws {
    // Input
    // { title: 'title1', price: 10, discount: 0.8 },
    // { title: 'title2', price: 12, discount: 1.0 },
    // { title: 'title3', price: 5,  discount: 0.66 }

    // An expression that will compute price from the value of msrp field and discount field
    let priceExpr: FunctionExpr = Field("msrp").multiply(Field("discount"))

    // An expression becomes a Selectable when given an alias. In this case
    // the alias is 'salePrice'
    let priceSelectableExpr: Selectable = priceExpr.as("salePrice")

    _ = db.pipeline().collection("books")
      .addFields(
        priceSelectableExpr // Add field `salePrice` based computed from msrp and discount
      )

    // We don't expect customers to separate the Expression definition from the
    // Pipeline definition. This was shown above so readers of this doc can see
    // the different types involved. The cleaner way to write the code above
    // is to inline the Expr definition
    _ = db.pipeline().collection("books")
      .addFields(
        Field("msrp").multiply(Field("discount")).as("salePrice"),
        Field("author")
      )

    // Output
    // { title: 'title1', price: 10, discount: 0.8,  salePrice: 8.0},
    // { title: 'title2', price: 12, discount: 1.0,  salePrice: 12.0 },
    // { title: 'title3', price: 5,  discount: 0.66, salePrice: 3.30 }
  }

  func testRemoveFieldsStage() async throws {
    // removes field 'rating' and 'cost' from the previous stage outputs.
    _ = db.pipeline().collection("books").removeFields("rating", "cost")

    // removes field 'rating'.
    _ = db.pipeline().collection("books").removeFields(Field("rating"))
  }

  func testSelectStage() async throws {
    // Input
    // { title: 'title1', price: 10, discount: 0.8 },
    // { title: 'title2', price: 12, discount: 1.0 },
    // { title: 'title3', price: 5,  discount: 0.66 }

    // Overload for string and Selectable
    _ = db.pipeline().collection("books")
      .select(
        Field("title"), // Field class inheritates Selectable
        Field("msrp").multiply(Field("discount")).as("salePrice")
      )

    _ = db.pipeline().collection("books").select("title", "author")

    // Output
    // { title: 'title1', salePrice: 8.0},
    // { title: 'title2', salePrice: 12.0 },
    // { title: 'title3', salePrice: 3.30 }
  }

  func testSortStage() async throws {
    // Sort books by rating in descending order, and then by title in ascending order for books
    // with the same rating
    _ = db.pipeline().collection("books")
      .sort(
        Field("rating").descending(),
        Ascending("title") // alternative API offered
      )
  }

  func testLimitStage() async throws {
    // Limit the results to the top 10 highest-rated books
    _ = db.pipeline().collection("books")
      .sort(Field("rating").descending())
      .limit(10)
  }

  func testOffsetStage() async throws {
    // Retrieve the second page of 20 results
    _ = db.pipeline().collection("books")
      .sort(Field("published").descending())
      .offset(20) // Skip the first 20 results. Note that this must come
      // before .limit(...) unlike in Query where the order did not matter.
      .limit(20) // Take the next 20 results
  }

  func testDistinctStage() async throws {
    // Input
    // { author: 'authorA', genre: 'genreA', title: 'title1' },
    // { author: 'authorb', genre: 'genreB', title: 'title2' },
    // { author: 'authorB', genre: 'genreB', title: 'title3' }

    // Get a list of unique author names in uppercase and genre combinations.
    _ = db.pipeline().collection("books")
      .distinct(
        Field("author").uppercased().as("authorName"),
        Field("genre")
      )

    // Output
    // { authorName: 'AUTHORA', genre: 'genreA' },
    // { authorName: 'AUTHORB', genre: 'genreB' }
  }

  func testAggregateStage() async throws {
    // Input
    // { genre: 'genreA', title: 'title1', rating: 5.0 },
    // { genre: 'genreB', title: 'title2', rating: 1.5 },
    // { genre: 'genreB', title: 'title3', rating: 2.5 }

    // Calculate the average rating and the total number of books
    _ = db.pipeline().collection("books")
      .aggregate(
        Field("rating").avg().as("averageRating"),
        CountAll().as("totalBooks")
      )

    // Output
    // { totalBooks: 3, averageRating: 3.0 }

    // Input
    // { genre: 'genreA', title: 'title1', rating: 5.0 },
    // { genre: 'genreB', title: 'title2', rating: 1.5 },
    // { genre: 'genreB', title: 'title3', rating: 2.5 }

    // Calculate the average rating and the total number of books and group by field 'genre'
    _ = db.pipeline().collection("books")
      .aggregate([
        Field("rating").avg().as("averageRating"),
        CountAll().as("totalBooks"),
      ],
      groups: ["genre"])

    // Output
    // { genre: 'genreA', totalBooks: 1, averageRating: 5.0 }
    // { genre: 'genreB', totalBooks: 2, averageRating: 2.0 }
  }

  func testFindNearestStage() async throws {
    _ = db.pipeline().collection("books").findNearest(
      field: Field("embedding"),
      vectorValue: [5.0],
      distanceMeasure: .cosine,
      limit: 3)
  }

  func testReplaceStage() async throws {
    // Input.
    // {
//  "name": "John Doe Jr.",
//  "parents": {
//    "father": "John Doe Sr.",
//    "mother": "Jane Doe"
//    }
    // }

    // Emit field parents as the document.
    _ = db.pipeline().collection("people")
      .replace(with: Field("parents"))

    // Output
    // {
//  "father": "John Doe Sr.",
//  "mother": "Jane Doe"
    // }
  }

  func testSampleStage() async throws {
    // Sample 25 books, if the collection contains at least 25 documents
    _ = db.pipeline().collection("books").sample(count: 10)

    // Sample 10 percent of the collection of books
    _ = db.pipeline().collection("books").sample(percentage: 10)
  }

  func testUnionStage() async throws {
    // Emit documents from books collection and magazines collection.
    _ = db.pipeline().collection("books")
      .union(db.pipeline().collection("magazines"))
  }

  func testUnnestStage() async throws {
    // Input:
    // { "title": "The Hitchhiker's Guide to the Galaxy", "tags": [ "comedy", "space", "adventure"
    // ], ... }

    // Emit a book document for each tag of the book.
    _ = db.pipeline().collection("books")
      .unnest(Field("tags").as("tag"))

    // Output:
    // { "title": "The Hitchhiker's Guide to the Galaxy", "tag": "comedy", tags: [...], ... }
    // { "title": "The Hitchhiker's Guide to the Galaxy", "tag": "space", tags: [...], ... }
    // { "title": "The Hitchhiker's Guide to the Galaxy", "tag": "adventure", tags: [...], ... }

    // Emit a book document for each tag of the book mapped to its' index in the array.
    _ = db.pipeline().collection("books")
      .unnest(Field("tags").as("tag"), indexField: "index")

    // Output:
    // { "title": "The Hitchhiker's Guide to the Galaxy", "tag": "comedy", index: 0, tags: [...],
    // ... }
    // { "title": "The Hitchhiker's Guide to the Galaxy", "tag": "space", index: 1, tags: [...], ...
    // }
    // { "title": "The Hitchhiker's Guide to the Galaxy", "tag": "adventure", index: 2, tags: [...],
    // ... }
  }

  func testRawStage() async throws {
    // Assume we don't have a built-in "where" stage, the customer could still
    // add this stage by calling rawStage, passing the name of the stage "where",
    // and providing positional argument values.
    _ = db.pipeline().collection("books")
      .rawStage(name: "where",
                params: [Field("published").lt(1900)])
      .select("title", "author")

    // In cases where the stage also supports named argument values, then these can be
    // provided with a third argument that maps the argument name to value.
    // Note that these named arguments are always optional in the stage definition.
    _ = db.pipeline().collection("books")
      .rawStage(name: "where",
                params: [Field("published").lt(1900)],
                options: ["someOptionalParamName": "the argument value for this param"])
      .select("title", "author")
  }

  func testField() async throws {
    // An expression that will return the value of the field `name` in the document
    let nameField = Field("name")

    // An expression that will return the value of the field `description` in the document
    // Field is a sub-type of Expr, so we can also declare our var of type Expr
    let descriptionField: Expr = Field("description")

    // USAGE: anywhere an Expr type is accepted
    // Use a field in a pipeline
    _ = db.pipeline().collection("books")
      .addFields(
        Field("rating").as("bookRating") // Duplicate field 'rating' as 'bookRating'
      )

    // One special Field value is conveniently exposed as static function to help the user reference
    // reserved field values of __name__.
    _ = db.pipeline().collection("books")
      .addFields(
        DocumentId()
      )
  }

  func testConstant() async throws {
    // A constant for a number
    let three = Constant(3)

    // A constant for a string
    let name = Constant("Expressions API")

    // Const is a sub-type of Expr, so we can also declare our var of type Expr
    let nothing: Expr = Constant.nil

    // USAGE: Anywhere an Expr type is accepted
    // Add field `fromTheLibraryOf: 'Rafi'` to every document in the collection.
    _ = db.pipeline().collection("books")
      .addFields(Constant("Rafi").as("fromTheLibraryOf"))
  }

  func testFunctionExpr() async throws {
    let secondsField = Field("seconds")

    // Create a FunctionExpr using the multiply function to compute milliseconds
    let milliseconds: FunctionExpr = secondsField.multiply(1000)

    // A firestore function is also a sub-type of Expr
    let myExpr: Expr = milliseconds
  }

  func testBooleanExpr() async throws {
    let isApple: BooleanExpr = Field("type").eq("apple")

    // USAGE: stage where requires an expression of type BooleanExpr
    let allAppleOptions: Pipeline = db.pipeline().collection("fruitOptions").where(isApple)
  }

  func testSelectableExpr() async throws {
    let secondsField = Field("seconds")

    // Create a selectable from our milliseconds expression.
    let millisecondsSelectable: Selectable = secondsField.multiply(1000).as("milliseconds")

    // USAGE: stages addFields and select accept expressions of type Selectable
    // Add (or overwrite) the 'milliseconds` field to each of our documents using the
    // `.addFields(...)` stage.
    _ = db.pipeline().collection("lapTimes")
      .addFields(secondsField.multiply(1000).as("milliseconds"))

    // NOTE: Field implements Selectable, the alias is the same as the name
    let secondsSelectable: Selectable = secondsField
  }

  func testAggregateExpr() async throws {
    let lapTimeSum: AggregateFunction = Field("seconds").sum()

    let lapTimeSumTarget: AggregateWithAlias = lapTimeSum.as("totalTrackTime")

    // USAGE: stage aggregate accepts expressions of type AggregateWithAlias
    // A pipeline that will return one document with one field `totalTrackTime` that
    // is the sum of all laps ever taken on the track.
    _ = db.pipeline().collection("lapTimes")
      .aggregate(lapTimeSum.as("totalTrackTime"))
  }

  func testOrdering() async throws {
    let fastestToSlowest: Ordering = Field("seconds").ascending()

    // USAGE: stage sort accepts objects of type Ordering
    // Use this ordering to sort our lap times collection from fastest to slowest
    _ = db.pipeline().collection("lapTimes").sort(fastestToSlowest)
  }

  func testExpr() async throws {
    // An expression that computes the area of a circle
    // by chaining together two calls to the multiply function
    let radiusField: Expr = Field("radius")
    let radiusSq: Expr = radiusField.multiply(Field("radius"))
    let areaExpr: Expr = radiusSq.multiply(3.14)

    // Or define this expression in one clean, fluent statement
    let areaOfCircle: Selectable = Field("radius")
      .multiply(Field("radius"))
      .multiply(3.14)
      .as("area")

    // And pass the expression to a Pipeline for evaluation
    _ = db.pipeline().collection("circles").addFields(areaOfCircle)
  }

  func testGeneric() async throws {
    // This is the same of the logicalMin('price', 0)', if it did not exist
    let myLm = FunctionExpr("logicalMin", [Field("price"), Constant(0)])

    // Create a generic BooleanExpr for use where BooleanExpr is required
    let myEq = BooleanExpr("eq", [Field("price"), Constant(10)])

    // Create a generic AggregateFunction for use where AggregateFunction is required
    let mySum = AggregateFunction("sum", [Field("price")])
  }
}
