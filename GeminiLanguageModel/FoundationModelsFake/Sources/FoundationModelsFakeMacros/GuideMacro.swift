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
import SwiftSyntaxMacros

/// Implements `@Guide`, which annotates a stored property of a `@Generable` type.
///
/// The macro expands to nothing: `@Generable` reads the description and guides from the
/// attribute. It only checks that it's attached to a stored instance property.
struct GuideMacro: PeerMacro {
  /// Validates the attachment of `@Guide` and adds no peers.
  ///
  /// - Parameters:
  ///   - node: The `@Guide` attribute.
  ///   - declaration: The attached declaration.
  ///   - context: The macro expansion context.
  /// - Returns: An empty array.
  static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    if !isStoredInstanceProperty(declaration) {
      context.diagnose(Diagnostic(node: node, message: MacroDiagnostic.guideRequiresStoredProperty))
    }
    return []
  }

  /// Whether `declaration` declares stored instance properties.
  ///
  /// - Parameter declaration: The attached declaration.
  /// - Returns: `false` for non-variable declarations and static or computed properties.
  private static func isStoredInstanceProperty(_ declaration: some DeclSyntaxProtocol) -> Bool {
    guard let variable = declaration.as(VariableDeclSyntax.self) else { return false }
    let modifiers = Set(variable.modifiers.map(\.name.text))
    guard modifiers.isDisjoint(with: ["static", "class"]) else { return false }
    return variable.bindings.allSatisfy { binding in
      guard let accessorBlock = binding.accessorBlock else { return true }
      return !accessorBlock.declaresComputedProperty
    }
  }
}
