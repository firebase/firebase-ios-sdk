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

import FirebaseFirestoreInternal
import Foundation

protocol Stage {
  var name: String { get }
  var bridge: StageBridge { get }
}

class CollectionSource: Stage {
  var name: String = "collection"

  var bridge: StageBridge
  private var collection: String

  init(collection: String) {
    self.collection = collection
    bridge = CollectionSourceStageBridge(path: collection)
  }
}

class CollectionGroupSource: Stage {
  var name: String = "collectionId"

  var bridge: StageBridge
  private var collectionId: String

  init(collectionId: String) {
    self.collectionId = collectionId
    bridge = CollectionGroupSourceStageBridge(collectionId: collectionId)
  }
}

// Represents the entire database as a source.
class DatabaseSource: Stage {
  var name: String = "database"
  var bridge: StageBridge

  init() {
    bridge = DatabaseSourceStageBridge()
  }
}

// Represents a list of document references as a source.
class DocumentsSource: Stage {
  var name: String = "documents"
  var bridge: StageBridge
  private var references: [String]

  // Initialize with an array of String paths
  init(paths: [String]) {
    references = paths
    bridge = DocumentsSourceStageBridge(documents: paths)
  }
}

// Represents an existing Query as a source.
class QuerySource: Stage {
  var name: String = "query"
  var bridge: StageBridge
  private var query: Query

  init(query: Query) {
    self.query = query
    bridge = DatabaseSourceStageBridge()
    // TODO: bridge = QuerySourceStageBridge(query: query.query)
  }
}

// Represents an existing AggregateQuery as a source.
class AggregateQuerySource: Stage {
  var name: String = "aggregateQuery"
  var bridge: StageBridge
  private var aggregateQuery: AggregateQuery

  init(aggregateQuery: AggregateQuery) {
    self.aggregateQuery = aggregateQuery
    bridge = DatabaseSourceStageBridge()
    // TODO: bridge = AggregateQuerySourceStageBridge(aggregateQuery: aggregateQuery.query)
  }
}

class Where: Stage {
  var name: String = "where"

  var bridge: StageBridge
  private var condition: BooleanExpr

  init(condition: BooleanExpr) {
    self.condition = condition
    bridge = WhereStageBridge(expr: condition.toBridge())
  }
}

class Limit: Stage {
  var name: String = "limit"

  var bridge: StageBridge
  private var limit: Int32

  init(_ limit: Int32) {
    self.limit = limit
    bridge = LimitStageBridge(limit: NSInteger(limit))
  }
}

class Offset: Stage {
  var name: String = "offset"

  var bridge: StageBridge
  private var offset: Int32

  init(_ offset: Int32) {
    self.offset = offset
    bridge = OffsetStageBridge(offset: NSInteger(offset))
  }
}

class AddFields: Stage {
  var name: String = "addFields"
  var bridge: StageBridge
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

class RemoveFieldsStage: Stage {
  var name: String = "removeFields"
  var bridge: StageBridge
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

class Select: Stage {
  var name: String = "select"
  var bridge: StageBridge
  private var selections: [Selectable]

  init(selections: [Selectable]) {
    self.selections = selections
    let map = Helper.selectablesToMap(selectables: selections)
    bridge = SelectStageBridge(selections: map
      .mapValues { Helper.sendableToExpr($0).toBridge() })
  }
}

class Distinct: Stage {
  var name: String = "distinct"
  var bridge: StageBridge
  private var groups: [Selectable]

  init(groups: [Selectable]) {
    self.groups = groups
    let map = Helper.selectablesToMap(selectables: groups)
    bridge = DistinctStageBridge(groups: map
      .mapValues { Helper.sendableToExpr($0).toBridge() })
  }
}

class Aggregate: Stage {
  var name: String = "aggregate"
  var bridge: StageBridge
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

class FindNearest: Stage {
  var name: String = "findNearest"
  var bridge: StageBridge
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

class Sort: Stage {
  var name: String = "sort"
  var bridge: StageBridge
  private var orderings: [Ordering]

  init(orderings: [Ordering]) {
    self.orderings = orderings
    bridge = SortStageBridge(orderings: orderings.map { $0.bridge })
  }
}

class ReplaceWith: Stage {
  var name: String = "replaceWith"
  var bridge: StageBridge
  private var expr: Expr

  init(expr: Expr) {
    self.expr = expr
    bridge = ReplaceWithStageBridge(expr: expr.toBridge())
  }
}

class Sample: Stage {
  var name: String = "sample"
  var bridge: StageBridge
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

class Union: Stage {
  var name: String = "union"
  var bridge: StageBridge
  private var other: Pipeline

  init(other: Pipeline) {
    self.other = other
    bridge = UnionStageBridge(other: other.bridge)
  }
}

class Unnest: Stage {
  var name: String = "unnest"
  var bridge: StageBridge
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

class GenericStage: Stage {
  var name: String
  var bridge: StageBridge
  private var params: [Sendable]
  private var options: [String: Sendable]?

  init(name: String, params: [Sendable], options: [String: Sendable]? = nil) {
    self.name = name
    self.params = params
    self.options = options
    let bridgeParams = params.map { Helper.sendableToExpr($0).toBridge() }
    let bridgeOptions = options?.mapValues { Helper.sendableToExpr($0).toBridge() }
    bridge = GenericStageBridge(name: name, params: bridgeParams, options: bridgeOptions)
  }
}
