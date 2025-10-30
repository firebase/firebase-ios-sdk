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
  static func sendableToExpr(_ value: Sendable?) -> Expression {
    guard let value = value else {
      return Constant.nil
    }

    if let exprValue = value as? Expression {
      return exprValue
    } else if let dictionaryValue = value as? [String: Sendable?] {
      return map(dictionaryValue)
    } else if let arrayValue = value as? [Sendable?] {
      return array(arrayValue)
    } else if let timeUnitValue = value as? TimeUnit {
      return Constant(timeUnitValue.rawValue)
    } else {
      return Constant(value)
    }
  }

  static func selectablesToMap(selectables: [Selectable]) -> [String: Expression] {
    let exprMap = selectables.reduce(into: [String: Expression]()) { result, selectable in
      guard let value = selectable as? SelectableWrapper else {
        fatalError("Selectable class must conform to SelectableWrapper.")
      }
      let alias = value.alias
      if result.keys.contains(alias) {
        // TODO: Add tests to verify the behaviour.
        fatalError("Duplicate alias '\(alias)' found in selectables.")
      }
      result[alias] = value.expr
    }
    return exprMap
  }

  static func aliasedAggregatesToMap(accumulators: [AliasedAggregate])
    -> [String: AggregateFunction] {
    let accumulatorMap = accumulators
      .reduce(into: [String: AggregateFunction]()) { result, aliasedAggregate in

        let alias = aliasedAggregate.alias
        if result.keys.contains(alias) {
          // TODO: Add tests to verify the behaviour.
          fatalError("Duplicate alias '\(alias)' found in accumulators.")
        }
        result[alias] = aliasedAggregate.aggregate
      }
    return accumulatorMap
  }

  static func map(_ elements: [String: Sendable?]) -> FunctionExpression {
    var result: [Expression] = []
    for (key, value) in elements {
      result.append(Constant(key))
      result.append(sendableToExpr(value))
    }
    return FunctionExpression(functionName: "map", args: result)
  }

  static func array(_ elements: [Sendable?]) -> FunctionExpression {
    let transformedElements = elements.map { element in
      sendableToExpr(element)
    }
    return FunctionExpression(functionName: "array", args: transformedElements)
  }

  // This function is used to convert Swift type into Objective-C type.
  static func sendableToAnyObjectForRawStage(_ value: Sendable?) -> AnyObject {
    guard let value = value, !(value is NSNull) else {
      return Constant.nil.bridge
    }

    if let exprValue = value as? Expression {
      return exprValue.toBridge()
    } else if let aggregateFunctionValue = value as? AggregateFunction {
      return aggregateFunctionValue.bridge
    } else if let dictionaryValue = value as? [String: Sendable?] {
      let mappedValue: [String: Sendable] = dictionaryValue.mapValues {
        if let aggFunc = $0 as? AggregateFunction {
          return aggFunc.bridge
        }
        return sendableToExpr($0).toBridge()
      }
      return mappedValue as NSDictionary
    } else {
      return Constant(value).bridge
    }
  }

  static func convertObjCToSwift(_ objValue: Sendable) -> Sendable? {
    switch objValue {
    case is NSNull:
      return nil

    default:
      return objValue
    }
  }
}
