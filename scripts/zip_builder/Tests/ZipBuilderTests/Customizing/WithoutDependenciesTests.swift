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

/// `products.withoutDependencies` on Fixtures/MiniPackage: Mini (SwiftLib) reaches CoreCInternal,
/// Mini-Extras and CoreC; MiniCore is CoreC; MiniHeaders is HeaderOnly; MiniPrebuilt is the
/// wrapper `Wrapper`, which forwards to the binary Prebuilt.
struct WithoutDependenciesTests {
  private let setting = #""products": { "withoutDependencies": true }"#

  private func customized(_ sections: String,
                          product: String? = nil) async throws
    -> (result: Plan, warnings: [String]) {
    try await collectingWarnings {
      try await MiniPackage.customizedPlan(sections, product: product)
    }
  }

  @Test func decodesTheSetting() throws {
    #expect(try !MiniPackage.config().products.withoutDependencies)
    #expect(try MiniPackage.config(setting).products.withoutDependencies)
  }

  @Test func offByDefaultLeavesThePlanUnchanged() async throws {
    let plan = try await MiniPackage.plan()
    #expect(plan.folders.allSatisfy { $0.ownFrameworks == nil })
    // An unset `ownFrameworks` isn't encoded, so `plan.json` is the same as before the field.
    let json = try String(decoding: plan.json(), as: UTF8.self)
    #expect(!json.contains("ownFrameworks"))
    #expect(try await MiniPackage.customizedPlan("") == plan)
  }

  @Test func planningRecordsEachProductsOwnFrameworks() async throws {
    let plan = try await MiniPackage.plan(setting)
    #expect(plan.folders.map(\.ownFrameworks) == [
      ["SwiftLib"], ["CoreC"], ["HeaderOnly"],
      // A wrapper counts as what it forwards to.
      ["Prebuilt"],
    ])
    // Folders still hold the whole closure, for restricting platforms.
    #expect(plan.folders[0].frameworks == ["CoreC", "CoreCInternal", "Mini-Extras", "SwiftLib"])
  }

  @Test func foldersHoldOnlyTheProductsOwnFrameworks() async throws {
    let (plan, warnings) = try await customized(setting)
    #expect(plan.folders.map(\.name) == ["Mini", "MiniCore", "MiniHeaders", "MiniPrebuilt"])
    #expect(plan.folders.map(\.frameworks) == [
      ["SwiftLib"], ["CoreC"], ["HeaderOnly"], ["Prebuilt"],
    ])
    #expect(plan.folders.allSatisfy { $0.ownFrameworks == nil })
    // Left-out dependencies are still built, and aren't warned about.
    #expect(plan.frameworks.map(\.name)
      == ["CoreC", "CoreCInternal", "HeaderOnly", "Mini-Extras", "SwiftLib"])
    #expect(warnings.isEmpty)
  }

  @Test func oneProductKeepsItsDependenciesInThePlan() async throws {
    let (plan, warnings) = try await customized(setting, product: "Mini")
    #expect(plan.folders == [Folder(name: "Mini", frameworks: ["SwiftLib"], files: [])])
    #expect(plan.frameworks.map(\.name) == ["CoreC", "CoreCInternal", "Mini-Extras", "SwiftLib"])
    #expect(warnings.isEmpty)
  }

  /// A product's own framework is what its target became: the parent it merged into, the
  /// package's aggregate, or its new name.
  @Test func ownFrameworksFollowMergesAggregatesAndRenames() async throws {
    let merged = try await customized(setting + #", "frameworks": { "merge": "#
      + #"{ "CoreCInternal": ["SwiftLib"] } }"#)
    #expect(merged.result.folders.first?.frameworks == ["CoreCInternal"])
    let aggregated = try await customized(setting + #", "frameworks": { "aggregate": ["Mini"] }"#)
    #expect(aggregated.result.folders.map(\.frameworks) == [
      ["Mini"], ["Mini"], ["Mini"], ["Prebuilt"],
    ])
    let renamed = try await customized(setting + #", "frameworks": { "rename": "#
      + #"{ "SwiftLib": "Swifty" } }"#)
    #expect(renamed.result.folders.first?.frameworks == ["Swifty"])
    #expect([merged, aggregated, renamed].allSatisfy { $0.warnings.isEmpty })
  }

  /// Platforms still come from every product that reaches a framework, so Mini's dependencies
  /// keep Mini's platforms though they're in no folder.
  @Test func platformRestrictionStillSeesTheClosure() async throws {
    let (plan, _) = try await customized("""
    "products": { "withoutDependencies": true, "platforms": { "Mini": ["ios", "tvos"] } },
    "build": { "platforms": ["ios", "macos", "tvos"] }
    """)
    #expect(try plan.framework("CoreCInternal").platforms == [.ios, .tvos])
    #expect(try plan.framework("Mini-Extras").platforms == [.ios, .tvos])
    #expect(plan.folders.first?.frameworks == ["SwiftLib"])
  }

  /// An own framework that ships on no platform stays out; `extraFrameworks` still adds and
  /// `base` still subtracts.
  @Test func otherProductKeysStillApply() async throws {
    let (dropped, _) = try await customized(setting + """
    , "frameworks": { "platforms": { "CoreC": ["watchos"] } },
    "build": { "platforms": ["ios", "macos"] }
    """)
    #expect(dropped.folders.first { $0.name == "MiniCore" }?.frameworks == [])
    let (arranged, _) = try await customized("""
    "products": { "withoutDependencies": true,
                  "extraFrameworks": { "MiniHeaders": ["Mini-Extras"] },
                  "base": { "product": "Mini", "frameworks": ["CoreC"] } }
    """)
    #expect(arranged.folders.map(\.frameworks) == [
      ["SwiftLib"], [], ["HeaderOnly", "Mini-Extras"], ["Prebuilt"],
    ])
  }

  /// Only dependencies left out on purpose go unwarned; a binary dependency stays in the plan.
  @Test func otherFrameworksInNoFolderAreStillWarnedAbout() async throws {
    var synthetic = SyntheticPackage.plan
    synthetic.folders = [Folder(name: "P", frameworks: ["A", "B", "Bin"], files: [],
                                ownFrameworks: ["A"])]
    let products = try MiniPackage.config(setting).products
    let (plan, warnings) = await collectingWarnings {
      synthetic.arrangingFolders(products, files: [])
    }
    #expect(plan.folders == [Folder(name: "P", frameworks: ["A"], files: [])])
    #expect(plan.binaries.map(\.name) == ["Bin"])
    #expect(warnings == ["C is built but isn't in any folder."])

    let (folderless, withoutFolderWarnings) = try await customized("""
    "products": { "withoutDependencies": true, "withoutFolder": ["MiniHeaders"] }
    """)
    #expect(folderless.folders.map(\.name) == ["Mini", "MiniCore", "MiniPrebuilt"])
    #expect(withoutFolderWarnings == ["HeaderOnly is built but isn't in any folder."])
  }
}
