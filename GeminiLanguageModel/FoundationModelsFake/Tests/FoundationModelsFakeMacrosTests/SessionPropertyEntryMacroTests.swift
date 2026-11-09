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

import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import FoundationModelsFakeMacros

/// Tests for the `@SessionPropertyEntry` macro's expansion.
@Suite("SessionPropertyEntry macro")
struct SessionPropertyEntryMacroTests {
  /// The macro under test.
  static let macroSpecs: [String: MacroSpec] = [
    "SessionPropertyEntry": MacroSpec(type: SessionPropertyEntryMacro.self)
  ]

  @Test
  func expandsToAccessorsAndAPrivateNonisolatedKey() {
    let source = """
      extension SessionPropertyValues {
          @SessionPropertyEntry var counter: Int = 0
      }
      """

    let expandedSource = """
      extension SessionPropertyValues {
          var counter: Int {
              get {
                self[__Key_counter.self]
              }
              set {
                self[__Key_counter.self] = newValue
              }
              _modify {
                yield &self[__Key_counter.self]
              }
          }

          private nonisolated struct __Key_counter: FoundationModelsFake.SessionPropertyKey {
            @FoundationModelsFake.__SessionPropertyEntryDefaultValue
            static var defaultValue: Int = 0
          }
      }
      """

    assertMacroExpansion(
      source,
      expandedSource: expandedSource,
      macroSpecs: Self.macroSpecs,
      failureHandler: { failure in
        Issue.record(Comment(rawValue: failure.message))
      }
    )
  }
}
