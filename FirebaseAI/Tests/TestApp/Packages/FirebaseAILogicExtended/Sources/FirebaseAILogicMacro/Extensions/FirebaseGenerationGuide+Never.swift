// Copyright 2026 Google LLC
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

import FirebaseAILogic

public extension FirebaseGenerationGuide where Value == [Never] {
  /// - Warning: This overload is only used for macro expansion. Use
  /// ``FirebaseGenerationGuide/minimumCount(_:)->FirebaseGenerationGuide<[Element]>`` instead.
  static func minimumCount(_ count: Int) -> FirebaseGenerationGuide<Value> {
    fatalError("""
    This overload is only used for macro expansion. Use
    `FirebaseGenerationGuide<[Element]>.minimumCount(_ count: Int)` instead.
    """)
  }

  /// - Warning: This overload is only used for macro expansion. Use
  /// ``FirebaseGenerationGuide/maximumCount(_:)->FirebaseGenerationGuide<[Element]>`` instead.
  static func maximumCount(_ count: Int) -> FirebaseGenerationGuide<Value> {
    fatalError("""
    This overload is only used for macro expansion. Use
    `FirebaseGenerationGuide<[Element]>.maximumCount(_ count: Int)` instead.
    """)
  }

  /// - Warning: This overload is only used for macro expansion. Use
  /// ``FirebaseGenerationGuide/count(_:)-(ClosedRange<Int>)->FirebaseGenerationGuide<[Element]>``
  /// instead.
  static func count(_ range: ClosedRange<Int>) -> FirebaseGenerationGuide<Value> {
    fatalError("""
    This overload is only used for macro expansion. Use
    `FirebaseGenerationGuide<[Element]>.count(_ range: ClosedRange<Int>)` instead.
    """)
  }

  /// - Warning: This overload is only used for macro expansion. Use
  /// ``FirebaseGenerationGuide/count(_:)-(Int)->FirebaseGenerationGuide<[Element]>`` instead.
  static func count(_ count: Int) -> FirebaseGenerationGuide<Value> {
    fatalError("""
    This overload is only used for macro expansion. Use
    `FirebaseGenerationGuide<[Element]>count<Element>(_ count: Int)` instead.
    """)
  }
}
