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

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when
// cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(FirebaseAILogicMacros)
  import FirebaseAILogicMacros
#endif

final class GenerableMacroTests: XCTestCase {
  #if canImport(FirebaseAILogicMacros)
    let testMacros: [String: Macro.Type] = [
      "stringify": StringifyMacro.self,
    ]
  #else
    let testMacros = [String: Macro.Type]()

    override func setUpWithError() throws {
      throw XCTSkip("Macros are only supported when running tests for the host platform.")
    }
  #endif // canImport(FirebaseAILogicMacros)

  func testMacro() throws {
    assertMacroExpansion(
      """
      #stringify(a + b)
      """,
      expandedSource: """
      (a + b, "a + b")
      """,
      macros: testMacros
    )
  }

  func testMacroWithStringLiteral() throws {
    assertMacroExpansion(
      #"""
      #stringify("Hello, \(name)")
      """#,
      expandedSource: #"""
      ("Hello, \(name)", #""Hello, \(name)""#)
      """#,
      macros: testMacros
    )
  }
}
