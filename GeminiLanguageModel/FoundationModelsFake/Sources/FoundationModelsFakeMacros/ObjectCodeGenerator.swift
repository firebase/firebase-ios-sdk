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

import SwiftSyntax

/// Generates the `Generable` members of a struct-like type: a `@Generable` struct, or a
/// `Discriminated*` helper struct of an enum with associated values.
struct ObjectCodeGenerator {
  /// The access modifier repeated on generated members.
  var access: GeneratedAccess

  /// The `name:` argument of `@Generable(name:)`, if any.
  var name: ExprSyntax?

  /// The type description.
  var description: ExprSyntax?

  /// The `representNilExplicitlyInGeneratedContent:` argument, if any.
  var representNilExplicitly: ExprSyntax?

  /// The stored properties, in declaration order.
  var properties: [GenerableProperty]

  /// The `Equatable`/`Hashable` conformances that `PartiallyGenerated` repeats.
  var equatableConformances: [String]

  /// The properties that appear in the schema and in generated content.
  private var schemaProperties: [GenerableProperty] {
    properties.filter { !$0.isGenerationID }
  }

  /// The `id: GenerationID` property, if the type declares one.
  private var generationIDProperty: GenerableProperty? {
    properties.first { $0.isGenerationID }
  }

  /// Whether the type declares an `id` property that isn't a `GenerationID`.
  ///
  /// `PartiallyGenerated` then keeps the property and doesn't synthesize `Identifiable`.
  private var hasNonGenerationIDProperty: Bool {
    properties.contains { $0.schemaName == "id" && !$0.isGenerationID }
  }

  /// The `generationSchema` static property.
  var generationSchemaSource: String {
    var arguments: [String] = []
    if let name {
      arguments.append("__name: \(name)")
    } else {
      arguments.append("type: Self.self")
    }
    if let description {
      arguments.append("description: \(description)")
    }
    if let representNilExplicitly {
      arguments.append("representNilExplicitlyInGeneratedContent: \(representNilExplicitly)")
    }
    let schemaProperties = schemaProperties
    if schemaProperties.isEmpty {
      arguments.append("properties: []")
    } else {
      let list = schemaProperties.map { "    \($0.schemaPropertySource)" }
        .joined(separator: ",\n")
      arguments.append("properties: [\n\(list)\n]")
    }
    return """
      nonisolated \(access.prefix)static var generationSchema: \(moduleName).GenerationSchema {
          \(moduleName).GenerationSchema(
              \(arguments.joined(separator: ",\n").indented(by: 8, skippingFirstLine: true))
          )
      }
      """
  }

  /// The `generatedContent` property.
  var generatedContentSource: String {
    let additions = schemaProperties.map {
      "    addProperty(name: \(stringLiteral($0.schemaName)), value: self.\($0.identifier))\n"
    }
    let idArgument = generationIDProperty.map { "        id: self.\($0.identifier),\n" } ?? ""
    let explicitNil = representNilExplicitly?.description ?? "false"
    let elementType = "(name: String, value: any \(moduleName).ConvertibleToGeneratedContent)"
    return """
      nonisolated \(access.prefix)var generatedContent: \(moduleName).GeneratedContent {
          let explicitNil = \(explicitNil)
          var properties = [\(elementType)]()
      \(additions.joined())    return \(moduleName).GeneratedContent(
              properties: properties,
      \(idArgument)        uniquingKeysWith: { _, second in
                  second
              }
          )
          func addProperty(name: String, value: some \(moduleName).Generable) {
              properties.append((name: name, value: value))
          }
          func addProperty(name: String, value: (some \(moduleName).Generable)?) {
              if explicitNil || value != nil {
                  properties.append((name: name, value: value))
              }
          }
      }
      """
  }

  /// The `init(_:)` initializer that decodes every stored property.
  var initializerSource: String {
    let assignments = properties.map { "    \($0.initializationSource)\n" }
    return """
      nonisolated \(access.prefix)init(_ content: \(moduleName).GeneratedContent) throws {
      \(assignments.joined())}
      """
  }

  /// The nested `PartiallyGenerated` struct.
  var partiallyGeneratedSource: String {
    var conformances: [String] = []
    var members: [String] = []
    var assignments: [String] = []
    if !hasNonGenerationIDProperty {
      conformances.append("Identifiable")
      members.append("\(access.prefix)var id: \(moduleName).GenerationID")
      assignments.append("self.id = content.id ?? \(moduleName).GenerationID()")
    }
    conformances.append("nonisolated \(moduleName).ConvertibleFromGeneratedContent")
    conformances.append(contentsOf: equatableConformances)
    for property in schemaProperties {
      members.append(
        "\(access.prefix)var \(property.identifier): \(property.type).PartiallyGenerated?")
      assignments.append(property.initializationSource)
    }
    let memberLines = members.map { "    \($0)\n" }.joined()
    let assignmentLines = assignments.map { "        \($0)\n" }.joined()
    let initializer = "init(_ content: \(moduleName).GeneratedContent) throws"
    let inheritance = conformances.joined(separator: ", ")
    return """
      nonisolated \(access.prefix)struct PartiallyGenerated: \(inheritance) {
      \(memberLines)    nonisolated \(access.prefix)\(initializer) {
      \(assignmentLines)    }
      }
      """
  }
}

extension String {
  /// Returns the string with every line indented by `width` spaces.
  ///
  /// - Parameters:
  ///   - width: The number of spaces to add.
  ///   - skippingFirstLine: Whether to leave the first line unchanged.
  /// - Returns: The indented string. Empty lines stay empty.
  func indented(by width: Int, skippingFirstLine: Bool = false) -> String {
    let indentation = String(repeating: " ", count: width)
    return split(separator: "\n", omittingEmptySubsequences: false).enumerated()
      .map { index, line in
        line.isEmpty || (skippingFirstLine && index == 0) ? String(line) : indentation + line
      }
      .joined(separator: "\n")
  }
}
