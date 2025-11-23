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
    // 1. Get all variable declarations from the member block.
    let varDecls = declaration.memberBlock.members
      .compactMap { $0.decl.as(VariableDeclSyntax.self) }

    // 2. Process each declaration to extract schema properties from its bindings.
    let schemaProperties = try varDecls.flatMap { varDecl -> [String] in
      // For declarations like `let a, b: String`, the type annotation is on the last binding.
      let typeAnnotationFromDecl = varDecl.bindings.last?.typeAnnotation

      return try varDecl.bindings.compactMap { binding -> String? in
        // 3. Filter out computed properties. Stored properties do not have a getter/setter block.
        guard binding.accessorBlock == nil else {
          return nil
        }

        // 4. Get the property's name. Skip complex patterns like tuples.
        guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
          return nil
        }

        // 5. Determine the property's type. It can be on the binding itself or on the declaration.
        guard let type = binding.typeAnnotation?.type ?? typeAnnotationFromDecl?.type else {
          throw MacroError.missingExplicitType(for: name)
        }

        // 6. Generate the schema string for this property.
        return try "\"\(name)\": \(schema(for: type))"
      }
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
      InheritedTypeSyntax(type: TypeSyntax("FirebaseAILogic.FirebaseGenerable"))
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

private enum MacroError: Error, CustomStringConvertible {
  case unsupportedType(Syntax)
  case missingExplicitType(for: String)

  var description: String {
    switch self {
    case let .unsupportedType(syntax):
      return "Unsupported type syntax: \(syntax)"
    case let .missingExplicitType(name):
      return "Property '\(name)' must have an explicit type annotation to be used with @FirebaseGenerable."
    }
  }
}
