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

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FirebaseGenerableMacro: ExtensionMacro {
  public static func expansion(of _: SwiftSyntax.AttributeSyntax,
                               attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
                               providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
                               conformingTo _: [SwiftSyntax.TypeSyntax],
                               in _: some SwiftSyntaxMacros
                                 .MacroExpansionContext) throws
    -> [SwiftSyntax.ExtensionDeclSyntax] {
    if let structDecl = declaration.as(StructDeclSyntax.self) {
      return try expansionForStruct(of: structDecl, type: type)
    } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
      return try expansionForEnum(of: enumDecl, type: type)
    } else {
      throw MacroExpansionErrorMessage(
        "`@FirebaseGenerable` can only be applied to a struct or enum."
      )
    }
  }

  private static func expansionForStruct(of structDecl: StructDeclSyntax,
                                         type: some SwiftSyntax.TypeSyntaxProtocol) throws
    -> [SwiftSyntax.ExtensionDeclSyntax] {
    var propertyInits = [String]()

    for member in structDecl.memberBlock.members {
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
            let binding = variableDecl.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self)
      else {
        continue
      }

      // Exclude computed properties.
      if binding.accessorBlock != nil {
        continue
      }

      // Exclude `let` properties with an initial value.
      if variableDecl.bindingSpecifier.tokenKind == .keyword(.let), binding.initializer != nil {
        continue
      }

      let name = identifier.identifier.text
      propertyInits.append("self.\(name) = try content.value(forProperty: \"\(name)\")")
    }

    let inits = propertyInits.joined(separator: "\n    ")

    var declarations = [ExtensionDeclSyntax]()
    let declSyntax: DeclSyntax = """
    @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
    extension \(type.trimmed): FirebaseAILogic.FirebaseGenerable {
      nonisolated init(_ content: FirebaseAILogic.ModelOutput) throws {
        \(raw: inits)
      }
    }
    """
    guard let extensionDecl = declSyntax.as(ExtensionDeclSyntax.self) else {
      throw MacroExpansionErrorMessage("""
      Failed to generate `FirebaseGenerable` extension for struct `\(type.trimmed)`.
      """)
    }
    declarations.append(extensionDecl)

    return declarations
  }

  private static func expansionForEnum(of enumDecl: EnumDeclSyntax,
                                       type: some SwiftSyntax.TypeSyntaxProtocol) throws
    -> [SwiftSyntax.ExtensionDeclSyntax] {
    var caseNames = [String]()

    for member in enumDecl.memberBlock.members {
      guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
        continue
      }

      for element in caseDecl.elements {
        if element.parameterClause != nil {
          throw MacroExpansionErrorMessage(
            "`@FirebaseGenerable` does not currently support enums with associated values."
          )
        }
        caseNames.append(element.name.text)
      }
    }

    let isStringBacked = enumDecl.inheritanceClause?.inheritedTypes.contains {
      $0.type.trimmed.description == "String"
    } ?? false

    let initBody: String
    if isStringBacked {
      initBody = """
      let rawValue = try content.value(String.self)
      if let value = Self(rawValue: rawValue) {
        self = value
      } else {
        throw FirebaseAILogic.GenerativeModel.GenerationError.decodingFailure(
          FirebaseAILogic.GenerativeModel.GenerationError.Context(
            debugDescription: "Unexpected value \\"\\(rawValue)\\" for \\(Self.self)"
          )
        )
      }
      """
    } else {
      let caseChecks = caseNames.map { caseName in
        "case \"\(caseName)\":\nself = .\(caseName)"
      }.joined(separator: "\n")

      initBody = """
      let rawValue = try content.value(String.self)
      switch rawValue {
      \(caseChecks)
      default:
        throw FirebaseAILogic.GenerativeModel.GenerationError.decodingFailure(
          FirebaseAILogic.GenerativeModel.GenerationError.Context(
            debugDescription: "Unexpected value \\"\\(rawValue)\\" for \\(Self.self)"
          )
        )
      }
      """
    }

    var declarations = [ExtensionDeclSyntax]()
    let declSyntaxString = """
    @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
    extension \(type.trimmed): FirebaseAILogic.FirebaseGenerable {
      nonisolated init(_ content: FirebaseAILogic.ModelOutput) throws {
        \(initBody)
      }
    }
    """
    let declSyntax = DeclSyntax(stringLiteral: declSyntaxString)
    guard let extensionDecl = declSyntax.as(ExtensionDeclSyntax.self) else {
      throw MacroExpansionErrorMessage("""
      Failed to generate `FirebaseGenerable` extension for enum `\(type.trimmed)`.
      """)
    }
    declarations.append(extensionDecl)

    return declarations
  }

  private static func expansionForEnum(of enumDecl: EnumDeclSyntax,
                                       type: some SwiftSyntax.TypeSyntaxProtocol) throws
    -> [SwiftSyntax.ExtensionDeclSyntax] {
    var caseNames = [String]()

    for member in enumDecl.memberBlock.members {
      guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
        continue
      }

      for element in caseDecl.elements {
        if element.parameterClause != nil {
          throw MacroExpansionErrorMessage(
            "`@FirebaseGenerable` does not currently support enums with associated values."
          )
        }
        caseNames.append(element.name.text)
      }
    }

    let caseChecks = caseNames.map { caseName in
      "case \"\(caseName)\":\nself = .\(caseName)"
    }.joined(separator: "\n")

    var declarations = [ExtensionDeclSyntax]()
    let declSyntaxString = """
    @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
    extension \(type.trimmed): FirebaseAILogic.FirebaseGenerable {
      nonisolated init(_ content: FirebaseAILogic.ModelOutput) throws {
        let rawValue = try content.value(String.self)
        switch rawValue {
        \(caseChecks)
        default:
          throw FirebaseAILogic.GenerativeModel.GenerationError.decodingFailure(
            FirebaseAILogic.GenerativeModel.GenerationError.Context(
              debugDescription: "Unexpected value \\"\\(rawValue)\\" for \\(Self.self)"
            )
          )
        }
      }
    }
    """
    let declSyntax = DeclSyntax(stringLiteral: declSyntaxString)
    guard let extensionDecl = declSyntax.as(ExtensionDeclSyntax.self) else {
      throw MacroExpansionErrorMessage("""
      Failed to generate `FirebaseGenerable` extension for enum `\(type.trimmed)`.
      """)
    }
    declarations.append(extensionDecl)

    return declarations
  }
}

