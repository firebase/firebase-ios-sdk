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
  func testCreatePipeline() async throws {
    let pipelineSource: PipelineSource = db.pipeline()

    let pipeline: Pipeline = pipelineSource.documents(
      [db.collection("foo").document("bar"), db.document("foo/baz")]
    )
    let _: Pipeline = pipelineSource.collection("foo")
    let _: Pipeline = pipelineSource.collectionGroup("foo")
    let _: Pipeline = pipelineSource.database()

    let query: Query = db.collection("foo").limit(to: 2)
    let _: Pipeline = pipelineSource.createFrom(query)

    let aggregateQuery = db.collection("foo").count
    let _: Pipeline = pipelineSource.createFrom(aggregateQuery)

    let _: PipelineSnapshot = try await pipeline.execute()
  }

  func testWhereStage() async throws {
    _ = db.pipeline().collection("books")
      .where(
        BooleanExpr.and(
          Field("rating").gt(4.0), // Filter for ratings greater than 4.0
          Field("genre").eq("Science Fiction")
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
    let priceSelectableExpr: Selectable = priceExpr.alias("salePrice")

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
        Field("msrp").multiply(Field("discount")).alias("salePrice")
      )

    // Output
    // { title: 'title1', price: 10, discount: 0.8,  salePrice: 8.0},
    // { title: 'title2', price: 12, discount: 1.0,  salePrice: 12.0 },
    // { title: 'title3', price: 5,  discount: 0.66, salePrice: 3.30 }
  }
}
