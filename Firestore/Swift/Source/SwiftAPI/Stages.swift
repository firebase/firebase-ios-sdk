//
//  Stages.swift
//  FirebaseFirestore
//
//  Created by Hui Wu on 2/10/25.
//

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

class Where: Stage {
  var name: String = "where"

  var bridge: StageBridge
  private var condition: Expr // TODO: should be FilterCondition

  init(condition: Expr) {
    self.condition = condition
    bridge = WhereStageBridge(expr: condition.bridge)
  }
}