struct PropertyInfo {
  let name: String
  let type: TypeSyntax
  let description: String?
  let guides: [String]
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension FirebaseGenerableMacro: MemberMacro {
  public static func expansion(of node: SwiftSyntax.AttributeSyntax,
                               providingMembersOf declaration: some SwiftSyntax.DeclGroupSyntax,
                               conformingTo _: [SwiftSyntax.TypeSyntax],
                               in _: some SwiftSyntaxMacros
                                 .MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax] {
    if let structDecl = declaration.as(StructDeclSyntax.self) {
      return try expansionForStruct(of: node, structDecl: structDecl)
    } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
      return try expansionForEnum(of: node, enumDecl: enumDecl)
    } else {
      throw MacroExpansionErrorMessage(
        "`@FirebaseGenerable` can only be applied to a struct or enum."
      )
    }
  }

  private static func expansionForStruct(of node: SwiftSyntax.AttributeSyntax,
                                         structDecl: StructDeclSyntax) throws
    -> [SwiftSyntax.DeclSyntax] {
    // Find the description for the struct itself from the @FirebaseGenerable macro.
    let structDescription = try getDescriptionFromGenerableMacro(node)

    var propertyInfos = [PropertyInfo]()

    // Iterate over the members of the struct to find properties.
    for member in structDecl.memberBlock.members {
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
            let binding = variableDecl.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self)
      else {
        continue
      }

      // Exclude computed properties.
      if binding.accessorBlock != nil {
        continue
      }

      // Exclude `let` properties with an initial value.
      if variableDecl.bindingSpecifier.tokenKind == .keyword(.let), binding.initializer != nil {
        continue
      }

      guard let typeAnnotation = binding.typeAnnotation else {
        continue
      }

      let name = identifier.identifier.text
      let type = typeAnnotation.type

      // Look for the @Guide macro on the property.
      let guides = getGuideMacroArguments(variableDecl.attributes)
      var propertyDescription: String? = nil
      var propertyGuides: [String] = []

      if let guideArgs = guides {
        for argument in guideArgs {
          if let label = argument.label, label.text == "description" {
            propertyDescription = getDescriptionArgument(guideArgs)
          } else {
            // This argument is a guide. Add its string representation to the array.
            propertyGuides.append(String(describing: argument.expression))
          }
        }
      }

      propertyInfos.append(PropertyInfo(
        name: name,
        type: type,
        description: propertyDescription,
        guides: propertyGuides
      ))
    }

