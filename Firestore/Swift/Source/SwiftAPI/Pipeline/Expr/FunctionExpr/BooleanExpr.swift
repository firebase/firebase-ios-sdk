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

public class BooleanExpr: FunctionExpr, @unchecked Sendable {
  override public init(_ functionName: String, _ agrs: [Expr]) {
    super.init(functionName, agrs)
  }

  public static func && (lhs: BooleanExpr,
                         rhs: @autoclosure () throws -> BooleanExpr) rethrows -> BooleanExpr {
    try BooleanExpr("and", [lhs, rhs()])
  }

  public static func || (lhs: BooleanExpr,
                         rhs: @autoclosure () throws -> BooleanExpr) rethrows -> BooleanExpr {
    try BooleanExpr("or", [lhs, rhs()])
  }

  public static prefix func ! (lhs: BooleanExpr) -> BooleanExpr {
    return BooleanExpr("not", [lhs])
  }
}
