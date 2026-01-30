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
  enum HelperError: Error, LocalizedError {
    case duplicateAlias(String)

    public var errorDescription: String? {
      switch self {
      case let .duplicateAlias(message):
        return message
      }
    }
  }

  static func sendableToExpr(_ value: Sendable?) -> Expression {
    guard let value else {
      return Constant.nil
    }
    switch value {
    case let exprValue as Expression:
      return exprValue
    case let dictionaryValue as [String: Sendable?]:
      return map(dictionaryValue)
    case let arrayValue as [Sendable?]:
      return array(arrayValue)
    case let timeUnitValue as TimeUnit:
      return Constant(timeUnitValue.rawValue)
    default:
      return Constant(value)
    }
  }

  static func selectablesToMap(selectables: [Selectable]) -> ([String: Expression], Error?) {
    var exprMap = [String: Expression]()
    for selectable in selectables {
      guard let value = selectable as? SelectableWrapper else {
        fatalError("Selectable class must conform to SelectableWrapper.")
      }
      let alias = value.alias
      if exprMap.keys.contains(alias) {
        return ([:], HelperError.duplicateAlias("Duplicate alias '\(alias)' found in selectables."))
      }
      exprMap[alias] = value.expr
    }
    return (exprMap, nil)
  }

  static func aliasedAggregatesToMap(accumulators: [AliasedAggregate])
    -> ([String: AggregateFunction], Error?) {
    var accumulatorMap = [String: AggregateFunction]()
    for aliasedAggregate in accumulators {
      let alias = aliasedAggregate.alias
      if accumulatorMap.keys.contains(alias) {
        return (
          [:],
          HelperError.duplicateAlias("Duplicate alias '\(alias)' found in accumulators.")
        )
      }
      accumulatorMap[alias] = aliasedAggregate.aggregate
    }
    return (accumulatorMap, nil)
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
    guard let value, !(value is NSNull) else {
      return Constant.nil.bridge
    }
    switch value {
    case let exprValue as Expression:
      return exprValue.toBridge()
    case let aggregateFunctionValue as AggregateFunction:
      return aggregateFunctionValue.bridge
    case let dictionaryValue as [String: Sendable?]:
      let mappedValue: [String: Sendable] = dictionaryValue.mapValues {
        if let aggFunc = $0 as? AggregateFunction {
          return aggFunc.bridge
        }
        return sendableToExpr($0).toBridge()
      }
      return mappedValue as NSDictionary
    default:
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
