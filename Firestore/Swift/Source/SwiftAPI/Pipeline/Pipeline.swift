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

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE
import Foundation

/// The `Pipeline` class provides a flexible and expressive framework for building complex data
/// transformation and query pipelines for Firestore.
///
/// A pipeline takes data sources, such as Firestore collections or collection groups, and applies
/// a series of stages that are chained together. Each stage takes the output from the previous
/// stage
/// (or the data source) and produces an output for the next stage (or as the final output of the
/// pipeline).
///
/// Expressions can be used within each stage to filter and transform data through the stage.
///
/// NOTE: The chained stages do not prescribe exactly how Firestore will execute the pipeline.
/// Instead, Firestore only guarantees that the result is the same as if the chained stages were
/// executed in order.
///
/// ## Usage Examples
///
/// The following examples assume you have a `Firestore` instance named `db`.
///
/// ```swift
/// import FirebaseFirestore
///
/// // Example 1: Select specific fields and rename 'rating' to 'bookRating'.
/// // Assumes `Field("rating").as("bookRating")` is a valid `Selectable` expression.
/// do {
/// let results1 = try await db.pipeline().collection("books")
/// .select(Field("title"), Field("author"), Field("rating").as("bookRating"))
/// .execute()
/// print("Results 1: \(results1.documents)")
/// } catch {
/// print("Error in example 1: \(error)")
/// }
///
/// // Example 2: Filter documents where 'genre' is "Science Fiction" and 'published' is after 1950.
/// // Assumes `Function.eq`, `Function.gt`, and `Function.and` create `BooleanExpr`.
/// do {
/// let results2 = try await db.pipeline().collection("books")
/// .where(Function.and(
/// Function.eq(Field("genre"), "Science Fiction"),
/// Function.gt(Field("published"), 1950)
/// ))
/// .execute()
/// print("Results 2: \(results2.documents)")
/// } catch {
/// print("Error in example 2: \(error)")
/// }
///
/// // Example 3: Calculate the average rating of books published after 1980.
/// // Assumes `avg()` creates an `Accumulator` and `AggregateWithAlias` is used correctly.
/// do {
/// let results3 = try await db.pipeline().collection("books")
/// .where(Function.gt(Field("published"), 1980))
/// .aggregate(AggregateWithas(avg(Field("rating")), alias: "averageRating"))
/// .execute()
/// print("Results 3: \(results3.documents)")
/// } catch {
/// print("Error in example 3: \(error)")
/// }
/// ```
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public struct Pipeline: @unchecked Sendable {
  private var stages: [Stage]
  let bridge: PipelineBridge
  let db: Firestore

  init(stages: [Stage], db: Firestore) {
    self.stages = stages
    self.db = db
    bridge = PipelineBridge(stages: stages.map { $0.bridge }, db: db)
  }

  /// Executes the defined pipeline and returns a `PipelineSnapshot` containing the results.
  ///
  /// This method asynchronously sends the pipeline definition to Firestore for execution.
  /// The resulting documents, transformed and filtered by the pipeline stages, are returned
  /// within a `PipelineSnapshot`.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume a pipeline is already configured.
  /// do {
  ///   let snapshot = try await pipeline.execute()
  ///   // Process snapshot.documents
  ///   print("Pipeline executed successfully: \(snapshot.documents)")
  /// } catch {
  ///   print("Pipeline execution failed: \(error)")
  /// }
  /// ```
  ///
  /// - Throws: An error if the pipeline execution fails on the backend.
  /// - Returns: A `PipelineSnapshot` containing the result of the pipeline execution.
  public func execute() async throws -> PipelineSnapshot {
    return try await withCheckedThrowingContinuation { continuation in
      self.bridge.execute { result, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: PipelineSnapshot(result!, pipeline: self))
        }
      }
    }
  }

  /// Adds new fields to outputs from previous stages.
  ///
  /// This stage allows you to compute values on-the-fly based on existing data from previous
  /// stages or constants. You can use this to create new fields or overwrite existing ones
  /// (if there is a name overlap).
  ///
  /// The added fields are defined using `Selectable`s, which can be:
  /// - `Field`: References an existing document field.
  /// - `Function`: Performs a calculation using functions like `Function.add` or
  /// `Function.multiply`,
  ///   typically with an assigned alias (e.g., `Function.multiply(Field("price"),
  /// 1.1).as("priceWithTax")`).
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline from a collection.
  /// let updatedPipeline = pipeline.addFields(
  ///   Field("rating").as("bookRating"), // Rename 'rating' to 'bookRating'.
  ///   Function.add(5, Field("quantity")).as("totalQuantityPlusFive") // Calculate
  /// 'totalQuantityPlusFive'.
  /// )
  /// // let results = try await updatedPipeline.execute()
  /// ```
  ///
  /// - Parameter field: The first field to add to the documents, specified as a `Selectable`.
  /// - Parameter additionalFields: Optional additional fields to add, specified as `Selectable`s.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func addFields(_ field: Selectable, _ additionalFields: Selectable...) -> Pipeline {
    let fields = [field] + additionalFields
    return Pipeline(stages: stages + [AddFields(fields: fields)], db: db)
  }

  /// Removes fields from outputs of previous stages.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// let updatedPipeline = pipeline.removeFields(Field("confidentialData"), Field("internalNotes"))
  /// // let results = try await updatedPipeline.execute()
  /// ```
  ///
  /// - Parameter field: The first field to remove, specified as a `Field` instance.
  /// - Parameter additionalFields: Optional additional fields to remove.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func removeFields(_ field: Field, _ additionalFields: Field...) -> Pipeline {
    return Pipeline(
      stages: stages + [RemoveFieldsStage(fields: [field] + additionalFields)],
      db: db
    )
  }

  /// Removes fields from outputs of previous stages using field names.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// // Removes fields 'rating' and 'cost' from the previous stage outputs.
  /// let updatedPipeline = pipeline.removeFields("rating", "cost")
  /// // let results = try await updatedPipeline.execute()
  /// ```
  ///
  /// - Parameter field: The name of the first field to remove.
  /// - Parameter additionalFields: Optional additional field names to remove.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func removeFields(_ field: String, _ additionalFields: String...) -> Pipeline {
    return Pipeline(
      stages: stages + [RemoveFieldsStage(fields: [field] + additionalFields)],
      db: db
    )
  }

  /// Selects or creates a set of fields from the outputs of previous stages.
  ///
  /// The selected fields are defined using `Selectable` expressions, which can be:
  /// - `String`: Name of an existing field (implicitly converted to `Field`).
  /// - `Field`: References an existing field.
  /// - `Function`: Represents the result of a function with an assigned alias
  ///   (e.g., `Function.toUppercase(Field("address")).as("upperAddress")`).
  ///
  /// If no selections are provided, the output of this stage is typically empty.
  /// Use `addFields` if only additions are desired without replacing the existing document
  /// structure.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// let projectedPipeline = pipeline.select(
  ///   Field("firstName"),
  ///   Field("lastName"),
  ///   Function.toUppercase(Field("address")).as("upperAddress")
  /// )
  /// // let results = try await projectedPipeline.execute()
  /// ```
  ///
  /// - Parameter selection: The first field to include in the output documents, specified as a
  /// `Selectable`.
  /// - Parameter additionalSelections: Optional additional fields to include, specified as
  /// `Selectable`s.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func select(_ selection: Selectable, _ additionalSelections: Selectable...) -> Pipeline {
    let selections = [selection] + additionalSelections
    return Pipeline(
      stages: stages + [Select(selections: selections)],
      db: db
    )
  }

  /// Selects a set of fields from the outputs of previous stages using field names.
  ///
  /// The selected fields are specified by their names. If no selections are provided,
  /// the output of this stage is typically empty. Use `addFields` if only additions are desired.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// let projectedPipeline = pipeline.select("title", "author", "yearPublished")
  /// // let results = try await projectedPipeline.execute()
  /// ```
  ///
  /// - Parameter selection: The name of the first field to include in the output documents.
  /// - Parameter additionalSelections: Optional additional field names to include.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func select(_ selection: String, _ additionalSelections: String...) -> Pipeline {
    let selections = ([selection] + additionalSelections).map { Field($0) }
    return Pipeline(
      stages: stages + [Select(selections: selections)],
      db: db
    )
  }

  /// Filters documents from previous stages, including only those matching the specified
  /// `BooleanExpr`.
  ///
  /// This stage applies conditions similar to a "WHERE" clause in SQL.
  /// Filter documents based on field values using `BooleanExpr` implementations, such as:
  /// - Field comparators: `Function.eq`, `Function.lt` (less than), `Function.gt` (greater than).
  /// - Logical operators: `Function.and`, `Function.or`, `Function.not`.
  /// - Advanced functions: `Function.regexMatch`, `Function.arrayContains`.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// let filteredPipeline = pipeline.where(
  ///     Field("rating").gt(4.0)   // Rating greater than 4.0.
  ///     && Field("genre").eq("Science Fiction") // Genre is "Science Fiction".
  /// )
  /// // let results = try await filteredPipeline.execute()
  /// ```
  ///
  /// - Parameter condition: The `BooleanExpr` to apply.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func `where`(_ condition: BooleanExpr) -> Pipeline {
    return Pipeline(stages: stages + [Where(condition: condition)], db: db)
  }

  /// Skips the first `offset` number of documents from the results of previous stages.
  ///
  /// A negative input number might count back from the end of the result set,
  /// depending on backend behavior. This stage is useful for pagination,
  /// typically used with `limit` to control page size.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline, possibly sorted.
  /// // Retrieve the second page of 20 results (skip first 20, limit to next 20).
  /// let pagedPipeline = pipeline
  ///                     .sort(Ascending("published")) // Example sort.
  ///                     .offset(20)  // Skip the first 20 results.
  ///                     .limit(20)   // Take the next 20 results.
  /// // let results = try await pagedPipeline.execute()
  /// ```
  ///
  /// - Parameter offset: The number of documents to skip (a `Int32` value).
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func offset(_ offset: Int32) -> Pipeline {
    return Pipeline(stages: stages + [Offset(offset)], db: db)
  }

  /// Limits the maximum number of documents returned by previous stages to `limit`.
  ///
  /// A negative input number might count back from the end of the result set,
  /// depending on backend behavior. This stage helps retrieve a controlled subset of data.
  /// It's often used for:
  /// - **Pagination:** With `offset` to retrieve specific pages.
  /// - **Limiting Data Retrieval:** To improve performance with large collections.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// // Limit results to the top 10 highest-rated books.
  /// let topTenPipeline = pipeline
  ///                      .sort(Descending(Field("rating")))
  ///                      .limit(10)
  /// // let results = try await topTenPipeline.execute()
  /// ```
  ///
  /// - Parameter limit: The maximum number of documents to return (a `Int32` value).
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func limit(_ limit: Int32) -> Pipeline {
    return Pipeline(stages: stages + [Limit(limit)], db: db)
  }

  /// Returns a set of distinct documents based on specified grouping field names.
  ///
  /// This stage ensures that only unique combinations of values for the specified
  /// group fields are included from the previous stage's output.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// // Get a list of unique author and genre combinations.
  /// let distinctAuthorsGenresPipeline = pipeline.distinct("author", "genre")
  /// // To further select only the author:
  /// //   .select("author")
  /// // let results = try await distinctAuthorsGenresPipeline.execute()
  /// ```
  ///
  /// - Parameter group: The name of the first field for distinct value combinations.
  /// - Parameter additionalGroups: Optional additional field names.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func distinct(_ group: String, _ additionalGroups: String...) -> Pipeline {
    let selections = ([group] + additionalGroups).map { Field($0) }
    return Pipeline(stages: stages + [Distinct(groups: selections)], db: db)
  }

  /// Returns a set of distinct documents based on specified `Selectable` expressions.
  ///
  /// This stage ensures unique combinations of values from evaluated `Selectable`
  /// expressions (e.g., `Field` or `Function` results).
  ///
  /// `Selectable` expressions can be:
  /// - `Field`: A reference to an existing document field.
  /// - `Function`: The result of a function with an alias (e.g.,
  /// `Function.toUppercase(Field("author")).as("authorName")`).
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// // Get unique uppercase author names and genre combinations.
  /// let distinctPipeline = pipeline.distinct(
  ///   Field("author").uppercased().as("authorName"),
  ///   Field("genre")
  /// )
  /// // To select only the transformed author name:
  /// //   .select(Field("authorName"))
  /// // let results = try await distinctPipeline.execute()
  /// ```
  ///
  /// - Parameter group: The first `Selectable` expression to consider.
  /// - Parameter additionalGroups: Optional additional `Selectable` expressions.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func distinct(_ group: Selectable, _ additionalGroups: Selectable...) -> Pipeline {
    let groups = [group] + additionalGroups
    return Pipeline(stages: stages + [Distinct(groups: groups)], db: db)
  }

  /// Performs aggregation operations on all documents from previous stages.
  ///
  /// Computes aggregate values (e.g., sum, average, count) over the entire set of documents
  /// from the previous stage. Aggregations are defined using `AggregateWithAlias`,
  /// which pairs an `Accumulator` (e.g., `avg(Field("price"))`) with a result field name.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume pipeline from a "books" collection.
  /// // Calculate the average rating and total number of books.
  /// let aggregatedPipeline = pipeline.aggregate(
  ///   AggregateWithas(aggregate: avg(Field("rating")), alias: "averageRating"),
  ///   AggregateWithas(aggregate: countAll(), alias: "totalBooks")
  /// )
  /// // let results = try await aggregatedPipeline.execute()
  /// // results.documents might be: [["averageRating": 4.2, "totalBooks": 150]]
  /// ```
  ///
  /// - Parameter accumulator: The first `AggregateWithAlias` expression.
  /// - Parameter additionalAccumulators: Optional additional `AggregateWithAlias` expressions.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func aggregate(_ accumulator: AggregateWithAlias,
                        _ additionalAccumulators: AggregateWithAlias...) -> Pipeline {
    return Pipeline(
      stages: stages + [Aggregate(
        accumulators: [accumulator] + additionalAccumulators,
        groups: nil // No grouping: aggregate over all documents.
      )],
      db: db
    )
  }

  /// Performs optionally grouped aggregation operations on documents from previous stages.
  ///
  /// Calculates aggregate values, optionally grouping documents by fields or `Selectable`
  /// expressions.
  /// - **Grouping:** Defined by the `groups` parameter. Each unique combination of values
  ///   from these `Selectable`s forms a group. If `groups` is `nil` or empty,
  ///   all documents form a single group.
  /// - **Accumulators:** An array of `AggregateWithAlias` defining operations
  ///   (e.g., sum, average) within each group.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume pipeline from "books" collection.
  /// // Calculate the average rating for each genre.
  /// let groupedAggregationPipeline = pipeline.aggregate(
  ///   [AggregateWithas(aggregate: avg(Field("rating")), alias: "avg_rating")],
  ///   groups: [Field("genre")] // Group by the "genre" field.
  /// )
  /// // let results = try await groupedAggregationPipeline.execute()
  /// // results.documents might be:
  /// // [
  /// //   ["genre": "SciFi", "avg_rating": 4.5],
  /// //   ["genre": "Fantasy", "avg_rating": 4.2]
  /// // ]
  /// ```
  ///
  /// - Parameters:
  ///   - accumulator: An array of `AggregateWithAlias` expressions for calculations.
  ///   - groups: Optional array of `Selectable` expressions for grouping. If `nil` or empty,
  /// aggregates across all documents.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func aggregate(_ accumulator: [AggregateWithAlias],
                        groups: [Selectable]? = nil) -> Pipeline {
    return Pipeline(stages: stages + [Aggregate(accumulators: accumulator, groups: groups)], db: db)
  }

  /// Performs optionally grouped aggregation operations using field names for grouping.
  ///
  /// Similar to the other `aggregate` method, but `groups` are specified as an array of `String`
  /// field names.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume pipeline from "books" collection.
  /// // Count books for each publisher.
  /// let groupedByPublisherPipeline = pipeline.aggregate(
  ///   [AggregateWithas(aggregate: countAll(), alias: "book_count")],
  ///   groups: ["publisher"] // Group by the "publisher" field name.
  /// )
  /// // let results = try await groupedByPublisherPipeline.execute()
  /// // results.documents might be:
  /// // [
  /// //   ["publisher": "Penguin", "book_count": 50],
  /// //   ["publisher": "HarperCollins", "book_count": 35]
  /// // ]
  /// ```
  ///
  /// - Parameters:
  ///   - accumulator: An array of `AggregateWithAlias` expressions.
  ///   - groups: An optional array of `String` field names for grouping.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func aggregate(_ accumulator: [AggregateWithAlias],
                        groups: [String]? = nil) -> Pipeline {
    let selectables = groups?.map { Field($0) }
    return Pipeline(
      stages: stages + [Aggregate(accumulators: accumulator, groups: selectables)],
      db: db
    )
  }

  /// Performs a vector similarity search, ordering results by similarity.
  ///
  /// Returns up to `limit` documents, from most to least similar based on vector embeddings.
  /// The distance can optionally be included in a specified field.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume pipeline from a collection with vector embeddings.
  /// let queryVector: [Double] = [0.1, 0.2, ..., 0.8] // Example query vector.
  /// let nearestNeighborsPipeline = pipeline.findNearest(
  ///   field: Field("embedding_field"),       // Field containing the vector.
  ///   vectorValue: queryVector,              // Query vector for comparison.
  ///   distanceMeasure: .COSINE,              // Distance metric.
  ///   limit: 10,                             // Return top 10 nearest neighbors.
  ///   distanceField: "similarityScore"       // Optional: field for distance score.
  /// )
  /// // let results = try await nearestNeighborsPipeline.execute()
  /// ```
  ///
  /// - Parameters:
  ///   - field: The `Field` containing vector embeddings.
  ///   - vectorValue: An array of `Double` representing the query vector.
  ///   - distanceMeasure: The `DistanceMeasure` (e.g., `.EUCLIDEAN`, `.COSINE`) for comparison.
  ///   - limit: Optional. Maximum number of similar documents to return.
  ///   - distanceField: Optional. Name for a new field to store the calculated distance.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func findNearest(field: Field,
                          vectorValue: [Double],
                          distanceMeasure: DistanceMeasure,
                          limit: Int? = nil,
                          distanceField: String? = nil) -> Pipeline {
    return Pipeline(
      stages: stages + [
        FindNearest(
          field: field,
          vectorValue: vectorValue,
          distanceMeasure: distanceMeasure,
          limit: limit,
          distanceField: distanceField
        ),
      ],
      db: db
    )
  }

  /// Sorts documents from previous stages based on one or more `Ordering` criteria.
  ///
  /// Specify multiple `Ordering` instances for multi-field sorting (ascending/descending).
  /// If documents are equal by one criterion, the next is used. If all are equal,
  /// relative order is unspecified.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// // Sort books by rating (descending), then by title (ascending).
  /// let sortedPipeline = pipeline.sort(
  ///   Ascending("rating"),
  ///   Descending("title")  // or Field("title").ascending() for ascending.
  /// )
  /// // let results = try await sortedPipeline.execute()
  /// ```
  ///
  /// - Parameter ordering: The primary `Ordering` criterion.
  /// - Parameter additionalOrdering: Optional additional `Ordering` criteria for secondary sorting,
  /// etc.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func sort(_ ordering: Ordering, _ additionalOrdering: Ordering...) -> Pipeline {
    let orderings = [ordering] + additionalOrdering
    return Pipeline(stages: stages + [Sort(orderings: orderings)], db: db)
  }

  /// Fully overwrites document fields with those from a nested map identified by an `Expr`.
  ///
  /// "Promotes" a map value (dictionary) from a field to become the new root document.
  /// Each key-value pair from the map specified by `expr` becomes a field-value pair
  /// in the output document, discarding original document fields.
  ///
  /// ```swift
  /// // Assume input document:
  /// // { "id": "user123", "profile": { "name": "Alex", "age": 30 }, "status": "active" }
  /// // let pipeline: Pipeline = ...
  ///
  /// // Replace document with the contents of the 'profile' map.
  /// let replacedPipeline = pipeline.replace(with: Field("profile"))
  ///
  /// // let results = try await replacedPipeline.execute()
  /// // Output document would be: { "name": "Alex", "age": 30 }
  /// ```
  ///
  /// - Parameter expr: The `Expr` (typically a `Field`) that resolves to the nested map.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func replace(with expr: Expr) -> Pipeline {
    return Pipeline(stages: stages + [ReplaceWith(expr: expr)], db: db)
  }

  /// Fully overwrites document fields with those from a nested map identified by a field name.
  ///
  /// "Promotes" a map value (dictionary) from a field to become the new root document.
  /// Each key-value pair from the map in `fieldName` becomes a field-value pair
  /// in the output document, discarding original document fields.
  ///
  /// ```swift
  /// // Assume input document:
  /// // { "id": "user123", "details": { "role": "admin", "department": "tech" }, "joined":
  /// "2023-01-15" }
  /// // let pipeline: Pipeline = ...
  ///
  /// // Replace document with the contents of the 'details' map.
  /// let replacedPipeline = pipeline.replace(with: "details")
  ///
  /// // let results = try await replacedPipeline.execute()
  /// // Output document would be: { "role": "admin", "department": "tech" }
  /// ```
  ///
  /// - Parameter fieldName: The name of the field containing the nested map.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func replace(with fieldName: String) -> Pipeline {
    return Pipeline(stages: stages + [ReplaceWith(expr: Field(fieldName))], db: db)
  }

  /// Performs pseudo-random sampling of input documents, returning a specific count.
  ///
  /// Filters documents pseudo-randomly. `count` specifies the approximate number
  /// to return. The actual number may vary and isn't guaranteed if the input set
  /// is smaller than `count`.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume pipeline from a large collection.
  /// // Sample 25 books, if available.
  /// let sampledPipeline = pipeline.sample(count: 25)
  /// // let results = try await sampledPipeline.execute()
  /// ```
  ///
  /// - Parameter count: The target number of documents to sample (a `Int64` value).
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func sample(count: Int64) -> Pipeline {
    return Pipeline(stages: stages + [Sample(count: count)], db: db)
  }

  /// Performs pseudo-random sampling of input documents, returning a percentage.
  ///
  /// Filters documents pseudo-randomly. `percentage` (0.0 to 1.0) specifies
  /// the approximate fraction of documents to return from the input set.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// // Sample 50% of books.
  /// let sampledPipeline = pipeline.sample(percentage: 0.5)
  /// // let results = try await sampledPipeline.execute()
  /// ```
  ///
  /// - Parameter percentage: The percentage of documents to sample (e.g., 0.5 for 50%; a `Double`
  /// value).
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func sample(percentage: Double) -> Pipeline {
    return Pipeline(stages: stages + [Sample(percentage: percentage)], db: db)
  }

  /// Performs a union of all documents from this pipeline and another, including duplicates.
  ///
  /// Passes through documents from this pipeline's previous stage and also those from
  /// the `other` pipeline's previous stage. The order of emitted documents is undefined.
  /// Both pipelines should ideally have compatible document structures.
  ///
  /// ```swift
  /// // let db: Firestore = ...
  /// // let booksPipeline = db.collection("books").pipeline().select("title", "category")
  /// // let magazinesPipeline = db.collection("magazines").pipeline().select("title",
  /// Field("topic").as("category"))
  ///
  /// // Emit documents from both "books" and "magazines" collections.
  /// let combinedPipeline = booksPipeline.union(magazinesPipeline)
  /// // let results = try await combinedPipeline.execute()
  /// ```
  ///
  /// - Parameter other: The other `Pipeline` whose documents will be unioned.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func union(_ other: Pipeline) -> Pipeline {
    return Pipeline(stages: stages + [Union(other: other)], db: db)
  }

  /// Takes an array field from input documents and outputs a new document for each element.
  ///
  /// For each input document, this stage emits zero or more augmented documents based on
  /// an array field specified by `field` (a `Selectable`). The `Selectable` for `field`
  /// **must** have an alias; this alias becomes the field name in the output document
  /// containing the unnested element.
  ///
  /// The original field containing the array is effectively replaced by the array element
  /// under the new alias name in each output document. Other fields from the original document
  /// are typically preserved.
  ///
  /// If `indexField` is provided, a new field with this name is added, containing the
  /// zero-based index of the element within its original array.
  ///
  /// Behavior for non-array values or empty arrays depends on the backend.
  ///
  /// ```swift
  /// // Assume input document:
  /// // { "title": "The Hitchhiker's Guide", "authors": ["Douglas Adams", "Eoin Colfer"] }
  /// // let pipeline: Pipeline = ...
  ///
  /// // Unnest 'authors'. Each author becomes a new document with the author in a "authorName"
  /// field.
  /// let unnestedPipeline = pipeline.unnest(Field("authors").as("authorName"), indexField:
  /// "authorIndex")
  ///
  /// // let results = try await unnestedPipeline.execute()
  /// // Possible Output (other fields like "title" are preserved):
  /// // { "title": "The Hitchhiker's Guide", "authorName": "Douglas Adams", "authorIndex": 0 }
  /// // { "title": "The Hitchhiker's Guide", "authorName": "Eoin Colfer", "authorIndex": 1 }
  /// ```
  ///
  /// - Parameters:
  ///   - field: A `Selectable` resolving to an array field. **Must include an alias**
  ///            (e.g., `Field("myArray").as("arrayElement")`) to name the output field.
  ///   - indexField: Optional. If provided, this string names a new field for the element's
  ///                 zero-based index from the original array.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func unnest(_ field: Selectable, indexField: String? = nil) -> Pipeline {
    return Pipeline(stages: stages + [Unnest(field: field, indexField: indexField)], db: db)
  }

  /// Adds a generic stage to the pipeline by specifying its name and parameters.
  ///
  /// Use this to call backend-supported stages not yet strongly-typed in the SDK.
  /// This method does not offer compile-time type safety for stage parameters;
  /// the caller must ensure correct name, order, and types.
  ///
  /// Parameters in `params` and `options` are typically primitive types, `Field`,
  /// `Function`, `Expr`, or arrays/dictionaries thereof.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ...
  /// // Example: Assuming a hypothetical backend stage "customFilterV2".
  /// let genericPipeline = pipeline.rawStage(
  ///   name: "customFilterV2",
  ///   params: [Field("userScore"), 80], // Ordered parameters.
  ///   options: ["mode": "strict", "logLevel": 2]  // Optional named parameters.
  /// )
  /// // let results = try await genericPipeline.execute()
  /// ```
  ///
  /// - Parameters:
  ///   - name: The unique name of the stage (as recognized by the backend).
  ///   - params: An array of ordered, `Sendable` parameters for the stage.
  ///   - options: Optional dictionary of named, `Sendable` parameters.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func rawStage(name: String, params: [Sendable],
                       options: [String: Sendable]? = nil) -> Pipeline {
    return Pipeline(
      stages: stages + [RawStage(name: name, params: params, options: options)],
      db: db
    )
  }
}
