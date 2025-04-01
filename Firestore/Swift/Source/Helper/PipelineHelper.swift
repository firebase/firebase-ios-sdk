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
  static func valueToDefaultExpr(_ value: Any) -> any Expr {
    if value is Expr {
      return value as! Expr
    } else if value is [String: Any] {
      return map(value as! [String: Any])
    } else if value is [Any] {
      return array(value as! [Any])
    } else {
      return Constant(value)
    }
  }

  static func vectorToExpr(_ value: VectorValue) -> any Expr {
    return Field("PLACEHOLDER")
  }

  static func timeUnitToExpr(_ value: TimeUnit) -> any Expr {
    return Field("PLACEHOLDER")
  }

  static func map(_ elements: [String: Any]) -> FunctionExpr {
    var result: [Expr] = []
    for (key, value) in elements {
      result.append(Constant(key))
      result.append(valueToDefaultExpr(value))
    }
    return FunctionExpr("map", result)
  }

  static func array(_ elements: [Any]) -> FunctionExpr {
    let transformedElements = elements.map { element in
      valueToDefaultExpr(element)
    }
    return FunctionExpr("array", transformedElements)
  }
}
