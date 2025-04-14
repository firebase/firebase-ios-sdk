// Copyright 2025 Google LLC
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

enum Helper {
  static func sendableToExpr(_ value: Sendable) -> Expr {
    if value is Expr {
      return value as! Expr
    } else if value is [String: Sendable] {
      return map(value as! [String: Sendable])
    } else if value is [Sendable] {
      return array(value as! [Sendable])
    } else {
      return Constant(value)
    }
  }

  static func selectablesToMap(selectables: [Any]) -> [String: Expr] {
    var result = [String: Expr]()
    for selectable in selectables {
      if let stringSelectable = selectable as? String {
        result[stringSelectable] = Field(stringSelectable)
      } else if let fieldSelectable = selectable as? Field {
        result[fieldSelectable.alias] = fieldSelectable.expr
      } else if let exprAliasSelectable = selectable as? ExprWithAlias {
        result[exprAliasSelectable.alias] = exprAliasSelectable.expr
      }
    }
    return result
  }

  static func vectorToExpr(_ value: VectorValue) -> Expr {
    return Field("PLACEHOLDER")
  }

  static func timeUnitToExpr(_ value: TimeUnit) -> Expr {
    return Field("PLACEHOLDER")
  }

  static func map(_ elements: [String: Sendable]) -> FunctionExpr {
    var result: [Expr] = []
    for (key, value) in elements {
      result.append(Constant(key))
      result.append(sendableToExpr(value))
    }
    return FunctionExpr("map", result)
  }

  static func array(_ elements: [Sendable]) -> FunctionExpr {
    let transformedElements = elements.map { element in
      sendableToExpr(element)
    }
    return FunctionExpr("array", transformedElements)
  }
}