    return generateStructMembers(
      structDescription: structDescription,
      propertyInfos: propertyInfos
    )
  }

  private static func expansionForEnum(of node: SwiftSyntax.AttributeSyntax,
                                       enumDecl: EnumDeclSyntax) throws
    -> [SwiftSyntax.DeclSyntax] {
    var rawValues = [String]()
    var caseNames = [String]()

    for member in enumDecl.memberBlock.members {
      guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
        continue
      }

      for element in caseDecl.elements {
        caseNames.append(element.name.text)
        if let rawValueExpr = element.rawValue?.value.as(StringLiteralExprSyntax.self),
           let segment = rawValueExpr.segments.first?.as(StringSegmentSyntax.self) {
          rawValues.append(segment.content.text)
        } else {
          rawValues.append(element.name.text)
        }
      }
    }

    let isStringBacked = enumDecl.inheritanceClause?.inheritedTypes.contains {
      $0.type.trimmed.description == "String"
    } ?? false

    // Find the description for the enum itself from the @FirebaseGenerable macro.
    let enumDescription = try getDescriptionFromGenerableMacro(node)

    // Generate `static var jsonSchema: ...` computed property.
    let anyOfList: String
    if isStringBacked {
      anyOfList = caseNames.map { "\($0).rawValue" }.joined(separator: ", ")
    } else {
      anyOfList = rawValues.map { "\"\($0)\"" }.joined(separator: ", ")
    }

    var schemaParameters = ["type: Self.self"]
    if let enumDescription {
      schemaParameters.append("description: \"\(enumDescription)\"")
    }
    schemaParameters.append("anyOf: [\(anyOfList)]")
    let schemaParametersCode = schemaParameters.joined(separator: ", ")

    let generationSchemaCode = """
    nonisolated static var jsonSchema: FirebaseAILogic.JSONSchema {
      FirebaseAILogic.JSONSchema(\(schemaParametersCode))
    }
    """

    // Generate `var modelOutput: ...` computed property.
    let modelOutputCode: String
    if isStringBacked {
      modelOutputCode = """
      nonisolated var modelOutput: FirebaseAILogic.ModelOutput {
        rawValue.modelOutput
      }
      """
    } else {
      let switchCases = caseNames.map { caseName in
        "case .\(caseName):\n    \"\(caseName)\".modelOutput"
      }.joined(separator: "\n  ")

      modelOutputCode = """
      nonisolated var modelOutput: FirebaseAILogic.ModelOutput {
        switch self {
        \(switchCases)
        }
      }
      """
    }

    return [
      DeclSyntax(stringLiteral: generationSchemaCode),
      DeclSyntax(stringLiteral: modelOutputCode),
    ]
  }

  private static func generateStructMembers(structDescription: String?,
                                            propertyInfos: [PropertyInfo]) -> [DeclSyntax] {
    var propertyNames = [String]()
    var propertySchemas = [String]()
    var partiallyGeneratedProperties = [String]()
    var partiallyGeneratedInits = [String]()

    for info in propertyInfos {
      propertyNames.append(info.name)

      // Build the property schema code string.
      var propertySchemaString =
        "FirebaseAILogic.JSONSchema.Property(name: \"\(info.name)\", "
      if let desc = info.description {
        propertySchemaString += "description: \"\(desc)\", "
      }
      propertySchemaString += "type: \(info.type).self"
      if !info.guides.isEmpty {
        propertySchemaString += ", guides: ["
        propertySchemaString += info.guides.joined(separator: ", ")
        propertySchemaString += "]"
      }
      propertySchemaString += ")"

      propertySchemas.append(propertySchemaString)

      let propertyTypeString = info.type.trimmed.description
      partiallyGeneratedProperties
        .append("var \(info.name): \(propertyTypeString).Partial?")
      partiallyGeneratedInits
        .append("self.\(info.name) = try content.value(forProperty: \"\(info.name)\")")
    }

    var schemaInitializerList = ["type: Self.self"]
    if let structDescription {
      schemaInitializerList.append("description: \"\(structDescription)\"")
    }

    var schemaPropertiesList = "properties: ["
    if !propertySchemas.isEmpty {
      schemaPropertiesList.append("\n")
      schemaPropertiesList.append(propertySchemas.joined(separator: ",\n"))
      schemaPropertiesList.append("\n")
    }
    schemaPropertiesList.append("]")

    schemaInitializerList.append(schemaPropertiesList)

    let schemaParametersCode = schemaInitializerList.joined(separator: ",\n")

    // Generate `static var jsonSchema: ...` computed property.
    let generationSchemaCode = """
    nonisolated static var jsonSchema: FirebaseAILogic.JSONSchema {
      FirebaseAILogic.JSONSchema(
        \(schemaParametersCode)
      )
    }
    """

    // Generate `var modelOutput: ...` computed property.
    let addPropertiesList = propertyNames.map { propertyName in
      "addProperty(name: \"\(propertyName)\", value: self.\(propertyName))"
    }.joined(separator: "\n")

    let modelOutputCode = """
    nonisolated var modelOutput: FirebaseAILogic.ModelOutput {
      var properties = [(name: String, value: any ConvertibleToModelOutput)]()
      \(addPropertiesList)
      return ModelOutput(
        properties: properties,
        uniquingKeysWith: { _, second in
          second
        }
      )
      func addProperty(name: String, value: some FirebaseGenerable) {
        properties.append((name, value))
      }
      func addProperty(name: String, value: (some FirebaseGenerable)?) {
        if let value {
          properties.append((name, value))
        }
      }
    }
    """

    let partiallyGeneratedPropertiesCode = partiallyGeneratedProperties.joined(
      separator: "\n  "
    )
    let partiallyGeneratedInitsCode = partiallyGeneratedInits.joined(separator: "\n    ")

    let partiallyGeneratedStructCode = """
    nonisolated struct Partial: Identifiable, FirebaseAILogic.ConvertibleFromModelOutput {
      var id: FirebaseAILogic.ResponseID
      \(partiallyGeneratedPropertiesCode)
      nonisolated init(_ content: FirebaseAILogic.ModelOutput) throws {
        self.id = content.id ?? FirebaseAILogic.ResponseID()
        \(partiallyGeneratedInitsCode)
      }
    }
    """

    return [
      DeclSyntax(stringLiteral: generationSchemaCode),
      DeclSyntax(stringLiteral: modelOutputCode),
      DeclSyntax(stringLiteral: partiallyGeneratedStructCode),
    ]
  }
}

