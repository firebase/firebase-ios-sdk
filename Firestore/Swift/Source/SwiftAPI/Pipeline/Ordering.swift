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

/// An ordering for the documents in a pipeline.
public struct Ordering: @unchecked Sendable {
  /// The expression to order by.
  public let expression: Expression
  /// The direction to order in.
  public let direction: Direction

  let bridge: OrderingBridge

  init(expression: Expression, direction: Direction) {
    self.expression = expression
    self.direction = direction
    bridge = OrderingBridge(expr: expression.toBridge(), direction: direction.rawValue)
  }
}

/// A direction to order results in.
public struct Direction: Sendable, Equatable, Hashable {
  let kind: Kind
  public let rawValue: String

  enum Kind: String {
    case ascending
    case descending
  }

  /// The ascending direction.
  static let ascending = Direction(kind: .ascending, rawValue: "ascending")

  /// The descending direction.
  static let descending = Direction(kind: .descending, rawValue: "descending")

  init(kind: Kind, rawValue: String) {
    self.kind = kind
    self.rawValue = rawValue
  }
}
