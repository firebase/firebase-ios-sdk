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

#if compiler(>=6.4)
  @testable import FoundationModelsFake

  /// Arguments with a single string property, as `@Generable` would generate them.
  protocol SingleStringArguments: Generable {
    /// The property's name.
    static var propertyName: String { get }

    /// The property's `@Guide` description, if any.
    static var propertyDescription: String? { get }

    /// The property's value.
    var value: String { get }

    /// Creates arguments with the given value.
    ///
    /// - Parameter value: The property's value.
    init(value: String)
  }

  extension SingleStringArguments {
    /// No `@Guide` description by default.
    static var propertyDescription: String? { nil }

    /// An object schema with the single string property.
    static var generationSchema: GenerationSchema {
      GenerationSchema(
        type: Self.self,
        properties: [
          GenerationSchema.Property(
            name: propertyName,
            description: propertyDescription,
            type: String.self
          )
        ]
      )
    }

    /// Reads the single property from generated content.
    ///
    /// - Parameter content: The generated content.
    /// - Throws: An error if the property is missing or isn't a string.
    init(_ content: GeneratedContent) throws {
      self.init(value: try content.value(forProperty: Self.propertyName))
    }

    /// The arguments as generated content.
    var generatedContent: GeneratedContent {
      GeneratedContent(properties: [Self.propertyName: value])
    }
  }
#endif  // compiler(>=6.4)
