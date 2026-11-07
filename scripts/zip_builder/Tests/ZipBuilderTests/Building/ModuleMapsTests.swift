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
import Testing
@testable import ZipBuilder

/// The framework module maps: SwiftPM custom module maps translated, and their lines normalized.
struct ModuleMapsTests {
  @Test func customModuleMapBecomesAFrameworkModuleMap() throws {
    let text = """
    // A comment.
    module Old [system] {
        umbrella header "Old.h"
        header "sub/Extra.h" // trailing comment
        exclude   header "Private.h"
        export *
    }
    """
    let translated = try frameworkModuleMap(rewriting: text, at: "m", moduleName: "New",
                                            publicHeaders: ["Old.h", "Extra.h"], hasSwift: true)
    #expect(translated == """
    framework module New [system] {
      umbrella header "Old.h"
      header "Extra.h"
      exclude header "Private.h"
      export *
    }

    module New.Swift {
      header "New-Swift.h"
      requires objc
    }

    """)
  }

  @Test(arguments: [
    ("module X{", "module X {"),
    ("  module  *  {  export * }  ", "module * { export * }"),
    ("   header   \"My  File.h\"  // a comment", "header \"My  File.h\""),
    ("header \"a//b.h\" // a comment", "header \"a//b.h\""),
    ("// only a comment", ""),
  ])
  func normalizesModuleMapLines(line: String, expected: String) {
    #expect(normalizedModuleMapLine(line) == expected)
  }

  @Test func quotedHeaderPathsAreKeptAsWritten() throws {
    let text = """
    module A {
      header "My  File.h"
      header "dir//B.h" // `//` inside quotes isn't a comment
    }
    """
    let translated = try frameworkModuleMap(rewriting: text, at: "m", moduleName: "A",
                                            publicHeaders: ["My  File.h", "B.h"],
                                            hasSwift: false)
    #expect(translated == """
    framework module A {
      header "My  File.h"
      header "B.h"
    }

    """)
  }

  @Test func unbalancedQuotesFail() {
    let error = #expect(throws: ZipBuilderError.self) {
      try frameworkModuleMap(rewriting: "module A {\n  header \"A.h\n}\n", at: "m",
                             moduleName: "A", publicHeaders: ["A.h"], hasSwift: false)
    }
    #expect(error?.description.contains("can't translate") == true)
  }

  /// After the module closes, any line is a second declaration, even one that couldn't be
  /// translated anyway.
  @Test func aSecondDeclarationFails() {
    let error = #expect(throws: ZipBuilderError.self) {
      try frameworkModuleMap(rewriting: "module A {\n}\nlink \"z\"\n", at: "m", moduleName: "A",
                             publicHeaders: [], hasSwift: false)
    }
    #expect(error?.description == "m: has a second top level declaration `link \"z\"`.")
  }

  @Test func untranslatableModuleMapsFail() {
    let bodies = [#"link "z""#, #"umbrella "dir""#, "explicit module Sub {", "requires objc",
                  #"header "NotPublic.h""#]
    let texts = bodies.map { "module A {\n  \($0)\n}\n" }
      + ["module A {\n}\nmodule B {\n}\n", "module A {\n  header \"A.h\"\n", "module A\n{\n}\n"]
    for text in texts {
      #expect(throws: ZipBuilderError.self) {
        try frameworkModuleMap(rewriting: text, at: "m", moduleName: "A", publicHeaders: ["A.h"],
                               hasSwift: false)
      }
    }
  }
}
