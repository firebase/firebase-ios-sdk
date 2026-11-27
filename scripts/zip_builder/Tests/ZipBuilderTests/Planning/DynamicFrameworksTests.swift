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

struct DynamicFrameworksTests {
  @Test func finalNamesFollowAggregateMergeAndRename() throws {
    let packages = ["A": "P", "B": "P", "C": "Q", "D": "Q", "E": "Q", "F": "Q"]
    let frameworks = try JSONDecoder().decode(Config.Frameworks.self, from: Data("""
    { "aggregate": ["P"],
      "merge": { "C": ["D"], "Missing": ["E"], "F": ["F"] },
      "rename": { "C": "Renamed", "E": "P", "F": "Bin" } }
    """.utf8))
    #expect(finalFrameworkNames(packages: packages, frameworks, binaries: ["Bin"]) == [
      "A": "P", "B": "P", // aggregated
      "C": "Renamed", "D": "Renamed", // merged, then renamed
      "E": "E", // its parent is missing, and its new name is taken
      "F": "F", // lists itself, and its new name is a binary's
    ])
    #expect(finalFrameworkNames(packages: packages, Config.Frameworks(), binaries: [])
      == Dictionary(uniqueKeysWithValues: packages.keys.map { ($0, $0) }))
  }

  /// A rename that's already done (old name missing, new name present) moves nothing, just as
  /// `customize` skips it; the final names match the customized plan's frameworks.
  @Test func finalNamesSkipRenamesThatAreAlreadyDone() async throws {
    let frameworks = try JSONDecoder().decode(Config.Frameworks.self, from: Data("""
    { "rename": { "Gone": "A", "Missing": "Bin", "B": "Renamed" } }
    """.utf8))
    #expect(finalFrameworkNames(packages: ["A": "P", "B": "P"], frameworks, binaries: ["Bin"])
      == ["A": "A", "B": "Renamed"])

    let sections = #""frameworks": { "rename": { "OldCore": "CoreC", "OldPrebuilt": "Prebuilt", "#
      + #""Mini-Extras": "Extras" } }"#
    let planned = try await MiniPackage.plan(sections)
    let finalNames = try finalFrameworkNames(
      packages: Dictionary(uniqueKeysWithValues: planned.frameworks.map { ($0.name, $0.package) }),
      MiniPackage.config(sections).frameworks, binaries: Set(planned.binaries.map(\.name))
    )
    let customized = try await MiniPackage.customizedPlan(sections)
    #expect(Set(finalNames.values) == customized.frameworkNames)
  }

  @Test func dynamicTargetsComeFromLinkageProductsAndFinalNames() throws {
    let packages = ["A": "P", "B": "P", "C": "C"]
    let config = try MiniPackage.config(#""frameworks": { "merge": { "A": ["B"] }, "#
      + #""dynamic": ["A"] }"#)
    #expect(dynamicTargets(packages: packages, dynamicProducts: [], config, binaries: [])
      == ["A", "B"])
    #expect(dynamicTargets(packages: packages, dynamicProducts: ["C"], config, binaries: [])
      == ["A", "B", "C"])
    let dynamic = try MiniPackage.config(#""build": { "linkage": "dynamic" }"#)
    #expect(dynamicTargets(packages: packages, dynamicProducts: [], dynamic, binaries: [])
      == ["A", "B", "C"])
  }

  /// `build.linkage: dynamic`: every framework built from source is dynamic, the aggregate
  /// `customize` adds too, and binaries don't change.
  @Test func releaseWideDynamicPlan() async throws {
    let staticPlan = try await MiniPackage.customizedPlan("")
    let plan = try await MiniPackage.customizedPlan(#""build": { "linkage": "dynamic" }"#)
    #expect(plan.frameworks.map(\.name) == staticPlan.frameworks.map(\.name))
    #expect(plan.frameworks.allSatisfy { $0.isDynamic && $0.settings["MACH_O_TYPE"] == "mh_dylib" })
    #expect(plan.frameworks.allSatisfy { $0.settings["DYLIB_INSTALL_NAME_BASE"] == "@rpath" })
    #expect(plan.binaries == staticPlan.binaries)
    #expect(try plan.framework("CoreC").settings["OTHER_LDFLAGS"] == ["-framework", "Security"])
    #expect(try staticPlan.framework("CoreC").settings["OTHER_LDFLAGS"] == nil)

    let aggregated = try await MiniPackage.customizedPlan(
      #""frameworks": { "aggregate": ["Mini"] }, "build": { "linkage": "dynamic" }"#
    )
    let mini = try aggregated.framework("Mini")
    #expect(mini.isDynamic && mini.settings["MACH_O_TYPE"] == "mh_dylib")
    #expect(mini.settings["DYLIB_INSTALL_NAME_BASE"] == "@rpath") // set by `customize`
  }

  /// `frameworks.dynamic` names the framework after renaming, and the linker settings follow.
  @Test func renamedDynamicFramework() async throws {
    let sections = #""frameworks": { "rename": { "CoreC": "Core" }, "dynamic": ["Core"] }"#
    #expect(try await MiniPackage.plan(sections).framework("CoreC").settings["OTHER_LDFLAGS"]
      == ["-framework", "Security"])
    let (plan, warnings) = try await collectingWarnings {
      try await MiniPackage.customizedPlan(sections)
    }
    let core = try plan.framework("Core")
    #expect(core.isDynamic && core.settings["MACH_O_TYPE"] == "mh_dylib")
    #expect(core.settings["OTHER_LDFLAGS"] == ["-framework", "Security"])
    #expect(warnings.isEmpty)

    // The target name no longer works: it isn't a framework in the plan.
    let (byTarget, targetWarnings) = try await collectingWarnings {
      try await MiniPackage.customizedPlan(
        #""frameworks": { "rename": { "CoreC": "Core" }, "dynamic": ["CoreC"] }"#
      )
    }
    #expect(try !byTarget.framework("Core").isDynamic)
    #expect(targetWarnings == [
      "frameworks.dynamic: CoreC isn't a framework in the plan; skipped.",
    ])
  }

  /// A companion merged into a dynamic parent brings its linker settings.
  @Test func mergedCompanionOfADynamicParent() async throws {
    let plan = try await MiniPackage.customizedPlan(
      #""frameworks": { "merge": { "SwiftLib": ["CoreCInternal", "CoreC"] }, "#
        + #""dynamic": ["SwiftLib"] }"#
    )
    let swiftLib = try plan.framework("SwiftLib")
    #expect(swiftLib.isDynamic && swiftLib.settings["MACH_O_TYPE"] == "mh_dylib")
    #expect(swiftLib.settings["OTHER_LDFLAGS"] == ["-framework", "Security"])
  }

  /// An aggregated part brings its linker settings into a dynamic aggregate.
  @Test func aggregatedPartOfADynamicAggregate() async throws {
    let sections = #""frameworks": { "aggregate": ["Mini"], "dynamic": ["Mini"] }"#
    #expect(try await MiniPackage.plan(sections).frameworks.allSatisfy { $0.isDynamic })
    let plan = try await MiniPackage.customizedPlan(sections)
    #expect(plan.frameworks.map(\.name) == ["Mini"])
    let mini = try plan.framework("Mini")
    #expect(mini.isDynamic && mini.settings["MACH_O_TYPE"] == "mh_dylib")
    #expect(mini.settings["OTHER_LDFLAGS"] == ["-framework", "Security"])
  }

  /// `layout.infoPlist` works around App Store checks on static frameworks; dynamic ones keep
  /// what Xcode generates. Bundles still apply.
  @Test func infoPlistValuesOnlyGoToStaticFrameworks() async throws {
    let plan = try await MiniPackage.customizedPlan("""
    "frameworks": { "dynamic": ["CoreC"] },
    "layout": { "privacyBundle": { "*": "{target}_Privacy" },
                "infoPlist": { "MinimumOSVersion": "100.0" } }
    """)
    #expect(try plan.framework("CoreC").layout == Layout(privacyBundle: "CoreC_Privacy"))
    #expect(try plan.framework("HeaderOnly").layout == Layout()) // a `.dynamic` product
    #expect(try plan.framework("Mini-Extras").layout
      == Layout(infoPlist: ["MinimumOSVersion": "100.0"]))
  }

  /// Dynamic frameworks never reuse static cache entries: the model (`isDynamic`) and settings
  /// (`MACH_O_TYPE`) are hashed. HeaderOnly is dynamic either way, so it keeps its fingerprint.
  @Test func dynamicFrameworksHaveTheirOwnFingerprints() async throws {
    let platforms = #""build": { "platforms": ["ios"] }"#
    let staticPlan = try await MiniPackage.customizedPlan(platforms)
    let dynamicPlan = try await MiniPackage.customizedPlan(
      #""build": { "platforms": ["ios"], "linkage": "dynamic" }"#
    )
    func fingerprints(_ plan: Plan) throws -> [String: String] {
      try ZipBuilder.fingerprints(of: plan, packageRoot: MiniPackage.path, xcodeVersion: "Xcode")
    }
    let before = try fingerprints(staticPlan)
    let after = try fingerprints(dynamicPlan)
    #expect(Set(before.keys) == Set(after.keys))
    for name in before.keys.sorted() {
      if name == "HeaderOnly" {
        #expect(after[name] == before[name])
      } else {
        #expect(after[name] != before[name], "\(name)")
      }
    }
  }
}
