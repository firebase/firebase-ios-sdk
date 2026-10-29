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

/// Represents an aggregate function in a pipeline.
///
/// An `AggregateFunction` is a function that computes a single value from a set of input values.
///
/// `AggregateFunction`s are typically used in the `aggregate` stage of a pipeline.
public class AggregateFunction: AggregateBridgeWrapper, @unchecked Sendable {
  let bridge: __AggregateFunctionBridge

  let functionName: String
  let args: [Expression]

  /// The error message associated with this aggregate function or its arguments, if any.
  var errorMessage: String? {
    let errors = args.compactMap { $0.errorMessage }
    return errors.isEmpty ? nil : errors.joined(separator: "\n")
  }

  /// Creates a new `AggregateFunction`.
  ///
  /// - Parameters:
  ///   - functionName: The name of the aggregate function.
  ///   - args: The arguments to the aggregate function.
  public init(functionName: String, args: [Expression]) {
    self.functionName = functionName
    self.args = args
    bridge = __AggregateFunctionBridge(
      name: functionName,
      args: self.args.map { $0.toBridge() },
      window: nil
    )
  }

  /// **[Public Preview]** Applies a window frame to this aggregate, evaluating it over the
  /// specified window frame independent of the frame declared on the enclosing `addWindowFields`
  /// stage.
  ///
  /// - Note: Only `documents` or `range` window frames are supported on individual accumulators
  ///   (using `WindowSpec.documents(...)` or `WindowSpec.range(...)`). Specifying other window
  ///   parameters, such as `partition` or `sort`, is not supported here and must be specified
  ///   on the enclosing `addWindowFields` stage.
  ///
  /// > Warning: Window Functions SDK features are in preview until the backend feature
  /// > launches. Look for launch announcement at:
  /// > https://docs.cloud.google.com/firestore/docs/release-notes
  ///
  /// - Parameter window: The window specification containing the `documents` or `range` frame to evaluate this aggregate over.
  /// - Returns: A new `WindowFunction` with the given window framing.
  public func over(_ window: WindowSpec) -> WindowFunction {
    return WindowFunction(functionName: functionName, args: args, window: window)
  }

  /// Creates an `AliasedAggregate` from this aggregate function.
  ///
  /// - Parameter name: The alias for the aggregate function.
  /// - Returns: An `AliasedAggregate` with the given alias.
  public func `as`(_ name: String) -> AliasedAggregate {
    return AliasedAggregate(aggregate: self, alias: name)
  }
}
