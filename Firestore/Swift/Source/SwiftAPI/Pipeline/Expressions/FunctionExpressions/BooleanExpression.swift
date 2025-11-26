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

public protocol BooleanExpression: Expression {}

struct BooleanFunctionExpression: BooleanExpression, BridgeWrapper {
  let expr: FunctionExpression
  public var bridge: ExprBridge { return expr.bridge }

  init(_ expr: FunctionExpression) {
    self.expr = expr
  }

  init(functionName: String, args: [Expression]) {
    expr = FunctionExpression(functionName: functionName, args: args)
  }
}

struct BooleanConstant: BooleanExpression, BridgeWrapper {
  private let constant: Constant
  public var bridge: ExprBridge { return constant.bridge }

  init(_ constant: Constant) {
    self.constant = constant
  }
}

struct BooleanField: BooleanExpression, BridgeWrapper {
  private let field: Field
  public var bridge: ExprBridge { return field.bridge }

  init(_ field: Field) {
    self.field = field
  }
}

public func && (lhs: BooleanExpression,
                rhs: @autoclosure () throws -> BooleanExpression) rethrows -> BooleanExpression {
  return try BooleanFunctionExpression(functionName: "and", args: [lhs, rhs()])
}

public func || (lhs: BooleanExpression,
                rhs: @autoclosure () throws -> BooleanExpression) rethrows -> BooleanExpression {
  return try BooleanFunctionExpression(functionName: "or", args: [lhs, rhs()])
}

public func ^ (lhs: BooleanExpression,
               rhs: @autoclosure () throws -> BooleanExpression) rethrows -> BooleanExpression {
  return try BooleanFunctionExpression(functionName: "xor", args: [lhs, rhs()])
}

public prefix func ! (lhs: BooleanExpression) -> BooleanExpression {
  return BooleanFunctionExpression(functionName: "not", args: [lhs])
}

public extension BooleanExpression {
  func countIf() -> AggregateFunction {
    return AggregateFunction(functionName: "count_if", args: [self])
  }

  func then(_ thenExpression: Expression,
            else elseExpression: Expression) -> FunctionExpression {
    return FunctionExpression(
      functionName: "conditional",
      args: [self, thenExpression, elseExpression]
    )
  }
}
