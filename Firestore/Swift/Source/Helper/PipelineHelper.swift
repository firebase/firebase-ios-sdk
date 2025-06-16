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
  static func sendableToExpr(_ value: Sendable?) -> Expr {
    guard let value = value else {
      return Constant.nil
    }

    if value is Expr {
      return value as! Expr
    } else if value is [String: Sendable?] {
      return map(value as! [String: Sendable?])
    } else if value is [Sendable?] {
      return array(value as! [Sendable?])
    } else {
      return Constant(value)
    }
  }

  static func selectablesToMap(selectables: [Selectable]) -> [String: Expr] {
    let exprMap = selectables.reduce(into: [String: Expr]()) { result, selectable in
      let value = selectable as! SelectableWrapper
      result[value.alias] = value.expr
    }
    return exprMap
  }

  static func map(_ elements: [String: Sendable?]) -> FunctionExpr {
    var result: [Expr] = []
    for (key, value) in elements {
      result.append(Constant(key))
      result.append(sendableToExpr(value))
    }
    return FunctionExpr("map", result)
  }

  static func array(_ elements: [Sendable?]) -> FunctionExpr {
    let transformedElements = elements.map { element in
      sendableToExpr(element)
    }
    return FunctionExpr("array", transformedElements)
  }

  // This function is used to convert Swift type into Objective-C type.
  static func sendableToAnyObjectForRawStage(_ value: Sendable?) -> AnyObject {
    guard let value = value else {
      return Constant.nil.bridge
    }

    // Step 2: Check for NSNull.
    guard !(value is NSNull) else {
      return Constant.nil.bridge
    }

    if value is Expr {
      return (value as! Expr).toBridge()
    } else if value is AggregateFunction {
      return (value as! AggregateFunction).toBridge()
    } else if value is [String: Sendable?] {
      let mappedValue = (value as! [String: Sendable?]).mapValues { sendableToExpr($0).toBridge() }
      return mappedValue as NSDictionary
    } else {
      return Constant(value).bridge
    }
  }
}