/// A helper function to find the `@Guide` macro and return its arguments.
private func getGuideMacroArguments(_ attributes: AttributeListSyntax?) -> LabeledExprListSyntax? {
  guard let attributes = attributes else { return nil }

  for attribute in attributes {
    guard let attributeSyntax = attribute.as(AttributeSyntax.self) else { continue }
    if let attributeName = attributeSyntax.attributeName.as(IdentifierTypeSyntax.self),
       attributeName.name.text == "FirebaseGuide" {
      return attributeSyntax.arguments?.as(LabeledExprListSyntax.self)
    }
  }
  return nil
}

/// A helper function to find the 'description' argument from a `@Generable` macro.
private func getDescriptionFromGenerableMacro(_ node: AttributeSyntax) throws -> String? {
  guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
    return nil
  }

  for argument in arguments {
    if let label = argument.label, label.text == "description" {
      guard let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
            let description = stringLiteral.representedLiteralValue
      else {
        continue
      }
      return description
    }
  }

  return nil
}

/// A helper function to extract the string value for the 'description' argument
/// from a `LabeledExprListSyntax`.
///
/// - Parameter arguments: The `LabeledExprListSyntax` from a macro call.
/// - Returns: The `String` value of the `description` argument, or `nil` if not found.
func getDescriptionArgument(_ arguments: LabeledExprListSyntax) -> String? {
  for argument in arguments {
    // Check if the argument has a label and if it's "description".
    if let label = argument.label, label.text == "description" {
      // The expression must be a string literal.
      guard let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) else {
        return nil
      }

      // Extract and return the string value from the literal.
      return stringLiteral.segments.compactMap { segment in
        segment.as(StringSegmentSyntax.self)?.content.text
      }.joined()
    }
  }

  return nil
}
