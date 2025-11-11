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
  /// The `errorMessage` defaults to `nil`. Errors during stage construction are captured and thrown
  /// later when `execute()` is called.
  var errorMessage: String? { get }
}

extension Stage {
  var errorMessage: String? {
    return nil
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class CollectionSource: Stage {
  let name: String = "collection"

  let bridge: StageBridge
  private let db: Firestore

  init(collection: CollectionReference, db: Firestore) {
    self.db = db
    bridge = CollectionSourceStageBridge(ref: collection, firestore: db)
  }

  init(bridge: CollectionSourceStageBridge, db: Firestore) {
    self.db = db
    self.bridge = bridge
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class CollectionGroupSource: Stage {
  let name: String = "collection_group"

  let bridge: StageBridge

  init(collectionId: String) {
    bridge = CollectionGroupSourceStageBridge(collectionId: collectionId)
  }

  init(bridge: CollectionGroupSourceStageBridge) {
    self.bridge = bridge
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

  init(bridge: DatabaseSourceStageBridge) {
    self.bridge = bridge
  }
}

// Represents a list of document references as a source.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class DocumentsSource: Stage {
  let name: String = "documents"
  let bridge: StageBridge
  private let db: Firestore

  // Initialize with an array of String paths
  init(docs: [DocumentReference], db: Firestore) {
    self.db = db
    bridge = DocumentsSourceStageBridge(documents: docs, firestore: db)
  }

  init(bridge: DocumentsSourceStageBridge, db: Firestore) {
    self.db = db
    self.bridge = bridge
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class Where: Stage {
  let name: String = "where"

  let bridge: StageBridge
  private var condition: BooleanExpression?

  init(condition: BooleanExpression) {
    self.condition = condition
    bridge = WhereStageBridge(expr: condition.toBridge())
  }

  init(bridge: WhereStageBridge) {
    self.bridge = bridge
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class Limit: Stage {
  let name: String = "limit"

  let bridge: StageBridge

  init(_ limit: Int32) {
    bridge = LimitStageBridge(limit: NSInteger(limit))
  }

  init(bridge: LimitStageBridge) {
    self.bridge = bridge
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class Offset: Stage {
  let name: String = "offset"

  let bridge: StageBridge

  init(_ offset: Int32) {
    bridge = OffsetStageBridge(offset: NSInteger(offset))
  }

  init(bridge: OffsetStageBridge) {
    self.bridge = bridge
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AddFields: Stage {
  let name: String = "add_fields"
  let bridge: StageBridge
  private var selectables: [Selectable]
  let errorMessage: String?

  init(selectables: [Selectable]) {
    self.selectables = selectables
    let (map, error) = Helper.selectablesToMap(selectables: selectables)
    if let error = error {
      errorMessage = error.localizedDescription
      bridge = AddFieldsStageBridge(fields: [:])
    } else {
      errorMessage = nil
      let objcAccumulators = map.mapValues { $0.toBridge() }
      bridge = AddFieldsStageBridge(fields: objcAccumulators)
    }
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class RemoveFieldsStage: Stage {
  let name: String = "remove_fields"
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
  let errorMessage: String?

  init(selections: [Selectable]) {
    let (map, error) = Helper.selectablesToMap(selectables: selections)
    if let error = error {
      errorMessage = error.localizedDescription
      bridge = SelectStageBridge(selections: [:])
    } else {
      errorMessage = nil
      let objcSelections = map.mapValues { Helper.sendableToExpr($0).toBridge() }
      bridge = SelectStageBridge(selections: objcSelections)
    }
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class Distinct: Stage {
  let name: String = "distinct"
  let bridge: StageBridge
  let errorMessage: String?

  init(groups: [Selectable]) {
    let (map, error) = Helper.selectablesToMap(selectables: groups)
    if let error = error {
      errorMessage = error.localizedDescription
      bridge = DistinctStageBridge(groups: [:])
    } else {
      errorMessage = nil
      let objcGroups = map.mapValues { Helper.sendableToExpr($0).toBridge() }
      bridge = DistinctStageBridge(groups: objcGroups)
    }
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class Aggregate: Stage {
  let name: String = "aggregate"
  let bridge: StageBridge
  private var accumulators: [AliasedAggregate]
  private var groups: [String: Expression] = [:]
  let errorMessage: String?

  init(accumulators: [AliasedAggregate], groups: [Selectable]?) {
    self.accumulators = accumulators

    if let groups = groups {
      let (map, error) = Helper.selectablesToMap(selectables: groups)
      if let error = error {
        errorMessage = error.localizedDescription
        bridge = AggregateStageBridge(accumulators: [:], groups: [:])
        return
      }
      self.groups = map
    }

    let (accumulatorsMap, error) = Helper.aliasedAggregatesToMap(accumulators: accumulators)
    if let error = error {
      errorMessage = error.localizedDescription
      bridge = AggregateStageBridge(accumulators: [:], groups: [:])
      return
    }

    errorMessage = nil
    let accumulatorBridgesMap = accumulatorsMap.mapValues { $0.bridge }
    bridge = AggregateStageBridge(
      accumulators: accumulatorBridgesMap,
      groups: self.groups.mapValues { Helper.sendableToExpr($0).toBridge() }
    )
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class FindNearest: Stage {
  let name: String = "find_nearest"
  let bridge: StageBridge
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
    bridge = FindNearestStageBridge(
      field: field.bridge as! FieldBridge,
      vectorValue: vectorValue,
      distanceMeasure: distanceMeasure.kind.rawValue,
      limit: limit as NSNumber?,
      distanceField: distanceField.map { Field($0).toBridge() } ?? nil
    )
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class Sort: Stage {
  let name: String = "sort"
  let bridge: StageBridge

  init(orderings: [Ordering]) {
    bridge = SortStageBridge(orderings: orderings.map { $0.bridge })
  }

  init(bridge: SortStageBridge) {
    self.bridge = bridge
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class ReplaceWith: Stage {
  let name: String = "replace_with"
  let bridge: StageBridge
  private var expr: Expression

  init(expr: Expression) {
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
  private var alias: Expression
  private var field: Expression
  private var indexField: String?

  init(field: Selectable, indexField: String? = nil) {
    let seletable = field as! SelectableWrapper
    self.field = seletable.expr
    alias = Field(seletable.alias)
    self.indexField = indexField

    bridge = UnnestStageBridge(
      field: self.field.toBridge(),
      alias: alias.toBridge(),
      indexField: indexField.map { Field($0).toBridge() } ?? nil
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
    let bridgeParams = params.map { Helper.sendableToAnyObjectForRawStage($0) }
    let bridgeOptions = options?.mapValues { Helper.sendableToExpr($0).toBridge() }
    bridge = RawStageBridge(name: name, params: bridgeParams, options: bridgeOptions)
  }
}
