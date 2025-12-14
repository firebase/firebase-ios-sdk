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

/// A type that can be converted to model output.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public protocol ConvertibleToModelOutput {
  /// This instance represented as model output.
  ///
  /// Conformance to this protocol is provided by the `@Generable` macro. A manual implementation
  /// may be used to map values onto properties using different names. Use the `modelOutput`
  /// property as shown below, to manually return a new ``ModelOutput`` with the properties
  /// you specify.
  ///
  /// ```swift
  /// struct Person: ConvertibleToModelOutput {
  ///    var name: String
  ///    var age: Int
  ///
  ///    var modelOutput: ModelOutput {
  ///        ModelOutput(properties: [
  ///            "firstName": name,
  ///            "ageInYears": age
  ///        ])
  ///    }
  /// }
  /// ```
  ///
  /// - Important: If your type also conforms to ``ConvertibleFromModelOutput``, it is
  /// critical that this implementation be symmetrical with
  /// ``ConvertibleFromModelOutput/init(_:)``.
  var modelOutput: ModelOutput { get }
}
