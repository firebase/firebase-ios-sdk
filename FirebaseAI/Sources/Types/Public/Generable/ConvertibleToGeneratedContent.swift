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

/// A type that can be converted to generated content.
public protocol ConvertibleToGeneratedContent {
  /// This instance represented as generated content.
  ///
  /// Conformance to this protocol is provided by the `@Generable` macro. A manual implementation
  /// may be used to map values onto properties using different names. Use the generated content
  /// property as shown below, to manually return a new ``GeneratedContent`` with the properties
  /// you specify.
  ///
  /// ```swift
  /// struct Person: ConvertibleToGeneratedContent {
  ///    var name: String
  ///    var age: Int
  ///
  ///    var generatedContent: GeneratedContent {
  ///        GeneratedContent(properties: [
  ///            "firstName": name,
  ///            "ageInYears": age
  ///        ])
  ///    }
  /// }
  /// ```
  ///
  /// - Important: If your type also conforms to ``ConvertibleFromGeneratedContent``, it is
  /// critical that this implementation be symmetrical with
  /// ``ConvertibleFromGeneratedContent/init(_:)``.
  var generatedContent: GeneratedContent { get }
}
