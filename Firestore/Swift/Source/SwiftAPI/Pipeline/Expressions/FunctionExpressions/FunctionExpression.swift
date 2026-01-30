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

/// Represents a function call in a pipeline.
///
/// A `FunctionExpression` is an expression that represents a function call with a given name and
/// arguments.
///
/// `FunctionExpression`s are typically used to perform operations on data in a pipeline, such as
/// mathematical calculations, string manipulations, or array operations.
public class FunctionExpression: Expression, BridgeWrapper, @unchecked Sendable {
  let bridge: ExprBridge

  let functionName: String
  let args: [Expression]

  /// Creates a new `FunctionExpression`.
  ///
  /// - Parameters:
  ///   - functionName: The name of the function.
  ///   - args: The arguments to the function.
  public init(functionName: String, args: [Expression]) {
    self.functionName = functionName
    self.args = args
    bridge = FunctionExprBridge(
      name: functionName,
      args: self.args.map { $0.toBridge()
      }
    )
  }
}
