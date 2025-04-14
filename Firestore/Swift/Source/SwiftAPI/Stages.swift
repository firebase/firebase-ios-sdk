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

class Where: Stage {
  var name: String = "where"

  var bridge: StageBridge
  private var condition: BooleanExpr

  init(condition: BooleanExpr) {
    self.condition = condition
    bridge = WhereStageBridge(expr: condition.exprToExprBridge())
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
      let seletable = field as! SelectableInternal
      result[seletable.alias] = seletable.expr.exprToExprBridge()
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
  private var selections: [Any]

  init(selections: [Any]) {
    self.selections = selections
    let objc_selections = Helper.selectablesToMap(selectables: selections)
    bridge = SelectStageBridge(selections: objc_selections
      .mapValues { Helper.sendableToExpr($0).exprToExprBridge() })
  }
}

class Distinct: Stage {
  var name: String = "distinct"
  var bridge: StageBridge
  private var groups: [Any]

  init(groups: [Any]) {
    self.groups = groups
    let objc_groups = Helper.selectablesToMap(selectables: groups)
    bridge = DistinctStageBridge(groups: objc_groups
      .mapValues { Helper.sendableToExpr($0).exprToExprBridge() })
  }
}

class Aggregate: Stage {
  var name: String = "aggregate"
  var bridge: StageBridge
  private var accumulators: [AggregateWithAlias]
  private var groups: [String: Expr] = [:]

  init(accumulators: [AggregateWithAlias], groups: [Any]?) {
    self.accumulators = accumulators
    if groups != nil {
      self.groups = Helper.selectablesToMap(selectables: groups!)
    }
    let objc_accumulators = accumulators
      .reduce(into: [String: AggregateFunctionBridge]()) { result, accumulator in
        result[accumulator.alias] = accumulator.aggregate.bridge
      }
    bridge = AggregateStageBridge(
      accumulators: objc_accumulators,
      groups: self.groups.mapValues { Helper.sendableToExpr($0).exprToExprBridge() }
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
  private var expr: Expr?
  private var fieldName: String?

  init(expr: Expr) {
    self.expr = expr
    fieldName = nil
    bridge = ReplaceWithStageBridge(expr: expr.exprToExprBridge())
  }

  init(fieldName: String) {
    self.fieldName = fieldName
    expr = nil
    bridge = ReplaceWithStageBridge(fieldName: fieldName)
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
      field: Helper.sendableToExpr(field).exprToExprBridge(),
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
    let bridgeParams = params.map { Helper.sendableToExpr($0).exprToExprBridge() }
    let bridgeOptions = options?.mapValues { Helper.sendableToExpr($0).exprToExprBridge() }
    bridge = GenericStageBridge(name: name, params: bridgeParams, options: bridgeOptions)
  }
}
