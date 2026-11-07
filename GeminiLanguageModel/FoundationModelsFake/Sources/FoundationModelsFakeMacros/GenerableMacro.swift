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
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implements `@Generable`, which conforms a struct or enum to `Generable`.
///
/// The member macro adds `generationSchema`, `generatedContent`, and (for structs and enums with
/// associated values) a nested `PartiallyGenerated` type. The extension macro adds the
/// `Generable` conformance and `init(_:)`, so that a struct keeps its memberwise initializer.
/// Every type reference is qualified with `FoundationModelsFake`, and every generated
/// member is `nonisolated`.
struct GenerableMacro: ExtensionMacro, MemberMacro {
  /// Adds the `Generable` members of `declaration`.
  ///
  /// - Parameters:
  ///   - node: The `@Generable` attribute.
  ///   - declaration: The attached declaration.
  ///   - protocols: The protocols the compiler asks the macro to add conformances to.
  ///   - context: The macro expansion context.
  /// - Returns: The generated members.
  static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard declaration.is(StructDeclSyntax.self) || declaration.is(EnumDeclSyntax.self) else {
      context.diagnose(
        Diagnostic(node: node, message: MacroDiagnostic.generableRequiresStructOrEnum))
      return []
    }
    guard !declaration.declaresGenerableConformance else {
      context.diagnose(Diagnostic(node: node, message: MacroDiagnostic.alreadyConformsToGenerable))
      return []
    }
    let arguments = GenerableArguments(attribute: node)
    let sources: [String]
    if let enumDeclaration = declaration.as(EnumDeclSyntax.self) {
      guard
        let generator = enumGenerator(
          for: enumDeclaration, arguments: arguments, diagnose: context.diagnose)
      else { return [] }
      sources = generator.memberSources
    } else {
      let generator = structGenerator(
        for: declaration, arguments: arguments, diagnose: context.diagnose)
      sources = [
        generator.generationSchemaSource,
        generator.generatedContentSource,
        generator.partiallyGeneratedSource,
      ]
    }
    return sources.map { DeclSyntax(stringLiteral: $0) }
  }

  /// Adds the `Generable` conformance and `init(_:)` to `declaration`.
  ///
  /// - Parameters:
  ///   - node: The `@Generable` attribute.
  ///   - declaration: The attached declaration.
  ///   - type: The type to extend.
  ///   - protocols: The protocols the compiler asks the macro to add conformances to.
  ///   - context: The macro expansion context.
  /// - Returns: The generated extension, or nothing if the declaration is unsupported.
  static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    // The member macro reports unsupported declarations, so they're skipped silently here.
    guard declaration.is(StructDeclSyntax.self) || declaration.is(EnumDeclSyntax.self),
      !declaration.declaresGenerableConformance
    else { return [] }
    let arguments = GenerableArguments(attribute: node)
    let initializer: String
    if let enumDeclaration = declaration.as(EnumDeclSyntax.self) {
      guard
        let generator = enumGenerator(
          for: enumDeclaration, arguments: arguments, diagnose: { _ in })
      else { return [] }
      initializer = generator.initializerSource
    } else {
      initializer =
        structGenerator(for: declaration, arguments: arguments, diagnose: { _ in })
        .initializerSource
    }
    let conformance = protocols.isEmpty ? "" : ": nonisolated \(moduleName).Generable"
    let source = """
      extension \(type.trimmedDescription)\(conformance) {
      \(initializer.indented(by: 4))
      }
      """
    return [try ExtensionDeclSyntax(SyntaxNodeString(stringLiteral: source))]
  }

  /// Creates the code generator for a struct.
  ///
  /// - Parameters:
  ///   - declaration: The struct declaration.
  ///   - arguments: The `@Generable` arguments.
  ///   - diagnose: Reports diagnostics about the properties.
  /// - Returns: The code generator.
  private static func structGenerator(
    for declaration: some DeclGroupSyntax,
    arguments: GenerableArguments,
    diagnose: (Diagnostic) -> Void
  ) -> ObjectCodeGenerator {
    ObjectCodeGenerator(
      access: GeneratedAccess(modifiers: declaration.modifiers),
      name: arguments.name,
      description: arguments.description,
      representNilExplicitly: arguments.representNilExplicitly,
      properties: GenerableProperty.storedProperties(of: declaration, diagnose: diagnose),
      equatableConformances: declaration.equatableConformances
    )
  }

  /// Creates the code generator for an enum, diagnosing unsupported enums.
  ///
  /// - Parameters:
  ///   - declaration: The enum declaration.
  ///   - arguments: The `@Generable` arguments.
  ///   - diagnose: Reports diagnostics.
  /// - Returns: The code generator, or `nil` if the enum is unsupported.
  private static func enumGenerator(
    for declaration: EnumDeclSyntax,
    arguments: GenerableArguments,
    diagnose: (Diagnostic) -> Void
  ) -> EnumCodeGenerator? {
    let elements = declaration.memberBlock.members.flatMap {
      $0.decl.as(EnumCaseDeclSyntax.self)?.elements.map { $0 } ?? []
    }
    let cases = elements.map(GenerableEnumCase.init(element:))
    var isSupported = true
    let isDiscriminated = cases.contains { !$0.associatedValues.isEmpty }
    var casesByTypeName: [String: GenerableEnumCase] = [:]
    for (element, enumCase) in zip(elements, cases) {
      var problems: [MacroDiagnostic] = []
      var propertyNames: Set<String> = []
      for value in enumCase.associatedValues {
        if value.schemaName == "type" {
          problems.append(.associatedValueNamedType(caseName: enumCase.name))
        } else if !propertyNames.insert(value.schemaName).inserted {
          problems.append(
            .duplicateAssociatedValueName(caseName: enumCase.name, propertyName: value.schemaName))
        }
      }
      if isDiscriminated {
        let typeName = enumCase.discriminatedTypeName
        if let other = casesByTypeName[typeName] {
          problems.append(
            .duplicateDiscriminatedTypeName(
              caseName: enumCase.name, otherCaseName: other.name, typeName: typeName))
        } else {
          casesByTypeName[typeName] = enumCase
        }
      }
      for problem in problems {
        diagnose(Diagnostic(node: element, message: problem))
      }
      isSupported = isSupported && problems.isEmpty
    }
    if cases.isEmpty {
      diagnose(Diagnostic(node: declaration.name, message: MacroDiagnostic.enumWithoutCases))
      return nil
    }
    guard isSupported else { return nil }
    let rawType = declaration.inheritedTypeNames.first
    return EnumCodeGenerator(
      access: GeneratedAccess(modifiers: declaration.modifiers),
      arguments: arguments,
      cases: cases,
      hasStringRawType: rawType == "String" || rawType == "Swift.String",
      equatableConformances: declaration.equatableConformances
    )
  }
}
