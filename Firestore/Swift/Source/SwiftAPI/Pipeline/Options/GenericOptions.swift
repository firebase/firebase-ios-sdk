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

/// A container for providing arbitrary, backend-specific options to a pipeline.
///
/// Use this to pass options that are not explicitly defined in the other option structs.
public struct CustomOptions: OptionProtocol {
  var values: [String: Sendable]
  /// Creates a set of custom options from a dictionary.
  /// - Parameter values: A dictionary containing the custom options.
  public init(_ values: [String: Sendable] = [:]) {
    self.values = values
  }
}
