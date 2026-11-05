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

/// The module that every generated type reference is qualified with.
let moduleName = "FoundationModelsFake"

/// The arguments passed to a `@Generable` attribute.
struct GenerableArguments {
  /// The `description:` argument, unless it's absent or a `nil` literal.
  var description: ExprSyntax?

  /// The `name:` argument, if present.
  var name: ExprSyntax?

  /// The `representNilExplicitlyInGeneratedContent:` argument, if present.
  var representNilExplicitly: ExprSyntax?

  /// Reads the arguments of `attribute`.
  ///
  /// - Parameter attribute: The `@Generable` attribute.
  init(attribute: AttributeSyntax) {
    guard case .argumentList(let arguments) = attribute.arguments else { return }
    for argument in arguments {
      let expression = argument.expression.trimmed
      switch argument.label?.text {
      case "description":
        if !expression.is(NilLiteralExprSyntax.self) {
          description = expression
        }
      case "name":
        name = expression
      case "representNilExplicitlyInGeneratedContent":
        representNilExplicitly = expression
      default:
        break
      }
    }
  }

  /// The source text of the `explicitNil` flag used by the generated `generatedContent`.
  var explicitNilSource: String {
    representNilExplicitly?.description ?? "false"
  }
}

/// The access modifier that generated members repeat from the attached type.
enum GeneratedAccess {
  /// The type is `public` or `open`.
  case `public`

  /// The type is `package`.
  case package

  /// The type is `internal`, `fileprivate`, or `private`, so members get no modifier.
  case implicit

  /// Determines the access of a declaration from its modifiers.
  ///
  /// - Parameter modifiers: The modifiers of the attached type.
  init(modifiers: DeclModifierListSyntax) {
    let keywords = Set(modifiers.map(\.name.text))
    if keywords.contains("public") || keywords.contains("open") {
      self = .public
    } else if keywords.contains("package") {
      self = .package
    } else {
      self = .implicit
    }
  }

  /// The modifier followed by a space, or an empty string.
  var prefix: String {
    switch self {
    case .public: return "public "
    case .package: return "package "
    case .implicit: return ""
    }
  }
}

extension DeclGroupSyntax {
  /// The names in the inheritance clause, as written.
  var inheritedTypeNames: [String] {
    inheritanceClause?.inheritedTypes.map { $0.type.trimmedDescription } ?? []
  }

  /// Whether the inheritance clause already lists `Generable`.
  var declaresGenerableConformance: Bool {
    inheritedTypeNames.contains { $0 == "Generable" || $0 == "\(moduleName).Generable" }
  }

  /// The `Equatable` and `Hashable` conformances that generated helper types repeat.
  var equatableConformances: [String] {
    inheritedTypeNames.filter {
      ["Equatable", "Hashable", "Swift.Equatable", "Swift.Hashable"].contains($0)
    }
  }
}

/// Returns `text` as a Swift string literal, escaping characters as needed.
///
/// - Parameter text: The string contents.
/// - Returns: The source text of a string literal.
func stringLiteral(_ text: String) -> String {
  StringLiteralExprSyntax(content: text).description
}

extension TokenSyntax {
  /// The identifier text without surrounding backticks.
  var unescapedText: String {
    let text = trimmedDescription
    guard text.count >= 2, text.hasPrefix("`"), text.hasSuffix("`") else { return text }
    return String(text.dropFirst().dropLast())
  }
}

extension TypeSyntax {
  /// The type with implicitly unwrapped optionals (`T!`) rewritten as optionals (`T?`).
  var normalizedForGeneration: TypeSyntax {
    if let implicitlyUnwrapped = self.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
      return TypeSyntax(OptionalTypeSyntax(wrappedType: implicitlyUnwrapped.wrappedType.trimmed))
    }
    return trimmed
  }
}

/// The keywords that must be escaped with backticks to be used as an identifier in a binding or
/// declaration.
private let reservedWords: Set<String> = [
  "Any", "Self", "_", "as", "associatedtype", "await", "break", "case", "catch", "class",
  "continue", "default", "defer", "deinit", "do", "else", "enum", "extension", "fallthrough",
  "false", "fileprivate", "for", "func", "guard", "if", "import", "in", "init", "inout",
  "internal", "is", "let", "nil", "open", "operator", "precedencegroup", "private", "protocol",
  "public", "repeat", "rethrows", "return", "self", "static", "struct", "subscript", "super",
  "switch", "throw", "throws", "true", "try", "typealias", "var", "where", "while",
]

extension String {
  /// The name as an identifier, with backticks if it's a reserved word.
  var escapedAsIdentifier: String {
    reservedWords.contains(self) ? "`\(self)`" : self
  }

  /// The name as an argument label, with backticks for the few keywords labels can't be.
  var escapedAsArgumentLabel: String {
    ["inout", "var", "let"].contains(self) ? "`\(self)`" : self
  }
}
