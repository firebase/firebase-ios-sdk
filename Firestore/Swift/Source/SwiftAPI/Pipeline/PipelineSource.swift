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

/// A `PipelineSource` is the entry point for building a Firestore pipeline. It allows you to
/// specify the source of the data for the pipeline, which can be a collection, a collection group,
/// a list of documents, or the entire database.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public struct PipelineSource: @unchecked Sendable {
  let db: Firestore
  let factory: ([Stage], Firestore) -> Pipeline

  init(db: Firestore, factory: @escaping ([Stage], Firestore) -> Pipeline) {
    self.db = db
    self.factory = factory
  }

  /// Specifies a collection as the data source for the pipeline.
  ///
  /// - Parameter path: The path to the collection.
  /// - Returns: A `Pipeline` with the specified collection as its source.
  public func collection(_ path: String) -> Pipeline {
    return factory([CollectionSource(collection: db.collection(path), db: db)], db)
  }

  /// Specifies a collection as the data source for the pipeline.
  ///
  /// - Parameter coll: The `CollectionReference` of the collection.
  /// - Returns: A `Pipeline` with the specified collection as its source.
  public func collection(_ coll: CollectionReference) -> Pipeline {
    return factory([CollectionSource(collection: coll, db: db)], db)
  }

  /// Specifies a collection group as the data source for the pipeline.
  ///
  /// - Parameter collectionId: The ID of the collection group.
  /// - Returns: A `Pipeline` with the specified collection group as its source.
  public func collectionGroup(_ collectionId: String) -> Pipeline {
    return factory(
      [CollectionGroupSource(collectionId: collectionId)],
      db
    )
  }

  /// Specifies the entire database as the data source for the pipeline.
  ///
  /// - Returns: A `Pipeline` with the entire database as its source.
  public func database() -> Pipeline {
    return factory([DatabaseSource()], db)
  }

  /// Specifies a list of documents as the data source for the pipeline.
  ///
  /// - Parameter docs: An array of `DocumentReference` objects.
  /// - Returns: A `Pipeline` with the specified documents as its source.
  public func documents(_ docs: [DocumentReference]) -> Pipeline {
    return factory([DocumentsSource(docs: docs, db: db)], db)
  }

  /// Specifies a list of documents as the data source for the pipeline.
  ///
  /// - Parameter paths: An array of document paths.
  /// - Returns: A `Pipeline` with the specified documents as its source.
  public func documents(_ paths: [String]) -> Pipeline {
    let docs = paths.map { db.document($0) }
    return factory([DocumentsSource(docs: docs, db: db)], db)
  }

  /// Creates a `Pipeline` from an existing `Query`.
  ///
  /// This allows you to convert a standard Firestore query into a pipeline, which can then be
  /// further modified with additional pipeline stages.
  ///
  /// - Parameter query: The `Query` to convert into a pipeline.
  /// - Returns: A `Pipeline` that is equivalent to the given query.
  public func create(from query: Query) -> Pipeline {
    let stageBridges = PipelineBridge.createStageBridges(from: query)
    let stages: [Stage] = stageBridges.map { bridge in
      switch bridge.name {
      case "collection":
        return CollectionSource(
          bridge: bridge as! CollectionSourceStageBridge,
          db: query.firestore
        )
      case "collection_group":
        return CollectionGroupSource(bridge: bridge as! CollectionGroupSourceStageBridge)
      case "documents":
        return DocumentsSource(bridge: bridge as! DocumentsSourceStageBridge, db: query.firestore)
      case "where":
        return Where(bridge: bridge as! WhereStageBridge)
      case "limit":
        return Limit(bridge: bridge as! LimitStageBridge)
      case "sort":
        return Sort(bridge: bridge as! SortStageBridge)
      case "offset":
        return Offset(bridge: bridge as! OffsetStageBridge)
      default:
        fatalError("Unknown stage type \(bridge.name)")
      }
    }
    return factory(stages, db)
  }

  /// Specifies an array of in-memory document dictionaries as the data source for the pipeline.
  ///
  /// Using literal documents as a data source allows constructing pipelines without fetching existing data
  /// from Firestore. This is useful for bulk inserting or upserting predefined records, testing pipelines with
  /// synthetic datasets, or applying transformations to static data.
  ///
  /// Dictionary values can include primitive types (such as `String`, `Int`, `Double`, `Bool`), nested collections,
  /// or Firestore `Expression` objects.
  ///
  /// ```swift
  /// // Example 1: Transform and project literal records
  /// let snapshot = try await db.pipeline()
  ///   .literals([
  ///     ["name": "Alice", "age": 30, "role": "Admin"],
  ///     ["name": "Bob", "age": 25, "role": "User"]
  ///   ])
  ///   .select([Field("name"), Field("role")])
  ///   .execute()
  ///
  /// // Example 2: Bulk insert literal documents into a collection
  /// let insertSnapshot = try await db.pipeline()
  ///   .literals([
  ///     ["id": "user_1", "name": "Charlie", "email": "charlie@example.com"],
  ///     ["id": "user_2", "name": "Dana", "email": "dana@example.com"]
  ///   ])
  ///   .insert(collectionPath: "users", documentIdExpression: Field("id"))
  ///   .execute()
  /// ```
  ///
  /// - Parameter data: An array of dictionaries representing document literals.
  /// - Returns: A `Pipeline` with the specified literal documents as its source.
  public func literals(_ data: [[String: Any]]) -> Pipeline {
    return factory([LiteralsSourceStage(data: data, db: db)], db)
  }

  /// Specifies in-memory document dictionaries as variadic arguments for the pipeline data source.
  ///
  /// Using literal documents as a data source allows constructing pipelines without fetching existing data
  /// from Firestore. This is useful for bulk inserting or upserting predefined records, testing pipelines with
  /// synthetic datasets, or applying transformations to static data.
  ///
  /// Dictionary values can include primitive types (such as `String`, `Int`, `Double`, `Bool`), nested collections,
  /// or Firestore `Expression` objects.
  ///
  /// ```swift
  /// // Example 1: Execute literals containing expressions
  /// let snapshot = try await db.pipeline()
  ///   .literals(
  ///     ["id": "doc_1", "baseValue": 10, "doubled": Expression.constant(20)]
  ///   )
  ///   .execute()
  ///
  /// // Example 2: Bulk upsert variadic literal records into a collection
  /// let upsertSnapshot = try await db.pipeline()
  ///   .literals(
  ///     ["id": "user_1", "status": "Active"],
  ///     ["id": "user_2", "status": "Pending"]
  ///   )
  ///   .upsert(
  ///     [Field("status").as("accountStatus")],
  ///     collectionPath: "users",
  ///     documentIdExpression: Field("id")
  ///   )
  ///   .execute()
  /// ```
  ///
  /// - Parameter data: Variadic dictionary arguments representing document literals.
  /// - Returns: A `Pipeline` with the specified literal documents as its source.
  public func literals(_ data: [String: Any]...) -> Pipeline {
    return literals(data)
  }
}
