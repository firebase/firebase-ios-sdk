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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public struct Pipeline: @unchecked Sendable {
  private var stages: [Stage]
  var bridge: PipelineBridge
  let db: Firestore

  init(stages: [Stage], db: Firestore) {
    self.stages = stages
    self.db = db
    bridge = PipelineBridge(stages: stages.map { $0.bridge }, db: db)
  }

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
  /// stages or constants. You can use this to create new fields or overwrite existing ones.
  ///
  /// The added fields are defined using `Selectable`s, which can be:
  ///
  /// - `Field`: References an existing document field.
  /// - `Function`: Performs a calculation using functions like `add`, `multiply` with
  ///   assigned aliases using `Expr.as`.
  ///
  /// - Parameter fields: The fields to add to the documents, specified as `Selectable`s.
  /// - Returns: A new `Pipeline` object with this stage appended to the stage list.
  public func addFields(_ field: Selectable, _ additionalFields: Selectable...) -> Pipeline {
    let fields = [field] + additionalFields
    return Pipeline(stages: stages + [AddFields(fields: fields)], db: db)
  }

  /// Remove fields from outputs of previous stages.
  /// - Parameter fields: The fields to remove.
  /// - Returns: A new Pipeline object with this stage appended to the stage list.
  public func removeFields(_ field: Field, _ additionalFields: Field...) -> Pipeline {
    return Pipeline(
      stages: stages + [RemoveFieldsStage(fields: [field] + additionalFields)],
      db: db
    )
  }

  /// Remove fields from outputs of previous stages.
  /// - Parameter fields: The fields to remove.
  /// - Returns: A new Pipeline object with this stage appended to the stage list.
  public func removeFields(_ field: String, _ additionalFields: String...) -> Pipeline {
    return Pipeline(
      stages: stages + [RemoveFieldsStage(fields: [field] + additionalFields)],
      db: db
    )
  }

  /// Selects or creates a set of fields from the outputs of previous stages.
  ///
  /// The selected fields are defined using `Selectable` expressions, which can be:
  ///
  /// - `String`: Name of an existing field.
  /// - `Field`: References an existing field.
  /// - `Function`: Represents the result of a function with an assigned alias name using `Expr#as`.
  ///
  /// If no selections are provided, the output of this stage is empty. Use `addFields` instead if
  /// only additions are desired.
  ///
  /// - Parameter selections: The fields to include in the output documents, specified as
  /// `Selectable` expressions.
  /// - Returns: A new `Pipeline` object with this stage appended to the stage list.
  public func select(_ selection: Selectable, _ additionalSelections: Selectable...) -> Pipeline {
    let selections = [selection] + additionalSelections
    return Pipeline(
      stages: stages + [Select(selections: selections + additionalSelections)],
      db: db
    )
  }

  /// Selects or creates a set of fields from the outputs of previous stages.
  ///
  /// The selected fields are defined using `Selectable` expressions, which can be:
  ///
  /// - `String`: Name of an existing field.
  /// - `Field`: References an existing field.
  /// - `Function`: Represents the result of a function with an assigned alias name using `Expr#as`.
  ///
  /// If no selections are provided, the output of this stage is empty. Use `addFields` instead if
  /// only additions are desired.
  ///
  /// - Parameter selections: `String` values representing field names.
  /// - Returns: A new `Pipeline` object with this stage appended to the stage list.
  public func select(_ selection: String, _ additionalSelections: String...) -> Pipeline {
    let selections = ([selection] + additionalSelections).map { Field($0) }
    return Pipeline(
      stages: stages + [Select(selections: selections)],
      db: db
    )
  }

  /// Filters the documents from previous stages to only include those matching the specified
  /// `BooleanExpr`.
  ///
  /// This stage allows you to apply conditions to the data, similar to a "WHERE" clause
  /// in SQL.
  /// You can filter documents based on their field values, using implementations of
  /// `BooleanExpr`, typically including but not limited to:
  ///
  /// - field comparators: `Function.eq`, `Function.lt` (less than), `Function.gt` (greater than),
  /// etc.
  /// - logical operators: `Function.and`, `Function.or`, `Function.not`,
  /// etc.
  /// - advanced functions: `Function.regexMatch`, `Function.arrayContains`, etc.
  ///
  /// - Parameter condition: The `BooleanExpr` to apply.
  /// - Returns: A new `Pipeline` object with this stage appended to the stage list.
  public func `where`(_ condition: BooleanExpr) -> Pipeline {
    return Pipeline(stages: stages + [Where(condition: condition)], db: db)
  }

  /// Skips the first `offset` number of documents from the results of previous stages.
  /// The negative input number will count back from the result set.
  ///
  /// This stage is useful for implementing pagination in your pipelines, allowing you to
  /// retrieve results in chunks. It is typically used in conjunction with `limit` to control the
  /// size of each page.
  ///
  /// - Parameter offset: The number of documents to skip.
  /// - Returns: A new `Pipeline` object with this stage appended to the stage list.
  public func offset(_ offset: Int32) -> Pipeline {
    return Pipeline(stages: stages + [Offset(offset)], db: db)
  }

  /// Limits the maximum number of documents returned by previous stages to `limit`.
  /// The negative input number will count back from the result set.
  ///
  /// This stage is particularly useful when you want to retrieve a controlled
  /// subset of data from a potentially large result set. It's often used for:
  ///
  /// - **Pagination:** In combination with `skip` to retrieve specific pages of results.
  /// - **Limiting Data Retrieval:** To prevent excessive data transfer and improve
  /// performance, especially when dealing with large collections.
  ///
  /// - Parameter limit: The maximum number of documents to return.
  /// - Returns: A new `Pipeline` object with this stage appended to the stage list.
  public func limit(_ limit: Int32) -> Pipeline {
    return Pipeline(stages: stages + [Limit(limit)], db: db)
  }

  /// Returns a set of distinct `Expr` values from the inputs to this stage.
  ///
  /// This stage processes the results from previous stages, ensuring that only unique
  /// combinations of `Expr` values (such as `Field` and `Function`) are included.
  ///
  /// The parameters to this stage are defined using `Selectable` expressions or field names:
  ///
  /// - `String`: The name of an existing field.
  /// - `Field`: A reference to an existing document field.
  /// - `Function`: Represents the result of a function with an assigned alias using
  /// `Expr.alias(_:)`.
  ///
  /// - Parameter selections: The fields to include in the output documents, specified as
  ///  `String` values representing field names.
  public func distinct(_ group: String, _ additionalGroups: String...) -> Pipeline {
    let selections = ([group] + additionalGroups).map { Field($0) }
    return Pipeline(stages: stages + [Distinct(groups: selections)], db: db)
  }

  /// Returns a set of distinct `Expr` values from the inputs to this stage.
  ///
  /// This stage processes the results from previous stages, ensuring that only unique
  /// combinations of `Expr` values (such as `Field` and `Function`) are included.
  ///
  /// The parameters to this stage are defined using `Selectable` expressions or field names:
  ///
  /// - `String`: The name of an existing field.
  /// - `Field`: A reference to an existing document field.
  /// - `Function`: Represents the result of a function with an assigned alias using
  /// `Expr.alias(_:)`.
  ///
  /// - Parameter selections: The fields to include in the output documents, specified as
  /// `Selectable` expressions.
  public func distinct(_ group: Selectable, _ additionalGroups: Selectable...) -> Pipeline {
    let groups = [group] + additionalGroups
    return Pipeline(stages: stages + [Distinct(groups: groups + additionalGroups)], db: db)
  }

  /// Performs aggregation operations on the documents from previous stages.
  ///
  /// This stage allows you to compute aggregate values over a set of documents.
  /// Aggregations are defined using `AccumulatorWithAlias`, which wraps an `Accumulator`
  /// and provides a name for the accumulated results. These expressions are typically
  /// created by calling `alias(_:)` on `Accumulator` instances.
  ///
  /// - Parameter accumulators: The `AccumulatorWithAlias` expressions, each wrapping an
  ///   `Accumulator` and assigning a name to the accumulated results.
  public func aggregate(_ accumulator: AggregateWithAlias,
                        _ additionalAccumulators: AggregateWithAlias...) -> Pipeline {
    return Pipeline(
      stages: stages + [Aggregate(
        accumulators: [accumulator] + additionalAccumulators,
        groups: nil
      )],
      db: db
    )
  }

  /// Performs optionally grouped aggregation operations on the documents from previous stages.
  ///
  /// This stage calculates aggregate values over a set of documents, optionally grouped by
  /// one or more fields or computed expressions.
  ///
  /// - **Grouping Fields or Expressions:** Defines how documents are grouped. For each
  ///   unique combination of values in the specified fields or expressions, a separate group
  ///   is created. If no grouping fields are provided, all documents are placed into a single
  ///   group.
  /// - **Accumulators:** Defines the accumulation operations to perform within each group.
  ///   These are provided as `AccumulatorWithAlias` expressions, typically created by
  ///   calling `alias(_:)` on `Accumulator` instances. Each aggregation computes a
  ///   value (e.g., sum, average, count) based on the documents in its group.
  ///
  /// - Parameters:
  ///   - accumulators: A list of `AccumulatorWithAlias` expressions defining the aggregation
  /// calculations.
  ///   - groups: An optional list of grouping fields or expressions.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func aggregate(_ accumulator: [AggregateWithAlias],
                        groups: [Selectable]? = nil) -> Pipeline {
    return Pipeline(stages: stages + [Aggregate(accumulators: accumulator, groups: groups)], db: db)
  }

  /// Performs optionally grouped aggregation operations on the documents from previous stages.
  ///
  /// This stage calculates aggregate values over a set of documents, optionally grouped by
  /// one or more fields or computed expressions.
  ///
  /// - **Grouping Fields or Expressions:** Defines how documents are grouped. For each
  ///   unique combination of values in the specified fields or expressions, a separate group
  ///   is created. If no grouping fields are provided, all documents are placed into a single
  ///   group.
  /// - **Accumulators:** Defines the accumulation operations to perform within each group.
  ///   These are provided as `AccumulatorWithAlias` expressions, typically created by
  ///   calling `alias(_:)` on `Accumulator` instances. Each aggregation computes a
  ///   value (e.g., sum, average, count) based on the documents in its group.
  ///
  /// - Parameters:
  ///   - accumulators: A list of `AccumulatorWithAlias` expressions defining the aggregation
  /// calculations.
  ///   - groups: An optional list of grouping field names.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func aggregate(_ accumulator: [AggregateWithAlias],
                        groups: [String]? = nil) -> Pipeline {
    let selectables = groups?.map { Field($0) }
    return Pipeline(
      stages: stages + [Aggregate(accumulators: accumulator, groups: selectables)],
      db: db
    )
  }

  /// Performs a vector similarity search, ordering the result set by most similar to least
  /// similar, and returning the first N documents in the result set.
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

  /// Sorts the documents from previous stages based on one or more `Ordering` criteria.
  ///
  /// This stage allows you to order the results of your pipeline. You can specify multiple
  /// `Ordering` instances to sort by multiple fields in ascending or descending order.
  /// If documents have the same value for a field used for sorting, the next specified ordering
  /// will be used. If all orderings result in equal comparison, the documents are considered
  /// equal and the order is unspecified.
  ///
  /// - Parameter orderings: One or more `Ordering` instances specifying the sorting criteria.
  /// - Returns: A new `Pipeline` object with this stage appended to the stage list.
  public func sort(_ ordering: Ordering, _ additionalOrdering: Ordering...) -> Pipeline {
    let orderings = [ordering] + additionalOrdering
    return Pipeline(stages: stages + [Sort(orderings: orderings)], db: db)
  }

  /// Fully overwrites all fields in a document with those coming from a nested map.
  ///
  /// This stage allows you to emit a map value as a document. Each key of the map becomes a
  /// field on the document that contains the corresponding value.
  ///
  /// - Parameter field: The `Expr` field containing the nested map.
  /// - Returns: A new `Pipeline` object with this stage appended to the stage list.
  public func replace(with expr: Expr) -> Pipeline {
    return Pipeline(stages: stages + [ReplaceWith(expr: expr)], db: db)
  }

  /// Fully overwrites all fields in a document with those coming from a nested map.
  ///
  /// This stage allows you to emit a map value as a document. Each key of the map becomes a
  /// field on the document that contains the corresponding value.
  ///
  /// - Parameter fieldName: The field containing the nested map.
  /// - Returns: A new `Pipeline` object with this stage appended to the stage list.
  public func replace(with fieldName: String) -> Pipeline {
    return Pipeline(stages: stages + [ReplaceWith(fieldName: fieldName)], db: db)
  }

  /// Performs a pseudo-random sampling of the input documents.
  ///
  /// This stage will filter documents pseudo-randomly. The parameter specifies how number of
  /// documents to be returned.
  ///
  /// - Parameter count: The number of documents to sample.
  /// - Returns: A new `Pipeline` object with this stage appended to the stage list.
  public func sample(count: Int64) -> Pipeline {
    return Pipeline(stages: stages + [Sample(count: count)], db: db)
  }

  /// Performs a pseudo-random sampling of the input documents.
  ///
  /// This stage will filter documents pseudo-randomly. The `options` parameter specifies how
  /// sampling will be performed. See `SampleOptions` for more information.
  ///
  /// - Parameter percentage: The percentage of documents to sample.
  /// - Returns: A new `Pipeline` object with this stage appended to the stage list.
  public func sample(percentage: Double) -> Pipeline {
    return Pipeline(stages: stages + [Sample(percentage: percentage)], db: db)
  }

  /// Performs union of all documents from two pipelines, including duplicates.
  ///
  /// This stage will pass through documents from previous stage, and also pass through documents
  /// from previous stage of the `other` Pipeline given in parameter. The order of documents
  /// emitted from this stage is undefined.
  ///
  /// - Parameter other: The other `Pipeline` that is part of union.
  /// - Returns: A new `Pipeline` object with this stage appended to the stage list.
  public func union(_ other: Pipeline) -> Pipeline {
    return Pipeline(stages: stages + [Union(other: other)], db: db)
  }

  /// Takes an array field from the input documents and outputs a document for each element
  /// with the array field mapped to the alias provided.
  ///
  /// For each previous stage document, this stage will emit zero or more augmented documents.
  /// The input array found in the previous stage document field specified by the `fieldName`
  /// parameter, will for each input array element produce an augmented document. The input array
  /// element will augment the previous stage document by replacing the field specified by
  /// `fieldName` parameter with the element value.
  ///
  /// In other words, the field containing the input array will be removed from the augmented
  /// document and replaced by the corresponding array element.
  ///
  /// - Parameter field: The name of the field containing the array.
  /// - Parameter indexField: Optional.
  /// - Returns: A new `Pipeline` object with this stage appended to the stage list.
  public func unnest(_ field: Selectable, indexField: String? = nil) -> Pipeline {
    return Pipeline(stages: stages + [Unnest(field: field, indexField: indexField)], db: db)
  }

  /// Adds a stage to the pipeline by specifying the stage name as an argument. This does
  /// not offer any type safety on the stage params and requires the caller to know the
  /// order (and optionally names) of parameters accepted by the stage.
  ///
  /// This method provides a way to call stages that are supported by the Firestore backend
  /// but that are not implemented in the SDK version being used.
  ///
  /// - Parameter name: The unique name of the stage to add.
  /// - Parameter params: A list of ordered parameters to configure the stage's behavior.
  /// - Parameter options: A list of optional, named parameters to configure the stage's behavior.
  /// - Returns: A new `Pipeline` object with this stage appended to the stage list.
  public func genericStage(name: String, params: [Sendable],
                           options: [String: Sendable]? = nil) -> Pipeline {
    return Pipeline(
      stages: stages + [GenericStage(name: name, params: params, options: options)],
      db: db
    )
  }
}
