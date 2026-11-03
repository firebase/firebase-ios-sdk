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
import SwiftSyntaxBuilder

/// An enum case and its associated values.
struct GenerableEnumCase {
  /// An associated value of a case.
  struct AssociatedValue {
    /// The argument label, escaped where needed, or `nil` when the value is unlabeled.
    let label: String?

    /// The property name used in the schema: the label, or `value`, `value1`, ... when unlabeled.
    let schemaName: String

    /// The identifier used for bindings and helper-struct properties, with backticks if it's a
    /// keyword.
    let identifier: String

    /// The declared type.
    let type: TypeSyntax
  }

  /// The case name as written, including any backticks.
  let identifier: String

  /// The case name without backticks, used as the generated string value.
  let name: String

  /// The associated values, in declaration order.
  let associatedValues: [AssociatedValue]

  /// Creates a case model from a case element.
  ///
  /// - Parameter element: The case element.
  init(element: EnumCaseElementSyntax) {
    identifier = element.name.trimmedDescription
    name = element.name.unescapedText
    var unlabeledCount = 0
    associatedValues = (element.parameterClause?.parameters ?? []).map { parameter in
      if let firstName = parameter.firstName, firstName.tokenKind != .wildcard {
        let name = firstName.unescapedText
        return AssociatedValue(
          label: name.escapedAsArgumentLabel,
          schemaName: name,
          identifier: name.escapedAsIdentifier,
          type: parameter.type.normalizedForGeneration
        )
      }
      let schemaName = unlabeledCount == 0 ? "value" : "value\(unlabeledCount)"
      unlabeledCount += 1
      return AssociatedValue(
        label: nil,
        schemaName: schemaName,
        identifier: schemaName,
        type: parameter.type.normalizedForGeneration
      )
    }
  }

  /// The name of the `Discriminated*` helper struct for this case.
  var discriminatedTypeName: String {
    "Discriminated" + name.prefix(1).uppercased() + name.dropFirst()
  }
}

/// Generates the `Generable` members of an enum.
struct EnumCodeGenerator {
  /// How an enum is represented in generated content.
  enum Representation {
    /// Every case is a string: its name (for enums without a `String` raw type).
    case caseNames

    /// Every case is a string: its `String` raw value.
    case stringRawValues

    /// Cases are objects with a `type` discriminator and their associated values.
    case discriminated
  }

  /// The access modifier repeated on generated members.
  var access: GeneratedAccess

  /// The `@Generable` arguments.
  var arguments: GenerableArguments

  /// The cases, in declaration order.
  var cases: [GenerableEnumCase]

  /// Whether the enum has a `String` raw type.
  var hasStringRawType: Bool

  /// The `Equatable`/`Hashable` conformances that generated helper types repeat.
  var equatableConformances: [String]

  /// The representation used for this enum.
  var representation: Representation {
    if cases.contains(where: { !$0.associatedValues.isEmpty }) {
      return .discriminated
    }
    return hasStringRawType ? .stringRawValues : .caseNames
  }

  /// The members added by the member macro.
  var memberSources: [String] {
    switch representation {
    case .caseNames, .stringRawValues:
      return [generationSchemaSource, generatedContentSource]
    case .discriminated:
      return [partiallyGeneratedSource, generationSchemaSource]
        + cases.map(discriminatedStructSource) + [generatedContentSource]
    }
  }

  /// The arguments that identify the schema: `type: Self.self` or `__name:`, plus `description:`.
  private var schemaIdentityArguments: [String] {
    var result = [arguments.name.map { "__name: \($0)" } ?? "type: Self.self"]
    if let description = arguments.description {
      result.append("description: \(description)")
    }
    return result
  }

