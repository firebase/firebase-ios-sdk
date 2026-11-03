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

import SwiftDiagnostics
import SwiftSyntax

/// A stored property (or enum payload) that becomes a property of a generated schema.
struct GenerableProperty {
  /// The property name used in the schema and in generated content, without backticks.
  let schemaName: String

  /// The property name as written in source, including any backticks.
  let identifier: String

  /// The declared type of the property.
  let type: TypeSyntax

  /// The `description:` argument of the property's `@Guide`, if any.
  var description: ExprSyntax?

  /// The unlabeled arguments of the property's `@Guide` attributes.
  var guides: [ExprSyntax]

  /// Creates a property.
  ///
  /// - Parameters:
  ///   - name: The property name as written in source.
  ///   - type: The declared type.
  ///   - description: The guide description.
  ///   - guides: The guide expressions.
  init(
    name: TokenSyntax, type: TypeSyntax, description: ExprSyntax? = nil, guides: [ExprSyntax] = []
  ) {
    self.schemaName = name.unescapedText
    self.identifier = name.trimmedDescription
    self.type = type.normalizedForGeneration
    self.description = description
    self.guides = guides
  }

  /// Creates a property with an explicit schema name and identifier.
  ///
  /// - Parameters:
  ///   - schemaName: The name used in the schema.
  ///   - identifier: The name used in source.
  ///   - type: The declared type.
  ///   - guides: The guide expressions.
  init(schemaName: String, identifier: String, type: TypeSyntax, guides: [ExprSyntax] = []) {
    self.schemaName = schemaName
    self.identifier = identifier
    self.type = type.normalizedForGeneration
    self.description = nil
    self.guides = guides
  }

  /// Whether this is an `id: GenerationID` or `id: GenerationID?` property, which maps to the
  /// content's generation ID instead of a schema property.
  var isGenerationID: Bool {
    schemaName == "id" && generationIDOptionality != nil
  }

  /// Whether the type is `GenerationID` (`false`) or an optional `GenerationID` (`true`), or `nil`
  /// if it's neither.
  private var generationIDOptionality: Bool? {
    let typeName = type.trimmedDescription.filter { !$0.isWhitespace }
    let names = ["GenerationID", "\(moduleName).GenerationID"]
    if names.contains(typeName) {
      return false
    }
    let optionalForms = names.flatMap { ["\($0)?", "Optional<\($0)>", "Swift.Optional<\($0)>"] }
    return optionalForms.contains(typeName) ? true : nil
  }

  /// The `GenerationSchema.Property(...)` expression for this property.
  var schemaPropertySource: String {
    var arguments = ["name: \(stringLiteral(schemaName))"]
    if let description {
      arguments.append("description: \(description)")
    }
    arguments.append("type: \(type).self")
    if !guides.isEmpty {
      arguments.append("guides: [\(guides.map(\.description).joined(separator: ", "))]")
    }
    return "\(moduleName).GenerationSchema.Property(\(arguments.joined(separator: ", ")))"
  }

  /// The statement that initializes this property from `content`.
  var initializationSource: String {
    if let isOptional = generationIDOptionality, schemaName == "id" {
      let fallback = isOptional ? "" : " ?? \(moduleName).GenerationID()"
      return "self.\(identifier) = content.id\(fallback)"
    }
    return "self.\(identifier) = try content.value(forProperty: \(stringLiteral(schemaName)))"
  }
}

extension GenerableProperty {
  /// Collects the stored instance properties of a struct, in declaration order.
  ///
  /// Static, `lazy`, and computed properties are skipped, as are `let` constants with an
  /// initial value (they can't be assigned by `init(_:)`). Properties without a type annotation
  /// are skipped with a warning.
  ///
  /// - Parameters:
  ///   - declaration: The struct declaration.
  ///   - diagnose: Reports a diagnostic.
  /// - Returns: The properties that become part of the schema.
  static func storedProperties(
    of declaration: some DeclGroupSyntax,
    diagnose: (Diagnostic) -> Void
  ) -> [GenerableProperty] {
    var properties: [GenerableProperty] = []
    for member in declaration.memberBlock.members {
      guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
      properties.append(contentsOf: storedProperties(of: variable, diagnose: diagnose))
    }
    return properties
  }

  /// Collects the stored properties declared by a single variable declaration.
  ///
  /// - Parameters:
  ///   - variable: The variable declaration.
  ///   - diagnose: Reports a diagnostic.
  /// - Returns: The properties that become part of the schema.
  private static func storedProperties(
    of variable: VariableDeclSyntax,
    diagnose: (Diagnostic) -> Void
  ) -> [GenerableProperty] {
    let modifiers = Set(variable.modifiers.map(\.name.text))
    guard modifiers.isDisjoint(with: ["static", "class", "lazy"]) else { return [] }
    let isLet = variable.bindingSpecifier.tokenKind == .keyword(.let)
    let (description, guides) = guideArguments(of: variable.attributes)

    // In `var a, b: Int`, `a` takes its type from the next binding that has one.
    var bindings: [(name: TokenSyntax, type: TypeSyntax)] = []
    var followingType: TypeSyntax?
    for binding in variable.bindings.reversed() {
      if let accessorBlock = binding.accessorBlock, accessorBlock.declaresComputedProperty {
        followingType = binding.typeAnnotation?.type
        continue
      }
      guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
        diagnose(
          Diagnostic(node: binding.pattern, message: MacroDiagnostic.tuplePatternUnsupported))
        followingType = nil
        continue
      }
      if let annotation = binding.typeAnnotation {
        followingType = annotation.type
      } else if binding.initializer != nil {
        followingType = nil
      }
      if isLet && binding.initializer != nil {
        continue
      }
      guard let type = followingType else {
        diagnose(
          Diagnostic(
            node: pattern,
            message: MacroDiagnostic.missingTypeAnnotation(
              propertyName: pattern.identifier.unescapedText)
          )
        )
        continue
      }
      bindings.append((pattern.identifier, type))
    }
    return bindings.reversed().map {
      GenerableProperty(name: $0.name, type: $0.type, description: description, guides: guides)
    }
  }

  /// Reads the description and guides from the `@Guide` attributes in `attributes`.
  ///
  /// - Parameter attributes: The attributes of a variable declaration.
  /// - Returns: The last `description:` argument and all unlabeled guide arguments.
  private static func guideArguments(
    of attributes: AttributeListSyntax
  ) -> (description: ExprSyntax?, guides: [ExprSyntax]) {
    var description: ExprSyntax?
    var guides: [ExprSyntax] = []
    for element in attributes {
      guard case .attribute(let attribute) = element, attribute.isGuideAttribute,
        case .argumentList(let arguments) = attribute.arguments
      else { continue }
      for argument in arguments {
        if argument.label?.text == "description" {
          description = argument.expression.trimmed
        } else {
          guides.append(argument.expression.trimmed)
        }
      }
    }
    return (description, guides)
  }
}

extension AttributeSyntax {
  /// Whether this attribute is `@Guide` or `@FoundationModelsFake.Guide`.
  var isGuideAttribute: Bool {
    let name = attributeName.trimmedDescription
    return name == "Guide" || name == "\(moduleName).Guide"
  }
}

extension AccessorBlockSyntax {
  /// Whether the accessors make the property computed (rather than stored with observers).
  var declaresComputedProperty: Bool {
    switch accessors {
    case .getter:
      return true
    case .accessors(let accessors):
      return accessors.contains {
        $0.accessorSpecifier.tokenKind != .keyword(.willSet)
          && $0.accessorSpecifier.tokenKind != .keyword(.didSet)
      }
    }
  }
}
