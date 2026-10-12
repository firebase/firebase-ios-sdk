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

protocol Stage {
  var name: String { get }
  var bridge: __StageBridge { get }
  /// The `errorMessage` defaults to `nil`. Errors during stage construction are captured and thrown
  /// later when `execute()` is called.
  var errorMessage: String? { get }
}

extension Stage {
  var errorMessage: String? {
    return nil
  }
}

class CollectionSource: Stage {
  let name: String = "collection"

  let bridge: __StageBridge
  private let db: Firestore
  private let forceIndex: String?

  init(collection: CollectionReference, db: Firestore, forceIndex: String? = nil) {
    self.db = db
    self.forceIndex = forceIndex
    bridge = __CollectionSourceStageBridge(ref: collection, firestore: db, forceIndex: forceIndex)
  }

  init(bridge: __CollectionSourceStageBridge, db: Firestore, forceIndex: String? = nil) {
    self.db = db
    self.bridge = bridge
    self.forceIndex = forceIndex
  }
}

class SubcollectionStage: Stage {
  let name: String = "subcollection"
  let bridge: __StageBridge

  init(path: String) {
    bridge = __SubcollectionSourceStageBridge(path: path)
  }
}

class CollectionGroupSource: Stage {
  let name: String = "collection_group"

  let bridge: __StageBridge
  private let forceIndex: String?

  init(collectionId: String, forceIndex: String? = nil) {
    self.forceIndex = forceIndex
    bridge = __CollectionGroupSourceStageBridge(collectionId: collectionId, forceIndex: forceIndex)
  }

  init(bridge: __CollectionGroupSourceStageBridge, forceIndex: String? = nil) {
    self.bridge = bridge
    self.forceIndex = forceIndex
  }
}

// Represents the entire database as a source.
class DatabaseSource: Stage {
  let name: String = "database"
  let bridge: __StageBridge

  init() {
    bridge = __DatabaseSourceStageBridge()
  }

  init(bridge: __DatabaseSourceStageBridge) {
    self.bridge = bridge
  }
}

// Represents a list of document references as a source.
class DocumentsSource: Stage {
  let name: String = "documents"
  let bridge: __StageBridge
  private let db: Firestore

  // Initialize with an array of String paths
  init(docs: [DocumentReference], db: Firestore) {
    self.db = db
    bridge = __DocumentsSourceStageBridge(documents: docs, firestore: db)
  }

  init(bridge: __DocumentsSourceStageBridge, db: Firestore) {
    self.db = db
    self.bridge = bridge
  }
}

class Where: Stage {
  let name: String = "where"

  let bridge: __StageBridge
  private var condition: BooleanExpression?
  let errorMessage: String?

  init(condition: BooleanExpression) {
    self.condition = condition
    bridge = __WhereStageBridge(expr: condition.toBridge())
    errorMessage = condition.errorMessage
  }

  init(bridge: __WhereStageBridge) {
    self.bridge = bridge
    errorMessage = nil
  }
}

class Limit: Stage {
  let name: String = "limit"

  let bridge: __StageBridge

  init(_ limit: Int32) {
    bridge = __LimitStageBridge(limit: NSInteger(limit))
  }

  init(bridge: __LimitStageBridge) {
    self.bridge = bridge
  }
}

class Offset: Stage {
  let name: String = "offset"

  let bridge: __StageBridge

  init(_ offset: Int32) {
    bridge = __OffsetStageBridge(offset: NSInteger(offset))
  }

  init(bridge: __OffsetStageBridge) {
    self.bridge = bridge
  }
}

class AddFields: Stage {
  let name: String = "add_fields"
  let bridge: __StageBridge
  private var selectables: [Selectable]
  let errorMessage: String?

  init(selectables: [Selectable]) {
    self.selectables = selectables
    let (map, error) = Helper.selectablesToMap(selectables: selectables)
    if let error = error {
      errorMessage = error.localizedDescription
      bridge = __AddFieldsStageBridge(fields: [:])
    } else {
      errorMessage = nil
      let objcAccumulators = map.mapValues { $0.toBridge() }
      bridge = __AddFieldsStageBridge(fields: objcAccumulators)
    }
  }
}

class RemoveFieldsStage: Stage {
  let name: String = "remove_fields"
  let bridge: __StageBridge
  private var fields: [String]

  init(fields: [String]) {
    self.fields = fields
    bridge = __RemoveFieldsStageBridge(fields: fields)
  }

  init(fields: [Field]) {
    self.fields = fields.map { $0.fieldName }
    bridge = __RemoveFieldsStageBridge(fields: self.fields)
  }
}