  /// The `generationSchema` static property.
  private var generationSchemaSource: String {
    let body: String
    switch representation {
    case .caseNames:
      let choices = cases.map { stringLiteral($0.name) }.joined(separator: ", ")
      let schemaArguments = schemaIdentityArguments + ["anyOf: [\(choices)]"]
      body = "\(moduleName).GenerationSchema(\(schemaArguments.joined(separator: ", ")))"
    case .stringRawValues:
      let choices = cases.map { "\($0.identifier).rawValue" }.joined(separator: ", ")
      let schemaArguments = schemaIdentityArguments + ["anyOf: [\(choices)]"]
      body = "\(moduleName).GenerationSchema(\(schemaArguments.joined(separator: ", ")))"
    case .discriminated:
      let choices = cases.map { "        \($0.discriminatedTypeName).self" }
        .joined(separator: ",\n")
      let schemaArguments = schemaIdentityArguments.map { "    \($0),\n" }.joined()
      body = """
        \(moduleName).GenerationSchema(
        \(schemaArguments)    anyOf: [
        \(choices)
            ]
        )
        """
    }
    return """
      nonisolated \(access.prefix)static var generationSchema: \(moduleName).GenerationSchema {
      \(body.indented(by: 4))
      }
      """
  }

  /// The `generatedContent` property.
  private var generatedContentSource: String {
    let body: String
    switch representation {
    case .caseNames:
      body = """
        switch self {
        \(cases.map { "case .\($0.identifier):\n    \(stringLiteral($0.name)).generatedContent" }
          .joined(separator: "\n"))
        }
        """
    case .stringRawValues:
      body = "rawValue.generatedContent"
    case .discriminated:
      body = """
        switch self {
        \(cases.map(discriminatedContentCase).joined(separator: "\n"))
        }
        """
    }
    return """
      nonisolated \(access.prefix)var generatedContent: \(moduleName).GeneratedContent {
      \(body.indented(by: 4))
      }
      """
  }

  /// The `case` clause of `generatedContent` for a case of a discriminated enum.
  ///
  /// - Parameter enumCase: The case.
  /// - Returns: The source of the `case` clause.
  private func discriminatedContentCase(_ enumCase: GenerableEnumCase) -> String {
    let bindings =
      enumCase.associatedValues.isEmpty
      ? "" : "(\(enumCase.associatedValues.map { "let \($0.identifier)" }.joined(separator: ", ")))"
    let entries =
      ["        \"type\": \(stringLiteral(enumCase.name))"]
      + enumCase.associatedValues.map {
        "        \(stringLiteral($0.schemaName)): \($0.identifier)"
      }
    return """
      case .\(enumCase.identifier)\(bindings):
          \(moduleName).GeneratedContent(
              properties: [
      \(entries.joined(separator: ",\n").indented(by: 4))
              ]
          )
      """
  }

  /// The `init(_:)` initializer added by the extension macro.
  var initializerSource: String {
    """
    nonisolated \(access.prefix)init(_ content: \(moduleName).GeneratedContent) throws {
    \(initializerBody.indented(by: 4))
    }
    """
  }

  /// The body of `init(_:)`, shared with the `PartiallyGenerated` enum.
  private var initializerBody: String {
    switch representation {
    case .caseNames:
      let clauses = cases.map {
        "case \(stringLiteral($0.name)):\n    self = .\($0.identifier)"
      }
      return """
        let rawValue = try content.value(String.self)
        switch rawValue {
        \(clauses.joined(separator: "\n"))
        default:
            \(parsingError(#"\"\(rawValue)\" isn't a case of \(Self.self)"#))
        }
        """
    case .stringRawValues:
      return """
        let rawValue = try content.value(String.self)
        if let value = Self(rawValue: rawValue) {
            self = value
        } else {
            \(parsingError(#"\"\(rawValue)\" isn't a raw value of \(Self.self)"#))
        }
        """
    case .discriminated:
      return """
        let type: String = try content.value(forProperty: "type")
        switch type {
        \(cases.map(discriminatedInitializerCase).joined(separator: "\n"))
        default:
            \(parsingError(#"The type \"\(type)\" isn't a case of \(Self.self)"#))
        }
        """
    }
  }

