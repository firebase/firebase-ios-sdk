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

import Foundation

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
protocol Stage {
  var name: String { get }
  var bridge: StageBridge { get }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class CollectionSource: Stage {
  let name: String = "collection"

  let bridge: StageBridge
  private var collection: CollectionReference
  private let db: Firestore

  init(collection: CollectionReference, db: Firestore) {
    self.collection = collection
    self.db = db
    bridge = CollectionSourceStageBridge(ref: collection, firestore: db)
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class CollectionGroupSource: Stage {
  let name: String = "collectionId"

  let bridge: StageBridge
  private var collectionId: String

  init(collectionId: String) {
    self.collectionId = collectionId
    bridge = CollectionGroupSourceStageBridge(collectionId: collectionId)
  }
}

// Represents the entire database as a source.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class DatabaseSource: Stage {
  let name: String = "database"
  let bridge: StageBridge

  init() {
    bridge = DatabaseSourceStageBridge()
  }
}

// Represents a list of document references as a source.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class DocumentsSource: Stage {
  let name: String = "documents"
  let bridge: StageBridge
  private var docs: [DocumentReference]
  private let db: Firestore

  // Initialize with an array of String paths
  init(docs: [DocumentReference], db: Firestore) {
    self.docs = docs
    self.db = db
    bridge = DocumentsSourceStageBridge(documents: docs, firestore: db)
  }
}

// Represents an existing Query as a source.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class QuerySource: Stage {
  let name: String = "query"
  let bridge: StageBridge
  private var query: Query

  init(query: Query) {
    self.query = query
    bridge = DatabaseSourceStageBridge()
    // TODO: bridge = QuerySourceStageBridge(query: query.query)
  }
}

