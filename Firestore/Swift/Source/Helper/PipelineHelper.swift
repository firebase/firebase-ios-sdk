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

import Foundation

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

  static func errorMessage(for expr: Expression) -> String? {
    if let funcExpr = expr as? FunctionExpression {
      return funcExpr.errorMessage
    } else if let pipelineExpr = expr as? PipelineExpression {
      return pipelineExpr.errorMessage
    } else if let boolFuncExpr = expr as? BooleanFunctionExpression {
      return boolFuncExpr.errorMessage
    }
    return nil
  }

  static func validateLiteralsValue(_ value: Sendable?, fieldPath: String) -> [String] {
    guard let value else {
      return []
    }
    if let fieldValue = value as? FieldValue {
      let methodName = (fieldValue.value(forKey: "methodName") as? String) ?? "FieldValue"
      return [
        "Function literals() called with invalid data. \(methodName) can only be used with update() and set() (found in field \(fieldPath))",
      ]
    } else if let dict = value as? [String: Sendable?] {
      var errors: [String] = []
      for (key, nestedVal) in dict {
        let nestedPath = fieldPath.isEmpty ? key : "\(fieldPath).\(key)"
        errors.append(contentsOf: validateLiteralsValue(nestedVal, fieldPath: nestedPath))
      }
      return errors
    } else if let arr = value as? [Sendable?] {
      var errors: [String] = []
      for nestedVal in arr {
        errors.append(contentsOf: validateLiteralsValue(nestedVal, fieldPath: fieldPath))
      }
      return errors
    }
    return []
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
    var errors = [String]()
    for selectable in selectables {
      guard let value = selectable as? SelectableWrapper else {
        fatalError("Selectable class must conform to SelectableWrapper.")
      }
      let alias = value.alias
      if let errorMessage = value.expr.errorMessage {
        errors.append(errorMessage)
      }
      if exprMap[alias] != nil {
        errors.append("Duplicate alias '\(alias)' found in selectables.")
      }
      exprMap[alias] = value.expr
    }
    if !errors.isEmpty {
      return (
        [:],
        NSError(
          domain: "com.google.firebase.firestore",
          code: 3,
          userInfo: [NSLocalizedDescriptionKey: errors.joined(separator: "\n")]
        )
      )
    }
    return (exprMap, nil)
  }

  static func aliasedAggregatesToMap(accumulators: [AliasedAggregate])
    -> ([String: AggregateFunction], Error?) {
    var accumulatorMap = [String: AggregateFunction]()
    var errors = [String]()
    for aliasedAggregate in accumulators {
      let alias = aliasedAggregate.alias
      if let errorMessage = aliasedAggregate.aggregate.errorMessage {
        errors.append(errorMessage)
      }
      if accumulatorMap[alias] != nil {
        errors.append("Duplicate alias '\(alias)' found in accumulators.")
      }
      accumulatorMap[alias] = aliasedAggregate.aggregate
    }
    if !errors.isEmpty {
      return (
        [:],
        NSError(
          domain: "com.google.firebase.firestore",
          code: 3,
          userInfo: [NSLocalizedDescriptionKey: errors.joined(separator: "\n")]
        )
      )
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