  /// A statement that throws a `ParsingError` for the content.
  ///
  /// - Parameter debugDescription: The contents of the debug description string literal, which
  ///   may contain interpolations.
  /// - Returns: The `throw` statement.
  private func parsingError(_ debugDescription: String) -> String {
    "throw \(moduleName).GeneratedContent.ParsingError(rawContent: content.jsonString, "
      + "debugDescription: \"\(debugDescription)\")"
  }

  /// The `case` clause of `init(_:)` for a case of a discriminated enum.
  ///
  /// - Parameter enumCase: The case.
  /// - Returns: The source of the `case` clause.
  private func discriminatedInitializerCase(_ enumCase: GenerableEnumCase) -> String {
    let values = enumCase.associatedValues.map { value in
      let decode = "try content.value(forProperty: \(stringLiteral(value.schemaName)))"
      return value.label.map { "\($0): \(decode)" } ?? decode
    }
    let construction: String
    switch values.count {
    case 0:
      construction = ".\(enumCase.identifier)"
    case 1:
      construction = ".\(enumCase.identifier)(\(values[0]))"
    default:
      construction = """
        .\(enumCase.identifier)(
                \(values.joined(separator: ",\n        "))
            )
        """
    }
    return "case \(stringLiteral(enumCase.name)):\n    self = \(construction)"
  }

  /// The nested `PartiallyGenerated` enum of a discriminated enum.
  private var partiallyGeneratedSource: String {
    let conformances =
      ["nonisolated \(moduleName).ConvertibleFromGeneratedContent"] + equatableConformances
    let caseLines = cases.map { enumCase -> String in
      guard !enumCase.associatedValues.isEmpty else { return "    case \(enumCase.identifier)\n" }
      let values = enumCase.associatedValues.map { value in
        let type = "\(value.type).PartiallyGenerated?"
        return value.label.map { "\($0): \(type)" } ?? type
      }
      return "    case \(enumCase.identifier)(\(values.joined(separator: ", ")))\n"
    }
    return """
      nonisolated \(access.prefix)enum PartiallyGenerated: \(conformances.joined(separator: ", ")) {
      \(caseLines.joined())\(initializerSource.indented(by: 4))
      }
      """
  }

  /// The private `Discriminated*` struct that describes one case in the schema.
  ///
  /// - Parameter enumCase: The case.
  /// - Returns: The source of the struct.
  private func discriminatedStructSource(_ enumCase: GenerableEnumCase) -> String {
    let constantGuide = ExprSyntax(".constant(\(raw: stringLiteral(enumCase.name)))")
    let typeProperty = GenerableProperty(
      schemaName: "type",
      identifier: "type",
      type: TypeSyntax("String"),
      guides: [constantGuide]
    )
    let valueProperties = enumCase.associatedValues.map {
      GenerableProperty(schemaName: $0.schemaName, identifier: $0.identifier, type: $0.type)
    }
    let generator = ObjectCodeGenerator(
      access: .implicit,
      name: nil,
      description: arguments.description,
      representNilExplicitly: arguments.representNilExplicitly,
      properties: [typeProperty] + valueProperties,
      equatableConformances: equatableConformances
    )
    let conformances = (["nonisolated \(moduleName).Generable"] + equatableConformances)
      .joined(separator: ", ")
    let storedProperties = valueProperties.map { "    let \($0.identifier): \($0.type)\n" }
    return """
      private nonisolated struct \(enumCase.discriminatedTypeName): \(conformances) {
          @\(moduleName).Guide(\(constantGuide))
          let type: String
      \(storedProperties.joined())\(generator.initializerSource.indented(by: 4))
      \(generator.generationSchemaSource.indented(by: 4))
      \(generator.generatedContentSource.indented(by: 4))
      }
      """
  }
}
