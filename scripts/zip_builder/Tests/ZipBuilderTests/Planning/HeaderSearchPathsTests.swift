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

struct HeaderSearchPathsTests {
  /// Ships CppUser, which depends on CppBase and Mini-Extras, as a product.
  private let cppProduct =
    #""products": { "add": [{ "name": "MiniCpp", "targets": ["CppUser"] }] }"#

  private func searchPaths(of name: String, in plan: Plan) throws -> [String] {
    try plan.framework(name).settings["HEADER_SEARCH_PATHS"]?.list ?? []
  }

  /// A framework with C++ sources also searches the include directories of its C and C++
  /// dependencies whose frameworks can't serve their headers: CppBase's are under `cpp_base/`,
  /// and Mini-Extras' at the top of its include directory.
  @Test func cppSourcesSearchIncludeDirectoriesNoFrameworkServes() async throws {
    let plan = try await MiniPackage.plan(cppProduct)
    #expect(try searchPaths(of: "CppUser", in: plan) == [
      "Sources/CppUser", "Sources/CppUser/include", "Sources/CppBase/include",
      "Sources/MiniExtras/include",
    ])
    #expect(try searchPaths(of: "CppBase", in: plan) == [
      "Sources/CppBase",
      "Sources/CppBase/include",
    ])
  }

  /// Swift and Objective-C dependents keep the usual rule: dependencies' headers come from their
  /// frameworks.
  @Test func otherLanguagesOnlySearchTheirOwnDirectories() async throws {
    let plan = try await MiniPackage.plan(cppProduct)
    #expect(try searchPaths(of: "SwiftLib", in: plan) == ["Sources/SwiftLib"]) // → Mini-Extras
    #expect(try searchPaths(of: "CoreCInternal", in: plan)
      == ["Sources/CoreCInternal", "Sources/CoreCInternal/Public"])
  }

  /// Renamed to `cpp_base`, CppBase's framework serves `<cpp_base/value.h>` itself, so its include
  /// directory isn't searched: the framework name is the one after renaming.
  @Test func aFrameworkThatServesTheHeadersIsUsedInstead() async throws {
    let plan = try await MiniPackage.plan(
      cppProduct + #", "frameworks": { "rename": { "CppBase": "cpp_base" } }"#
    )
    #expect(try searchPaths(of: "CppUser", in: plan)
      == ["Sources/CppUser", "Sources/CppUser/include", "Sources/MiniExtras/include"])
  }
}