// Represents an existing AggregateQuery as a source.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AggregateQuerySource: Stage {
  let name: String = "aggregateQuery"
  let bridge: StageBridge
  private var aggregateQuery: AggregateQuery

  init(aggregateQuery: AggregateQuery) {
    self.aggregateQuery = aggregateQuery
    bridge = DatabaseSourceStageBridge()
    // TODO: bridge = AggregateQuerySourceStageBridge(aggregateQuery: aggregateQuery.query)
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class Where: Stage {
  let name: String = "where"

  let bridge: StageBridge
  private var condition: BooleanExpr

  init(condition: BooleanExpr) {
    self.condition = condition
    bridge = WhereStageBridge(expr: condition.toBridge())
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class Limit: Stage {
  let name: String = "limit"

  let bridge: StageBridge
  private var limit: Int32

  init(_ limit: Int32) {
    self.limit = limit
    bridge = LimitStageBridge(limit: NSInteger(limit))
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class Offset: Stage {
  let name: String = "offset"

  let bridge: StageBridge
  private var offset: Int32

  init(_ offset: Int32) {
    self.offset = offset
    bridge = OffsetStageBridge(offset: NSInteger(offset))
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AddFields: Stage {
  let name: String = "addFields"
  let bridge: StageBridge
  private var fields: [Selectable]

  init(fields: [Selectable]) {
    self.fields = fields
    let objc_accumulators = fields.reduce(into: [String: ExprBridge]()) {
      result,
        field
      in
      let seletable = field as! SelectableWrapper
      result[seletable.alias] = seletable.expr.toBridge()
    }
    bridge = AddFieldsStageBridge(fields: objc_accumulators)
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class RemoveFieldsStage: Stage {
  let name: String = "removeFields"
  let bridge: StageBridge
  private var fields: [String]

  init(fields: [String]) {
    self.fields = fields
    bridge = RemoveFieldsStageBridge(fields: fields)
  }

  init(fields: [Field]) {
    self.fields = fields.map { $0.fieldName }
    bridge = RemoveFieldsStageBridge(fields: self.fields)
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class Select: Stage {
  let name: String = "select"
  let bridge: StageBridge
  private var selections: [Selectable]

  init(selections: [Selectable]) {
    self.selections = selections
    let map = Helper.selectablesToMap(selectables: selections)
    bridge = SelectStageBridge(selections: map
      .mapValues { Helper.sendableToExpr($0).toBridge() })
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class Distinct: Stage {
  let name: String = "distinct"
  let bridge: StageBridge
  private var groups: [Selectable]

  init(groups: [Selectable]) {
    self.groups = groups
    let map = Helper.selectablesToMap(selectables: groups)
    bridge = DistinctStageBridge(groups: map
      .mapValues { Helper.sendableToExpr($0).toBridge() })
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class Aggregate: Stage {
  let name: String = "aggregate"
  let bridge: StageBridge
  private var accumulators: [AggregateWithAlias]
  private var groups: [String: Expr] = [:]

  init(accumulators: [AggregateWithAlias], groups: [Selectable]?) {
    self.accumulators = accumulators
    if groups != nil {
      self.groups = Helper.selectablesToMap(selectables: groups!)
    }
    let map = accumulators
      .reduce(into: [String: AggregateFunctionBridge]()) { result, accumulator in
        result[accumulator.alias] = accumulator.aggregate.bridge
      }
    bridge = AggregateStageBridge(
      accumulators: map,
      groups: self.groups.mapValues { Helper.sendableToExpr($0).toBridge() }
    )
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class FindNearest: Stage {
  let name: String = "findNearest"
  let bridge: StageBridge
  private var field: Field
  private var vectorValue: [Double]
  private var distanceMeasure: DistanceMeasure
  private var limit: Int?
  private var distanceField: String?

  init(field: Field,
       vectorValue: [Double],
       distanceMeasure: DistanceMeasure,
       limit: Int? = nil,
       distanceField: String? = nil) {
    self.field = field
    self.vectorValue = vectorValue
    self.distanceMeasure = distanceMeasure
    self.limit = limit
    self.distanceField = distanceField
    bridge = FindNearestStageBridge(
      field: field.bridge as! FieldBridge,
      vectorValue: VectorValue(vectorValue),
      distanceMeasure: distanceMeasure.kind.rawValue,
      limit: limit as NSNumber?,
      distanceField: distanceField
    )
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class Sort: Stage {
  let name: String = "sort"
  let bridge: StageBridge
  private var orderings: [Ordering]

  init(orderings: [Ordering]) {
    self.orderings = orderings
    bridge = SortStageBridge(orderings: orderings.map { $0.bridge })
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class ReplaceWith: Stage {
  let name: String = "replaceWith"
  let bridge: StageBridge
  private var expr: Expr

  init(expr: Expr) {
    self.expr = expr
    bridge = ReplaceWithStageBridge(expr: expr.toBridge())
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class Sample: Stage {
  let name: String = "sample"
  let bridge: StageBridge
  private var count: Int64?
  private var percentage: Double?

  init(count: Int64) {
    self.count = count
    percentage = nil
    bridge = SampleStageBridge(count: count)
  }

  init(percentage: Double) {
    self.percentage = percentage
    count = nil
    bridge = SampleStageBridge(percentage: percentage)
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class Union: Stage {
  let name: String = "union"
  let bridge: StageBridge
  private var other: Pipeline

  init(other: Pipeline) {
    self.other = other
    bridge = UnionStageBridge(other: other.bridge)
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class Unnest: Stage {
  let name: String = "unnest"
  let bridge: StageBridge
  private var field: Selectable
  private var indexField: String?

  init(field: Selectable, indexField: String? = nil) {
    self.field = field
    self.indexField = indexField
    bridge = UnnestStageBridge(
      field: Helper.sendableToExpr(field).toBridge(),
      indexField: indexField
    )
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class RawStage: Stage {
  let name: String
  let bridge: StageBridge
  private var params: [Sendable]
  private var options: [String: Sendable]?

  init(name: String, params: [Sendable], options: [String: Sendable]? = nil) {
    self.name = name
    self.params = params
    self.options = options
    let bridgeParams = params.map { Helper.sendableToExpr($0).toBridge() }
    let bridgeOptions = options?.mapValues { Helper.sendableToExpr($0).toBridge() }
    bridge = RawStageBridge(name: name, params: bridgeParams, options: bridgeOptions)
  }
}