class Define: Stage {
  let name: String = "let"
  let bridge: __StageBridge
  let errorMessage: String?

  init(variables: [Selectable]) {
    let (exprMap, error) = Helper.selectablesToMap(selectables: variables)
    if let error = error {
      errorMessage = error.localizedDescription
      bridge = __DefineStageBridge(variables: [:])
    } else {
      errorMessage = nil
      let bridgeVariables = exprMap.mapValues { $0.toBridge() }
      bridge = __DefineStageBridge(variables: bridgeVariables)
    }
  }
}

class Select: Stage {
  let name: String = "select"
  let bridge: __StageBridge
  let errorMessage: String?

  init(selections: [Selectable]) {
    let (map, error) = Helper.selectablesToMap(selectables: selections)
    if let error = error {
      errorMessage = error.localizedDescription
      bridge = __SelectStageBridge(selections: [:])
    } else {
      errorMessage = nil
      let objcSelections = map.mapValues { Helper.sendableToExpr($0).toBridge() }
      bridge = __SelectStageBridge(selections: objcSelections)
    }
  }
}

class Distinct: Stage {
  let name: String = "distinct"
  let bridge: __StageBridge
  let errorMessage: String?

  init(groups: [Selectable]) {
    let (map, error) = Helper.selectablesToMap(selectables: groups)
    if let error = error {
      errorMessage = error.localizedDescription
      bridge = __DistinctStageBridge(groups: [:])
    } else {
      errorMessage = nil
      let objcGroups = map.mapValues { Helper.sendableToExpr($0).toBridge() }
      bridge = __DistinctStageBridge(groups: objcGroups)
    }
  }
}

class Aggregate: Stage {
  let name: String = "aggregate"
  let bridge: __StageBridge
  private var accumulators: [AliasedAggregate]
  private var groups: [String: Expression] = [:]
  let errorMessage: String?

  init(accumulators: [AliasedAggregate], groups: [Selectable]?) {
    self.accumulators = accumulators

    if let groups = groups {
      let (map, error) = Helper.selectablesToMap(selectables: groups)
      if let error = error {
        errorMessage = error.localizedDescription
        bridge = __AggregateStageBridge(accumulators: [:], groups: [:])
        return
      }
      self.groups = map
    }

    let (accumulatorsMap, error) = Helper.aliasedAggregatesToMap(accumulators: accumulators)
    if let error = error {
      errorMessage = error.localizedDescription
      bridge = __AggregateStageBridge(accumulators: [:], groups: [:])
      return
    }

    errorMessage = nil
    let accumulatorBridgesMap = accumulatorsMap.mapValues { $0.bridge }
    bridge = __AggregateStageBridge(
      accumulators: accumulatorBridgesMap,
      groups: self.groups.mapValues { Helper.sendableToExpr($0).toBridge() }
    )
  }
}

class FindNearest: Stage {
  let name: String = "find_nearest"
  let bridge: __StageBridge
  private var field: Field
  private var vectorValue: VectorValue
  private var distanceMeasure: DistanceMeasure
  private var limit: Int?
  private var distanceField: String?

  init(field: Field,
       vectorValue: VectorValue,
       distanceMeasure: DistanceMeasure,
       limit: Int? = nil,
       distanceField: String? = nil) {
    self.field = field
    self.vectorValue = vectorValue
    self.distanceMeasure = distanceMeasure
    self.limit = limit
    self.distanceField = distanceField
    bridge = __FindNearestStageBridge(
      field: field.bridge as! __FieldBridge,
      vectorValue: vectorValue,
      distanceMeasure: distanceMeasure.kind.rawValue,
      limit: limit as NSNumber?,
      distanceField: distanceField.map { Field($0).toBridge() } ?? nil
    )
  }
}

class Search: Stage {
  let name: String = "search"
  let bridge: __StageBridge
  let errorMessage: String?

