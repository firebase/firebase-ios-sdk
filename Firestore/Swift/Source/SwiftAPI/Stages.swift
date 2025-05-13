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
    bridge = WhereStageBridge(expr: (condition as! (Expr & BridgeWrapper)).bridge)
  }
}
