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
  let bridge: AggregateFunctionBridge

  let functionName: String
  let args: [Expression]
  let window: WindowSpec?

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
    window = nil
    bridge = AggregateFunctionBridge(
      name: functionName,
      args: self.args.map { $0.toBridge() },
      window: nil
    )
  }

  init(functionName: String, args: [Expression], window: WindowSpec?) {
    self.functionName = functionName
    self.args = args
    self.window = window
    bridge = AggregateFunctionBridge(
      name: functionName,
      args: self.args.map { $0.toBridge() },
      window: window?.toBridge()
    )
  }

  /// Applies a window frame to this aggregate, evaluating it over the specified window frame
  /// independent of the frame declared on the enclosing `addWindowFields` stage.
  ///
  /// - Parameter window: The window specification to evaluate this aggregate over.
  /// - Returns: A new `AggregateFunction` with the given window framing.
  public func over(_ window: WindowSpec) -> AggregateFunction {
    return AggregateFunction(functionName: functionName, args: args, window: window)
  }

  /// Creates an `AliasedAggregate` from this aggregate function.
  ///
  /// - Parameter name: The alias for the aggregate function.
  /// - Returns: An `AliasedAggregate` with the given alias.
  public func `as`(_ name: String) -> AliasedAggregate {
    return AliasedAggregate(aggregate: self, alias: name)
  }
}
