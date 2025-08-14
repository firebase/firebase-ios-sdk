/*
 * Copyright 2024 Google LLC
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

public class Ordering: @unchecked Sendable {
  let expr: Expression
  let direction: Direction
  let bridge: OrderingBridge

  init(expr: Expression, direction: Direction) {
    self.expr = expr
    self.direction = direction
    bridge = OrderingBridge(expr: expr.toBridge(), direction: direction.rawValue)
  }
}

struct Direction: Sendable, Equatable, Hashable {
  let kind: Kind
  let rawValue: String

  enum Kind: String {
    case ascending
    case descending
  }

  static let ascending = Direction(kind: .ascending, rawValue: "ascending")

  static let descending = Direction(kind: .descending, rawValue: "descending")

  init(kind: Kind, rawValue: String) {
    self.kind = kind
    self.rawValue = rawValue
  }
}
