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

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct FirebaseGenerableMacro: MemberMacro, ExtensionMacro {
  public static func expansion<Declaration, Context>(of node: SwiftSyntax.AttributeSyntax,
                                                     providingMembersOf declaration: Declaration,
                                                     in context: Context) throws
    -> [SwiftSyntax.DeclSyntax]
    where Declaration: SwiftSyntax.DeclGroupSyntax,
    Context: SwiftSyntaxMacros.MacroExpansionContext {
    let properties = declaration.memberBlock.members.compactMap {
      $0.decl.as(VariableDeclSyntax.self)
    }

    let schemaProperties: [String] = try properties.map { property in
      let (name, type) = try property.toNameAndType()
      return try """
      "\(name)": \(schema(for: type))
      """
    }

    return [
      """
      public static var firebaseGenerationSchema: FirebaseAILogic.Schema {
        .object(properties: [
          \(raw: schemaProperties.joined(separator: ",\n"))
        ])
      }
      """,
    ]
  }

  public static func expansion(of node: SwiftSyntax.AttributeSyntax,
                               attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
                               providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
                               conformingTo protocols: [SwiftSyntax.TypeSyntax],
                               in context: some SwiftSyntaxMacros
                                 .MacroExpansionContext) throws
    -> [SwiftSyntax.ExtensionDeclSyntax] {
    if protocols.isEmpty {
      return []
    }

    let inheritanceClause = InheritanceClauseSyntax {
      for protocolType in protocols {
        InheritedTypeSyntax(type: protocolType)
      }
    }

    let extensionDecl = ExtensionDeclSyntax(
      extendedType: type.trimmed,
      inheritanceClause: inheritanceClause
    ) {
      // Empty member block
    }

    return [extensionDecl]
  }

  private static func schema(for type: TypeSyntax) throws -> String {
    let schemaPrefix = "FirebaseAILogic.Schema"
    if let type = type.as(IdentifierTypeSyntax.self) {
      switch type.name.text {
      case "String":
        return "\(schemaPrefix).string()"
      case "Int", "Int8", "Int16", "Int32", "Int64",
           "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
        return "\(schemaPrefix).integer()"
      case "Float":
        return "\(schemaPrefix).float()"
      case "Double":
        return "\(schemaPrefix).double()"
      case "Bool":
        return "\(schemaPrefix).boolean()"
      default:
        // For a custom type, generate a call to its static schema property.
        return "\(type).firebaseGenerationSchema"
      }
    } else if let type = type.as(OptionalTypeSyntax.self) {
      // For an optional type, get the wrapped type's schema and make it nullable.
      let wrappedSchema = try schema(for: type.wrappedType)
      return "(\(wrappedSchema)).asNullable()"
    } else if let type = type.as(ArrayTypeSyntax.self) {
      return try """
      \(schemaPrefix).array(items: \(schema(for: type.element)))
      """
    }

    throw MacroError.unsupportedType(Syntax(type))
  }
}

private extension VariableDeclSyntax {
  func toNameAndType() throws -> (String, TypeSyntax) {
    guard let binding = bindings.first else {
      throw MacroError.unsupportedType(Syntax(self))
    }
    guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
      throw MacroError.unsupportedType(Syntax(self))
    }
    guard let type = binding.typeAnnotation?.type else {
      throw MacroError.unsupportedType(Syntax(self))
    }

    return (name, type)
  }
}

private enum MacroError: Error, CustomStringConvertible {
  case unsupportedType(Syntax)

  var description: String {
    switch self {
    case let .unsupportedType(type):
      return "Unsupported type: \(type)"
    }
  }
}
