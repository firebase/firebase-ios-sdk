// Copyright 2023 Google LLC
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

import Foundation

import FirebaseFirestore

public extension AggregateQuerySnapshot {

  // MARK: - Optimization #1: Reduce allowed return types.
  // - Create two methods. One that returns `Int?` and one that returns `Double?`.
  // - Removes `Any?` as a possible returned type.
  // - Removes `NSNumber` as a possible returned type.

  func get(_ aggregateField: AggregateField) -> Int? {
    return self.__value(for: aggregateField) as? Int
  }

  func get(_ aggregateField: AggregateField) -> Double? {
    return self.__value(for: aggregateField) as? Double
  }

  // MARK: - Optimization #2: Make snapshot subscriptable.
  // Snapshots are effectively key/value collections, and could be "indexed" into.

  subscript(index: AggregateField) -> Int? {
    return self.__value(for: index) as? Int
  }

  subscript(index: AggregateField) -> Double? {
    return self.__value(for: index) as? Double
  }

}
