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
/// stage (or the data source) and produces an output for the next stage (or as the final output of
/// the pipeline).
///
/// Expressions can be used within each stage to filter and transform data through the stage.
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
/// let snapshot1 = try await db.pipeline().collection("books")
/// .select(Field("title"), Field("author"), Field("rating").as("bookRating"))
/// .execute()
/// print("Results 1: \(snapshot1.results)")
/// } catch {
/// print("Error in example 1: \(error)")
/// }
///
/// // Example 2: Filter documents where 'genre' is "Science Fiction" and 'published' is after 1950.
/// do {
/// let snapshot2 = try await db.pipeline().collection("books")
/// .where(
/// Field("genre").equal("Science Fiction")
/// && Field("published").greaterThan(1950)
/// )
/// .execute()
/// print("Results 2: \(snapshot2.results)")
/// } catch {
/// print("Error in example 2: \(error)")
/// }
///
/// // Example 3: Calculate the average rating of books published after 1980.
/// do {
/// let snapshot3 = try await db.pipeline().collection("books")
/// .where(Field("published").greaterThan(1980))
/// .aggregate(Field("rating").average().as("averageRating"))
/// .execute()
/// print("Results 3: \(snapshot3.results)")
/// } catch {
/// print("Error in example 3: \(error)")
/// }
/// ```
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public struct Pipeline: @unchecked Sendable {
  private var stages: [Stage]
  let bridge: PipelineBridge
  let db: Firestore

  let errorMessage: String?

  init(stages: [Stage], db: Firestore, errorMessage: String? = nil) {
    self.stages = stages
    self.db = db
    self.errorMessage = errorMessage
    bridge = PipelineBridge(stages: stages.map { $0.bridge }, db: db)
  }

  /// A `Pipeline.Snapshot` contains the results of a pipeline execution.
  public struct Snapshot: Sendable {
    /// An array of all the results in the `Pipeline.Snapshot`.
    public let results: [PipelineResult]

    /// The time at which the pipeline producing this result was executed.
    public let executionTime: Timestamp

    let bridge: __PipelineSnapshotBridge

    init(_ bridge: __PipelineSnapshotBridge) {
      self.bridge = bridge
      executionTime = self.bridge.execution_time
      results = self.bridge.results.map { PipelineResult($0) }
    }
  }

  /// Creates a new `Pipeline` instance in a faulted state.
  ///
  /// This function is used to propagate an error through the pipeline chain. When a stage
  /// fails to initialize or if a preceding stage has already failed, this method is called
  /// to create a new pipeline that holds the error message. The `stages` array is cleared,
  /// and the `errorMessage` is set.
  ///
  /// The stored error is eventually thrown by the `execute()` method.
  ///
  /// - Parameter message: The error message to store in the pipeline.
  /// - Returns: A new `Pipeline` instance with the specified error message.
  private func withError(_ message: String) -> Pipeline {
    return Pipeline(stages: [], db: db, errorMessage: message)
  }

  /// Executes the defined pipeline and returns a `Pipeline.Snapshot` containing the results.
  ///
  /// This method asynchronously sends the pipeline definition to Firestore for execution.
  /// The resulting documents, transformed and filtered by the pipeline stages, are returned
  /// within a `Pipeline.Snapshot`.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume a pipeline is already configured.
  /// do {
  ///   let snapshot = try await pipeline.execute()
  ///   // Process snapshot.results
  ///   print("Pipeline executed successfully: \(snapshot.results)")
  /// } catch {
  ///   print("Pipeline execution failed: \(error)")
  /// }
  /// ```
  ///
  /// - Throws: An error if the pipeline execution fails on the backend.
  /// - Returns: A `Pipeline.Snapshot` containing the result of the pipeline execution.
  public func execute() async throws -> Pipeline.Snapshot {
    // Check if any errors occurred during stage construction.
    if let errorMessage = errorMessage {
      throw NSError(
        domain: "com.google.firebase.firestore",
        code: 3 /* kErrorInvalidArgument */,
        userInfo: [NSLocalizedDescriptionKey: errorMessage]
      )
    }

    return try await withCheckedThrowingContinuation { continuation in
      self.bridge.execute { result, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: Pipeline.Snapshot(result!))
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
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline from a collection.
  /// let updatedPipeline = pipeline.addFields([
  ///   Field("rating").as("bookRating"), // Rename 'rating' to 'bookRating'.
  ///   Field("quantity").add(5).as("totalQuantityPlusFive") // Calculate
  /// // 'totalQuantityPlusFive'.
  /// ])
  /// // let results = try await updatedPipeline.execute()
  /// ```
  ///
  /// - Parameter selectables: An array of at least one `Selectable` to add to the documents.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func addFields(_ selectables: [Selectable]) -> Pipeline {
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let addFieldsStage = AddFields(selectables: selectables)
    if let errorMessage = addFieldsStage.errorMessage {
      return withError(errorMessage)
    }
    return Pipeline(stages: stages + [addFieldsStage], db: db)
  }

  /// Removes fields from outputs of previous stages.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// let updatedPipeline = pipeline.removeFields([Field("confidentialData"),
  /// Field("internalNotes")])
  /// // let results = try await updatedPipeline.execute()
  /// ```
  ///
  /// - Parameter fields: An array of at least one `Field` instance to remove.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func removeFields(_ fields: [Field]) -> Pipeline {
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let stage = RemoveFieldsStage(fields: fields)
    if let errorMessage = stage.errorMessage {
      return withError(errorMessage)
    } else {
      return Pipeline(
        stages: stages + [stage],
        db: db
      )
    }
  }

  /// Removes fields from outputs of previous stages using field names.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// // Removes fields 'rating' and 'cost' from the previous stage outputs.
  /// let updatedPipeline = pipeline.removeFields(["rating", "cost"])
  /// // let results = try await updatedPipeline.execute()
  /// ```
  ///
  /// - Parameter fields: An array of at least one field name to remove.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func removeFields(_ fields: [String]) -> Pipeline {
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let stage = RemoveFieldsStage(fields: fields)
    if let errorMessage = stage.errorMessage {
      return withError(errorMessage)
    } else {
      return Pipeline(
        stages: stages + [stage],
        db: db
      )
    }
  }

  /// Selects or creates a set of fields from the outputs of previous stages.
  ///
  /// The selected fields are defined using `Selectable` expressions, which can be:
  /// - `String`: Name of an existing field (implicitly converted to `Field`).
  /// - `Field`: References an existing field.
  /// - `FunctionExpression`: Represents the result of a function with an assigned alias
  ///   (e.g., `Field("address").toUpper().as("upperAddress")`).
  ///
  /// If no selections are provided, the output of this stage is typically empty.
  /// Use `addFields` if only additions are desired without replacing the existing document
  /// structure.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// let projectedPipeline = pipeline.select([
  ///   Field("firstName"),
  ///   Field("lastName"),
  ///   Field("address").toUpper().as("upperAddress")
  /// ])
  /// // let results = try await projectedPipeline.execute()
  /// ```
  ///
  /// - Parameter selections: An array of at least one `Selectable` expression to include in the
  /// output documents.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func select(_ selections: [Selectable]) -> Pipeline {
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let selectStage = Select(selections: selections)
    if let errorMessage = selectStage.errorMessage {
      return withError(errorMessage)
    }
    return Pipeline(stages: stages + [selectStage], db: db)
  }

  /// Selects a set of fields from the outputs of previous stages using field names.
  ///
  /// The selected fields are specified by their names. If no selections are provided,
  /// the output of this stage is typically empty. Use `addFields` if only additions are desired.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// let projectedPipeline = pipeline.select(["title", "author", "yearPublished"])
  /// // let results = try await projectedPipeline.execute()
  /// ```
  ///
  /// - Parameter selections: An array of at least one field name to include in the output
  /// documents.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func select(_ selections: [String]) -> Pipeline {
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let selections = selections.map { Field($0) }
    let stage = Select(selections: selections)
    if let errorMessage = stage.errorMessage {
      return withError(errorMessage)
    } else {
      return Pipeline(
        stages: stages + [stage],
        db: db
      )
    }
  }

  /// Filters documents from previous stages, including only those matching the specified
  /// `BooleanExpression`.
  ///
  /// This stage applies conditions similar to a "WHERE" clause in SQL.
  /// Filter documents based on field values using `BooleanExpression` implementations, such as:
  /// - Field comparators: `equal`, `lessThan`, `greaterThan`.
  /// - Logical operators: `&&` (and), `||` (or), `!` (not).
  /// - Advanced functions: `regexMatch`, `arrayContains`.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// let filteredPipeline = pipeline.where(
  ///     Field("rating").greaterThan(4.0)   // Rating greater than 4.0.
  ///     && Field("genre").equal("Science Fiction") // Genre is "Science Fiction".
  /// )
  /// // let results = try await filteredPipeline.execute()
  /// ```
  ///
  /// - Parameter condition: The `BooleanExpression` to apply.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func `where`(_ condition: BooleanExpression) -> Pipeline {
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let stage = Where(condition: condition)
    if let errorMessage = stage.errorMessage {
      return withError(errorMessage)
    } else {
      return Pipeline(stages: stages + [stage], db: db)
    }
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
  ///                     .sort(Field("published").ascending()) // Example sort.
  ///                     .offset(20)  // Skip the first 20 results.
  ///                     .limit(20)   // Take the next 20 results.
  /// // let results = try await pagedPipeline.execute()
  /// ```
  ///
  /// - Parameter offset: The number of documents to skip (a `Int32` value).
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func offset(_ offset: Int32) -> Pipeline {
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let stage = Offset(offset)
    if let errorMessage = stage.errorMessage {
      return withError(errorMessage)
    } else {
      return Pipeline(stages: stages + [stage], db: db)
    }
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
  ///                      .sort([Field("rating").descending()])
  ///                      .limit(10)
  /// // let results = try await topTenPipeline.execute()
  /// ```
  ///
  /// - Parameter limit: The maximum number of documents to return (a `Int32` value).
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func limit(_ limit: Int32) -> Pipeline {
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let stage = Limit(limit)
    if let errorMessage = stage.errorMessage {
      return withError(errorMessage)
    } else {
      return Pipeline(stages: stages + [stage], db: db)
    }
  }

  /// Returns a set of distinct documents based on specified grouping field names.
  ///
  /// This stage ensures that only unique combinations of values for the specified
  /// group fields are included from the previous stage's output.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// // Get a list of unique author and genre combinations.
  /// let distinctAuthorsGenresPipeline = pipeline.distinct(["author", "genre"])
  /// // To further select only the author:
  /// //   .select("author")
  /// // let results = try await distinctAuthorsGenresPipeline.execute()
  /// ```
  ///
  /// - Parameter groups: An array of at least one field name for distinct value combinations.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func distinct(_ groups: [String]) -> Pipeline {
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let selections = groups.map { Field($0) }
    let stage = Distinct(groups: selections)
    if let errorMessage = stage.errorMessage {
      return withError(errorMessage)
    } else {
      return Pipeline(stages: stages + [stage], db: db)
    }
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
  ///   Field("author").toUpper().as("authorName"),
  ///   Field("genre")
  /// )
  /// // To select only the transformed author name:
  /// //   .select(Field("authorName"))
  /// // let results = try await distinctPipeline.execute()
  /// ```
  ///
  /// - Parameter groups: An array of at least one `Selectable` expression to consider.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func distinct(_ groups: [Selectable]) -> Pipeline {
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let distinctStage = Distinct(groups: groups)
    if let errorMessage = distinctStage.errorMessage {
      return withError(errorMessage)
    }
    return Pipeline(stages: stages + [distinctStage], db: db)
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
  ///   [Field("rating").average().as("avg_rating")],
  ///   groups: [Field("genre")] // Group by the "genre" field.
  /// )
  /// // let results = try await groupedAggregationPipeline.execute()
  /// // snapshot.results might be:
  /// // [
  /// //   ["genre": "SciFi", "avg_rating": 4.5],
  /// //   ["genre": "Fantasy", "avg_rating": 4.2]
  /// // ]
  /// ```
  ///
  /// - Parameters:
  ///   - aggregates: An array of at least one `AliasedAggregate` expression for calculations.
  ///   - groups: Optional array of `Selectable` expressions for grouping. If `nil` or empty,
  /// aggregates across all documents.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func aggregate(_ aggregates: [AliasedAggregate],
                        groups: [Selectable]? = nil) -> Pipeline {
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let aggregateStage = Aggregate(accumulators: aggregates, groups: groups)
    if let errorMessage = aggregateStage.errorMessage {
      return withError(errorMessage)
    }
    return Pipeline(stages: stages + [aggregateStage], db: db)
  }

  /// Performs a vector similarity search, ordering results by similarity.
  ///
  /// Returns up to `limit` documents, from most to least similar based on vector embeddings.
  /// The distance can optionally be included in a specified field.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume pipeline from a collection with vector embeddings.
  /// let queryVector = VectorValue([0.1, 0.2, ..., 0.8]) // Example query vector.
  /// let nearestNeighborsPipeline = pipeline.findNearest(
  ///   field: Field("embedding_field"),       // Field containing the vector.
  ///   vectorValue: queryVector,              // Query vector for comparison.
  ///   distanceMeasure: .cosine,              // Distance metric.
  ///   limit: 10,                             // Return top 10 nearest neighbors.
  ///   distanceField: "similarityScore"       // Optional: field for distance score.
  /// )
  /// // let results = try await nearestNeighborsPipeline.execute()
  /// ```
  ///
  /// - Parameters:
  ///   - field: The `Field` containing vector embeddings.
  ///   - vectorValue: A `VectorValue` instance representing the query vector.
  ///   - distanceMeasure: The `DistanceMeasure` (e.g., `.euclidean`, `.cosine`) for comparison.
  ///   - limit: Optional. Maximum number of similar documents to return.
  ///   - distanceField: Optional. Name for a new field to store the calculated distance.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func findNearest(field: Field,
                          vectorValue: VectorValue,
                          distanceMeasure: DistanceMeasure,
                          limit: Int? = nil,
                          distanceField: String? = nil) -> Pipeline {
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let stage = FindNearest(
      field: field,
      vectorValue: vectorValue,
      distanceMeasure: distanceMeasure,
      limit: limit,
      distanceField: distanceField
    )
    if let errorMessage = stage.errorMessage {
      return withError(errorMessage)
    } else {
      return Pipeline(stages: stages + [stage], db: db)
    }
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
  /// let sortedPipeline = pipeline.sort([
  ///   Field("rating").descending(),
  ///   Field("title").ascending()
  /// ])
  /// // let results = try await sortedPipeline.execute()
  /// ```
  ///
  /// - Parameter orderings: An array of at least one `Ordering` criterion.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func sort(_ orderings: [Ordering]) -> Pipeline {
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let stage = Sort(orderings: orderings)
    if let errorMessage = stage.errorMessage {
      return withError(errorMessage)
    } else {
      return Pipeline(stages: stages + [stage], db: db)
    }
  }

  /// Fully overwrites document fields with those from a nested map identified by an `Expr`.
  ///
  /// "Promotes" a map value (dictionary) from a field to become the new root document.
  /// Each key-value pair from the map specified by `expression` becomes a field-value pair
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
  /// - Parameter expression: The `Expr` (typically a `Field`) that resolves to the nested map.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func replace(with expression: Expression) -> Pipeline {
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let stage = ReplaceWith(expr: expression)
    if let errorMessage = stage.errorMessage {
      return withError(errorMessage)
    } else {
      return Pipeline(stages: stages + [stage], db: db)
    }
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
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let stage = ReplaceWith(expr: Field(fieldName))
    if let errorMessage = stage.errorMessage {
      return withError(errorMessage)
    } else {
      return Pipeline(stages: stages + [stage], db: db)
    }
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
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let stage = Sample(count: count)
    if let errorMessage = stage.errorMessage {
      return withError(errorMessage)
    } else {
      return Pipeline(stages: stages + [stage], db: db)
    }
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
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let stage = Sample(percentage: percentage)
    if let errorMessage = stage.errorMessage {
      return withError(errorMessage)
    } else {
      return Pipeline(stages: stages + [stage], db: db)
    }
  }

  /// Performs a union of all documents from this pipeline and another, including duplicates.
  ///
  /// Passes through documents from this pipeline's previous stage and also those from
  /// the `other` pipeline's previous stage. The order of emitted documents is undefined.
  /// Both pipelines should ideally have compatible document structures.
  ///
  /// ```swift
  /// // let db: Firestore = ...
  /// // let booksPipeline = db.pipeline().collection("books").select(["title", "category"])
  /// // let magazinesPipeline = db.pipeline().collection("magazines").select(["title",
  /// // Field("topic").as("category")])
  ///
  /// // Emit documents from both "books" and "magazines" collections.
  /// let combinedPipeline = booksPipeline.union(with: magazinesPipeline)
  /// // let results = try await combinedPipeline.execute()
  /// ```
  ///
  /// - Parameter other: Another `Pipeline` whose documents will be unioned.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func union(with other: Pipeline) -> Pipeline {
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let stage = Union(other: other)
    if let errorMessage = stage.errorMessage {
      return withError(errorMessage)
    } else {
      return Pipeline(stages: stages + [stage], db: db)
    }
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
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let stage = Unnest(field: field, indexField: indexField)
    if let errorMessage = stage.errorMessage {
      return withError(errorMessage)
    } else {
      return Pipeline(stages: stages + [stage], db: db)
    }
  }

  /// Adds a generic stage to the pipeline by specifying its name and parameters.
  ///
  /// Use this to call backend-supported stages not yet strongly-typed in the SDK.
  /// This method does not offer compile-time type safety for stage parameters;
  /// the caller must ensure correct name, order, and types.
  ///
  /// Parameters in `params` and `options` are typically primitive types, `Field`,
  /// `Function`, `Expression`, or arrays/dictionaries thereof.
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
    if let errorMessage = errorMessage {
      return withError(errorMessage)
    }
    let stage = RawStage(name: name, params: params, options: options)
    if let errorMessage = stage.errorMessage {
      return withError(errorMessage)
    } else {
      return Pipeline(stages: stages + [stage], db: db)
    }
  }
}
