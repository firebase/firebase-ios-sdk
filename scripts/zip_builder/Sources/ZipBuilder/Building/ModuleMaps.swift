/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import RegexBuilder

// The framework module maps `addingGeneratedFiles` writes: one for a generated umbrella with a
// different name, and SwiftPM's custom module maps translated for a framework.

/// The module map Xcode would generate, but with a differently named umbrella header.
func frameworkModuleMap(_ moduleName: String, umbrella: String, hasSwift: Bool) -> String {
  let text = """
  framework module \(moduleName) {
    umbrella header "\(umbrella)"
    export *
    module * { export * }
  }

  """
  return hasSwift ? text + swiftSubmodule(moduleName) : text
}

/// SwiftPM's custom module map (`at`, for errors) as a framework module map: `module Foo` becomes
/// `framework module <moduleName>`, header paths become file names, since `Headers/` is flat, and
/// Swift sources add the Swift submodule. Lines it can't translate (submodules, umbrella
/// directories, `link`, `requires`, …) throw.
func frameworkModuleMap(rewriting text: String, at path: Path, moduleName: String,
                        publicHeaders: Set<String>, hasSwift: Bool) throws -> String {
  // The line shapes a framework module map can keep, matched after `normalizedModuleMapLine`.
  let opening = Regex { // `module foo [system] {`, or `framework module foo {`
    Optionally { "framework " }
    "module "
    OneOrMore(.word) // the original module name
    Capture { // the attributes, e.g. ` [system] [extern_c]`
      ZeroOrMore { " ["; OneOrMore(.word); "]" }
    }
    " {"
  }
  let export = ChoiceOf {
    Regex { // `export *`, `export Foo.Bar`
      "export "
      ChoiceOf { "*"; OneOrMore(CharacterClass(.word, .anyOf("."))) }
    }
    "module * { export * }"
  }
  // `header "A.h"`, `umbrella header "A.h"`, `exclude header "A.h"`
  let header = Regex {
    Optionally {
      Capture { ChoiceOf { "umbrella"; "exclude" } }
      " "
    }
    "header \""
    Capture { OneOrMore(CharacterClass.anyOf("\"").inverted) } // the path
    "\""
  }

  var lines: [String] = []
  var isClosed = false
  for rawLine in text.components(separatedBy: .newlines) {
    let line = normalizedModuleMapLine(rawLine)
    guard !line.isEmpty else {
      continue
    }

    guard !isClosed else {
      throw ZipBuilderError("\(path): has a second top level declaration `\(line)`.")
    }

    let unsupported = ZipBuilderError(
      "\(path): can't translate `\(line)` into a framework module map."
    )
    if lines.isEmpty {
      guard let (_, attributes) = line.wholeMatch(of: opening)?.output else {
        throw unsupported
      }

      lines.append("framework module \(moduleName)\(attributes) {")
    } else if line == "}" {
      lines.append("}")
      isClosed = true
    } else if line.wholeMatch(of: export) != nil {
      lines.append("  " + line)
    } else if let (_, modifier, headerPath) = line.wholeMatch(of: header)?.output {
      let name = fileName(String(headerPath))
      guard modifier == "exclude" || publicHeaders.contains(name) else {
        throw ZipBuilderError("\(path): \(headerPath) isn't a public header of \(moduleName).")
      }

      let kind = modifier.map { "\($0) header" } ?? "header"
      lines.append("  \(kind) \"\(name)\"")
    } else {
      throw unsupported
    }
  }
  guard isClosed else {
    throw ZipBuilderError("\(path): no complete module declaration.")
  }

  let result = lines.joined(separator: "\n") + "\n"
  return hasSwift ? result + swiftSubmodule(moduleName) : result
}

/// A module map line without its comment, with braces spaced out and whitespace collapsed
/// outside quotes, so each line shape has one spelling: `module X{` and `module  X {` both
/// become `module X {`. Quoted text (header paths) is kept exactly as written, and `//` inside
/// quotes doesn't start a comment.
func normalizedModuleMapLine(_ line: String) -> String {
  var parts: [String] = []
  for (index, part) in line.split(separator: "\"", omittingEmptySubsequences: false).enumerated() {
    guard index.isMultiple(of: 2) else {
      // inside quotes
      parts.append(String(part))
      continue
    }

    let code = part.components(separatedBy: "//") // outside quotes, `//` starts a comment
    parts.append(code[0]
      .replacing("{", with: " { ")
      .replacing("}", with: " } ")
      .replacing(OneOrMore(.whitespace), with: " "))
    if code.count > 1 {
      break // the rest of the line is the comment
    }
  }

  return parts.joined(separator: "\"").trimmingCharacters(in: .whitespaces)
}

/// The submodule for the Swift part's generated `-Swift.h` header, as Xcode writes it.
private func swiftSubmodule(_ moduleName: String) -> String {
  """

  module \(moduleName).Swift {
    header "\(moduleName)-Swift.h"
    requires objc
  }

  """
}