  init(query: Expression? = nil,
       languageCode: String? = nil,
       retrievalDepth: Int? = nil,
       sort: [Ordering]? = nil,
       offset: Int? = nil,
       limit: Int? = nil,
       select: [Selectable]? = nil,
       addFields: [Selectable]? = nil,
       queryEnhancement: QueryEnhancement? = nil) {
    // Options represented as a Sendable (e.g. primitive data type or Expression)
    // can be added to this options map. Map and array values will be repsented
    // with the map and array function expressions.
    var options: [String: Sendable] = [:]
    if let query = query {
      options["query"] = query
    }
    if let limit = limit {
      options["limit"] = limit
    }
    if let retrievalDepth = retrievalDepth {
      options["retrieval_depth"] = retrievalDepth
    }
    if let offset = offset {
      options["offset"] = offset
    }
    if let queryEnhancement = queryEnhancement {
      options["query_enhancement"] = queryEnhancement.kind.rawValue
    }
    if let languageCode = languageCode {
      options["language_code"] = languageCode
    }

    // Options represented as an array or map, which should use
    // the map_value or array_value, and not the map or array function,
    // must be managed independently of the options object.

    var errors: [String] = []

    // add_fields is a map_value and map function expression is not supported
    var addFieldsBridge: [String: __ExprBridge] = [:]
    if let addFields = addFields {
      let (map, error) = Helper.selectablesToMap(selectables: addFields)
      if let error = error {
        errors.append(error.localizedDescription)
      } else {
        addFieldsBridge = map.mapValues { $0.toBridge() }
      }
    }

    // select is a map_value and map function expression is not supported
    var selectBridge: [String: __ExprBridge] = [:]
    if let select = select {
      let (map, error) = Helper.selectablesToMap(selectables: select)
      if let error = error {
        errors.append(error.localizedDescription)
      } else {
        selectBridge = map.mapValues { $0.toBridge() }
      }
    }

    if !errors.isEmpty {
      errorMessage = errors.joined(separator: "\n")
      bridge = __SearchStageBridge(options: [:], addFields: [:], select: [:], sort: [])
      return
    }

    // sort is an array_value and array function expression is not supported
    var sortBridge: [__OrderingBridge] = []
    if let sort = sort {
      sortBridge = sort.map { $0.bridge }
    }

    errorMessage = nil
    let bridgeOptions = options.mapValues { Helper.sendableToExpr($0).toBridge() }
    bridge = __SearchStageBridge(
      options: bridgeOptions,
      addFields: addFieldsBridge,
      select: selectBridge,
      sort: sortBridge
    )
  }
}

class Sort: Stage {
  let name: String = "sort"
  let bridge: __StageBridge

  init(orderings: [Ordering]) {
    bridge = __SortStageBridge(orderings: orderings.map { $0.bridge })
  }

  init(bridge: __SortStageBridge) {
    self.bridge = bridge
  }
}

class ReplaceWith: Stage {
  let name: String = "replace_with"
  let bridge: __StageBridge
  private var expr: Expression
  let errorMessage: String?

  init(expr: Expression) {
    self.expr = expr
    bridge = __ReplaceWithStageBridge(expr: expr.toBridge())
    errorMessage = expr.errorMessage
  }
}

class Sample: Stage {
  let name: String = "sample"
  let bridge: __StageBridge
  private var count: Int64?
  private var percentage: Double?

  init(count: Int64) {
    self.count = count
    percentage = nil
    bridge = __SampleStageBridge(count: count)
  }

  init(percentage: Double) {
    self.percentage = percentage
    count = nil
    bridge = __SampleStageBridge(percentage: percentage)
  }
}

class Union: Stage {
  let name: String = "union"
  let bridge: __StageBridge
  private var other: Pipeline

  let errorMessage: String?

  init(other: Pipeline) {
    self.other = other
    bridge = __UnionStageBridge(other: other.pipelineBridge)
    errorMessage = other.errorMessage
  }
}

class Unnest: Stage {
  let name: String = "unnest"
  let bridge: __StageBridge
  private var alias: Expression
  private var field: Expression
  private var indexField: String?
  let errorMessage: String?

  init(field: Selectable, indexField: String? = nil) {
    let seletable = field as! SelectableWrapper
    self.field = seletable.expr
    alias = Field(seletable.alias)
    self.indexField = indexField
    errorMessage = self.field.errorMessage ?? alias.errorMessage

    bridge = __UnnestStageBridge(
      field: self.field.toBridge(),
      alias: alias.toBridge(),
      indexField: indexField.map { Field($0).toBridge() } ?? nil
    )
  }
}

class RawStage: Stage {
  let name: String
  let bridge: __StageBridge
  private var params: [Sendable]
  private var options: [String: Sendable]?
  let errorMessage: String? = nil

  init(name: String, params: [Sendable], options: [String: Sendable]? = nil) {
    self.name = name
    self.params = params
    self.options = options
    let bridgeParams = params.map { Helper.sendableToAnyObjectForRawStage($0) }
    let bridgeOptions = options?.mapValues { Helper.sendableToExpr($0).toBridge() }
    bridge = __RawStageBridge(name: name, params: bridgeParams, options: bridgeOptions)
  }
}
