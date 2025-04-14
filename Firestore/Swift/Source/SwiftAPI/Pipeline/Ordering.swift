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
  let expr: Expr
  let direction: Direction
  var bridge: OrderingBridge

  init(expr: Expr, direction: Direction) {
    self.expr = expr
    self.direction = direction
    bridge = OrderingBridge(expr: expr.exprToExprBridge(), direction: direction.rawValue)
  }
}

public struct Direction: Sendable, Equatable, Hashable {
  let kind: Kind
  let rawValue: String

  enum Kind: String {
    case ascending
    case descending
  }

  public static var ascending: Direction {
    return self.init(kind: .ascending, rawValue: "ascending")
  }

  public static var descending: Direction {
    return self.init(kind: .descending, rawValue: "descending")
  }

  init(kind: Kind, rawValue: String) {
    self.kind = kind
    self.rawValue = rawValue
  }
}
