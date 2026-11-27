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

import Basics
import Foundation
@preconcurrency import PackageGraph
@preconcurrency import PackageModel
import Testing
@testable import ZipBuilder

/// `unsupportedFeature` (MakePlan.swift) on synthetic modules, for what Fixtures/MiniPackage
/// can't express cheaply: a real macro target needs swift-syntax. The rest is in `MakePlanTests`.
struct UnsupportedFeatureTests {
  /// A module with no files, depending directly on `dependencies`.
  private func module(_ name: String, type: PackageModel.Module.Kind,
                      dependencies: [ResolvedModule] = []) throws -> ResolvedModule {
    try SyntheticModule.module(name, type: type,
                               dependencies: dependencies.map { .module($0, conditions: []) })
  }

  @Test func macroDependenciesAreUnsupported() throws {
    let macros = try module("Macros", type: .macro)
    #expect(try unsupportedFeature(of: module("UsesMacros", type: .library,
                                              dependencies: [macros])) == "macros aren't supported")
    let library = try module("Library", type: .library)
    #expect(try unsupportedFeature(of: module("UsesLibrary", type: .library,
                                              dependencies: [library])) == nil)
  }

  /// A macro reached through a product is caught too, not just a direct macro module.
  @Test func macrosThroughAProductAreUnsupported() throws {
    let product = try SyntheticModule.product("Macros", [
      SyntheticModule.module("MacroImpl", type: .macro),
    ])
    let module = try SyntheticModule.module("UsesMacros",
                                            dependencies: [.product(product, conditions: [])])
    #expect(unsupportedFeature(of: module) == "macros aren't supported")
  }
}
