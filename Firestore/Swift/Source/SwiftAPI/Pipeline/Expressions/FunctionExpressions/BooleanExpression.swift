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

public class BooleanExpression: FunctionExpression, @unchecked Sendable {
  override public init(_ functionName: String, _ agrs: [Expression]) {
    super.init(functionName, agrs)
  }

  public func countIf() -> AggregateFunction {
    return AggregateFunction("count_if", [self])
  }

  public func then(_ thenExpr: Expression, else elseExpr: Expression) -> FunctionExpression {
    return FunctionExpression("cond", [self, thenExpr, elseExpr])
  }

  public static func && (lhs: BooleanExpression,
                         rhs: @autoclosure () throws -> BooleanExpression) rethrows
    -> BooleanExpression {
    try BooleanExpression("and", [lhs, rhs()])
  }

  public static func || (lhs: BooleanExpression,
                         rhs: @autoclosure () throws -> BooleanExpression) rethrows
    -> BooleanExpression {
    try BooleanExpression("or", [lhs, rhs()])
  }

  public static func ^ (lhs: BooleanExpression,
                        rhs: @autoclosure () throws -> BooleanExpression) rethrows
    -> BooleanExpression {
    try BooleanExpression("xor", [lhs, rhs()])
  }

  public static prefix func ! (lhs: BooleanExpression) -> BooleanExpression {
    return BooleanExpression("not", [lhs])
  }
}
