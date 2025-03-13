/*
 * Copyright 2025 Google LLC
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

import Foundation

public protocol Expr {
  var bridge: ExprBridge { get }
}

public struct Constant: Expr {
  public var bridge: ExprBridge

  var value: any Numeric
  init(value: any Numeric) {
    self.value = value
    bridge = ConstantBridge(value as! NSNumber)
  }
}

public func constant(_ number: any Numeric) -> Constant {
  return Constant(value: number)
}

public struct Field: Expr {
  public var bridge: ExprBridge

  var name: String
  init(name: String) {
    self.name = name
    bridge = FieldBridge(name)
  }
}

public func field(_ name: String) -> Field {
  return Field(name: name)
}

protocol Function: Expr {
  var name: String { get }
}

public struct FunctionExpr: Function {
  public var bridge: ExprBridge

  var name: String
  private var args: [Expr]

  init(name: String, args: [Expr]) {
    self.name = name
    self.args = args
    bridge = FunctionExprBridge(name: name, args: args.map { $0.bridge })
  }
}

public func eq(_ left: Expr, _ right: Expr) -> FunctionExpr {
  return FunctionExpr(name: "eq", args: [left, right])
}
