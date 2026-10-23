// Copyright 2026 Google LLC
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

/// A function that is evaluated over a window of documents in an `addWindowFields` stage.
///
/// Create a `WindowFunction` with a dedicated window function such as `Rank()`, or by calling
/// `over(_:)` on an `AggregateFunction`.
public class WindowFunction: AggregateBridgeWrapper, @unchecked Sendable {
  let bridge: __AggregateFunctionBridge

  let functionName: String
  let args: [Expression]
  let window: WindowSpec?

  /// The error message associated with this window function or its arguments, if any.
  var errorMessage: String? {
    let errors = args.compactMap { $0.errorMessage }
    return errors.isEmpty ? nil : errors.joined(separator: "\n")
  }

  init(functionName: String, args: [Expression], window: WindowSpec? = nil) {
    self.functionName = functionName
    self.args = args
    self.window = window
    bridge = __AggregateFunctionBridge(
      name: functionName,
      args: args.map { $0.toBridge() },
      window: window?.toBridge()
    )
  }

  /// Applies a window frame to this window function, evaluating it over the specified window frame
  /// independent of the frame declared on the enclosing `addWindowFields` stage.
  ///
  /// - Note: Only `documents` or `range` window frames are supported on individual accumulators
  ///   (using `WindowSpec.documents(...)` or `WindowSpec.range(...)`). Specifying other window
  ///   parameters, such as `partition` or `sort`, is not supported here and must be specified
  ///   on the enclosing `addWindowFields` stage.
  ///
  /// - Parameter window: The window specification containing the `documents` or `range` frame to evaluate this window function over.
  /// - Returns: A new `WindowFunction` with the given window framing.
  public func over(_ window: WindowSpec) -> WindowFunction {
    return WindowFunction(functionName: functionName, args: args, window: window)
  }

  /// Creates an `AliasedWindowFunction` from this window function.
  ///
  /// - Parameter name: The name of the output field that will contain the result.
  /// - Returns: An `AliasedWindowFunction` with the given alias.
  public func `as`(_ name: String) -> AliasedWindowFunction {
    return AliasedWindowFunction(windowFunction: self, alias: name)
  }
}
