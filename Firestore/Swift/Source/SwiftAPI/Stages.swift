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
    bridge = WhereStageBridge(expr: condition.bridge)
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
