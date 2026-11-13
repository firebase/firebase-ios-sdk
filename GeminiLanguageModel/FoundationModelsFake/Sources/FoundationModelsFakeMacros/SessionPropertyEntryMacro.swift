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

/// Diagnostics emitted by `@SessionPropertyEntry` and `@__SessionPropertyEntryDefaultValue`.
enum SessionPropertyMacroDiagnostic: DiagnosticMessage {
  /// `@SessionPropertyEntry` is attached to something other than a single stored instance `var`
  /// with an explicit type and initializer.
  case invalidSessionPropertyEntryDeclaration

  /// `@__SessionPropertyEntryDefaultValue` is attached to a declaration without an initializer.
  case missingDefaultValueInitializer

  /// The human-readable diagnostic text.
  var message: String {
    switch self {
    case .invalidSessionPropertyEntryDeclaration:
      return
        "'@SessionPropertyEntry' must be attached to an instance 'var' property with an explicit "
        + "type annotation and default value initializer."
    case .missingDefaultValueInitializer:
      return
        "'@__SessionPropertyEntryDefaultValue' requires a property declaration with a default "
        + "value initializer."
    }
  }

  /// A stable identifier for the diagnostic.
  var diagnosticID: MessageID {
    let id: String
    switch self {
    case .invalidSessionPropertyEntryDeclaration:
      id = "invalidSessionPropertyEntryDeclaration"
    case .missingDefaultValueInitializer:
      id = "missingDefaultValueInitializer"
    }
    return MessageID(domain: "FoundationModelsFakeMacros", id: id)
  }

  /// The severity of the diagnostic.
  var severity: DiagnosticSeverity {
    .error
  }
}

/// Implements `@SessionPropertyEntry`, which synthesizes `get`, `set`, and `_modify` accessors
/// forwarding to `self[__Key_<name>.self]` and a peer `SessionPropertyKey` struct.
struct SessionPropertyEntryMacro: AccessorMacro, PeerMacro {
  /// Synthesizes `get`, `set`, and `_modify` accessors for a `@SessionPropertyEntry` property.
  ///
  /// - Parameters:
  ///   - node: The `@SessionPropertyEntry` attribute.
  ///   - declaration: The attached property declaration.
  ///   - context: The macro expansion context.
  /// - Returns: The generated `get`, `set`, and `_modify` accessors.
  static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    guard let parsed = parseEntry(from: declaration) else {
      context.diagnose(
        Diagnostic(
          node: node,
          message: SessionPropertyMacroDiagnostic.invalidSessionPropertyEntryDeclaration
        )
      )
      return []
    }
    let keyName = "__Key_\(parsed.name)"
    return [
      """
      get {
        self[\(raw: keyName).self]
      }
      """,
      """
      set {
        self[\(raw: keyName).self] = newValue
      }
      """,
      """
      _modify {
        yield &self[\(raw: keyName).self]
      }
      """,
    ]
  }

  /// Synthesizes the private `__Key_<name>: FoundationModelsFake.SessionPropertyKey` peer
  /// struct for a `@SessionPropertyEntry` property.
  ///
  /// - Parameters:
  ///   - node: The `@SessionPropertyEntry` attribute.
  ///   - declaration: The attached property declaration.
  ///   - context: The macro expansion context.
  /// - Returns: The generated peer `SessionPropertyKey` struct.
  static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // The accessor macro already reports diagnostics for invalid declarations.
    guard let parsed = parseEntry(from: declaration) else {
      return []
    }
    let keyName = "__Key_\(parsed.name)"
    let peerSource = """
      private nonisolated struct \(keyName): \(moduleName).SessionPropertyKey {
        @\(moduleName).__SessionPropertyEntryDefaultValue
        static var defaultValue: \(parsed.type.trimmedDescription) = \(parsed.initializer.trimmedDescription)
      }
      """
    return [DeclSyntax(stringLiteral: peerSource)]
  }

  /// Parsed components of a valid `@SessionPropertyEntry` property declaration.
  private struct ParsedEntry {
    /// The unescaped identifier name of the property.
    let name: String

    /// The explicit type annotation of the property.
    let type: TypeSyntax

    /// The default value initializer expression of the property.
    let initializer: ExprSyntax
  }

  /// Extracts the property name, type annotation, and initializer expression from `declaration`.
  ///
  /// - Parameter declaration: The declaration to inspect.
  /// - Returns: The parsed entry components, or `nil` if invalid.
  private static func parseEntry(from declaration: some DeclSyntaxProtocol) -> ParsedEntry? {
    guard let variable = declaration.as(VariableDeclSyntax.self),
      variable.bindingSpecifier.tokenKind == .keyword(.var),
      variable.bindings.count == 1,
      let binding = variable.bindings.first,
      binding.accessorBlock == nil,
      let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self),
      let typeAnnotation = binding.typeAnnotation,
      let initializer = binding.initializer
    else {
      return nil
    }
    let modifiers = Set(variable.modifiers.map(\.name.text))
    guard modifiers.isDisjoint(with: ["static", "class"]) else {
      return nil
    }
    return ParsedEntry(
      name: identifierPattern.identifier.unescapedText,
      type: typeAnnotation.type.trimmed,
      initializer: initializer.value.trimmed
    )
  }
}

/// Implements `@__SessionPropertyEntryDefaultValue`, which rewrites a `static var defaultValue`
/// declaration with an initializer into a computed getter returning that initializer expression.
struct SessionPropertyEntryDefaultValueMacro: AccessorMacro {
  /// Synthesizes a computed `get` accessor returning the property's initializer expression.
  ///
  /// - Parameters:
  ///   - node: The `@__SessionPropertyEntryDefaultValue` attribute.
  ///   - declaration: The attached property declaration.
  ///   - context: The macro expansion context.
  /// - Returns: The generated `get` accessor.
  static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    guard let variable = declaration.as(VariableDeclSyntax.self),
      let binding = variable.bindings.first,
      let initializer = binding.initializer
    else {
      context.diagnose(
        Diagnostic(
          node: node,
          message: SessionPropertyMacroDiagnostic.missingDefaultValueInitializer
        )
      )
      return []
    }
    let expr = initializer.value.trimmed
    return [
      """
      get {
        \(expr)
      }
      """
    ]
  }
}
