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

/// `body`'s result and the warnings it printed, collected instead of printed.
func collectingWarnings<T>(_ body: () async throws -> T) async rethrows
  -> (result: T, warnings: [String]) {
  let warnings = Warnings()
  let result = try await Warnings.$collected.withValue(warnings) { try await body() }
  return (result, warnings.all)
}

/// Config mistakes and corner cases in `customize`, on Fixtures/MiniPackage: each warns and is
/// skipped, never leaving a plan that can't be built.
struct CustomizeEdgeCaseTests {
  private func customized(_ sections: String) async throws -> (result: Plan, warnings: [String]) {
    try await collectingWarnings { try await MiniPackage.customizedPlan(sections) }
  }

  @Test func aFrameworkOnNoPlatformIsDropped() async throws {
    let (plan, warnings) = try await customized("""
    "frameworks": { "platforms": { "CoreC": ["watchos"] } },
    "build": { "platforms": ["ios", "macos"] }
    """)
    #expect(plan.frameworks.map(\.name) == ["CoreCInternal", "HeaderOnly", "Mini-Extras",
                                            "SwiftLib"])
    #expect(try plan.framework("CoreCInternal").dependencies.isEmpty)
    #expect(plan.folders.map(\.frameworks) == [
      ["CoreCInternal", "Mini-Extras", "SwiftLib"], [], ["HeaderOnly"], ["Prebuilt"],
    ])
    #expect(warnings.contains("CoreC ships on no platform; dropped."))
  }

  @Test func aBinaryOnNoPlatformIsDropped() async throws {
    // Prebuilt only has iOS slices, but MiniPrebuilt ships on tvOS only.
    let (plan, warnings) = try await customized("""
    "products": { "platforms": { "MiniPrebuilt": ["tvos"] } },
    "build": { "platforms": ["ios", "tvos"] }
    """)
    #expect(plan.binaries.isEmpty)
    #expect(plan.folders.first { $0.name == "MiniPrebuilt" }?.frameworks == [])
    #expect(warnings.contains("Prebuilt ships on no platform; dropped."))
  }

  @Test func aDependencyOnADroppedBinaryIsDropped() async {
    // A depends on B and on Bin (iOS only); the product P only ships on macOS.
    var synthetic = SyntheticPackage.plan
    synthetic.folders = [Folder(name: "P", frameworks: ["A", "B", "Bin"], files: [])]
    let (plan, warnings) = await collectingWarnings {
      synthetic.restrictingPlatforms([:], ["P": [.macos]], release: [.ios, .macos])
    }
    #expect(plan.binaries.isEmpty)
    #expect(plan.frameworks.first { $0.name == "A" }?.dependencies == [Dependency(name: "B")])
    #expect(plan.folders.map(\.frameworks) == [["A", "B"]])
    #expect(warnings == ["Bin ships on no platform; dropped."])
  }

  @Test func aMissingMergeParentStillWarnsAboutItsCompanions() async throws {
    let (plan, warnings) = try await customized("""
    "frameworks": { "merge": { "Gone": ["CoreC", "Nope"] } }
    """)
    #expect(try await plan == MiniPackage.plan())
    #expect(warnings == [
      "frameworks.merge: Gone isn't a framework in the plan; skipped.",
      "frameworks.merge: Nope isn't a framework in the plan; skipped.",
    ])
  }

  /// Warned per key, in name order; `"*"` is allowed in both keys and isn't a name.
  @Test func unknownNamesInBuildModeWarnByKey() async throws {
    let (plan, warnings) = try await customized("""
    "frameworks": { "dynamic": ["Zed", "*", "Abc"] },
    "build": { "swiftVersion": { "*": "5.0", "Bee": "6.0", "Zed": "6.0" } }
    """)
    #expect(warnings == [
      "frameworks.dynamic: Abc isn't a framework in the plan; skipped.",
      "frameworks.dynamic: Zed isn't a framework in the plan; skipped.",
      "build.swiftVersion: Bee isn't a framework in the plan; skipped.",
      "build.swiftVersion: Zed isn't a framework in the plan; skipped.",
    ])
    // `"*"` doesn't make every framework dynamic.
    let unconfigured = try await MiniPackage.plan()
    #expect(plan.frameworks.map(\.isDynamic) == unconfigured.frameworks.map(\.isDynamic))
  }

  @Test func renamingSkipsBinariesAndTakenNames() async throws {
    let (plan, warnings) = try await customized("""
    "frameworks": { "rename": { "Prebuilt": "Pre", "CoreC": "SwiftLib", "HeaderOnly": "Prebuilt",
                                "Mini-Extras": "Extras" } }
    """)
    #expect(plan.binaries.map(\.name) == ["Prebuilt"])
    #expect(plan.frameworks.map(\.name).sorted() ==
      ["CoreC", "CoreCInternal", "Extras", "HeaderOnly", "SwiftLib"])
    #expect(try plan.framework("CoreCInternal").dependencies.map(\.name) == ["CoreC"])
    #expect(try plan.framework("SwiftLib").dependencies.map(\.name) == ["CoreCInternal", "Extras"])
    #expect(plan.folders.first { $0.name == "MiniPrebuilt" }?.frameworks == ["Prebuilt"])
    #expect(warnings.filter { $0.hasPrefix("frameworks.rename") } == [
      "frameworks.rename: SwiftLib is already a framework or binary; CoreC skipped.",
      "frameworks.rename: Prebuilt is already a framework or binary; HeaderOnly skipped.",
      "frameworks.rename: Prebuilt is a prebuilt binary; binaries can't be renamed; skipped.",
    ])
  }

  /// A rename whose old name is missing while its new name is already a framework (CoreC) or a
  /// binary (Prebuilt) is already done: it's skipped without a warning (debug log only). When
  /// neither name is in the plan, it's still a warning, so typos stay visible.
  @Test func aRenameThatsAlreadyDoneIsSkippedQuietly() async throws {
    let (plan, warnings) = try await customized("""
    "frameworks": { "rename": { "OldCore": "CoreC", "OldPrebuilt": "Prebuilt", "Typo": "Nowhere",
                                "Mini-Extras": "Extras" } }
    """)
    #expect(plan.frameworks.map(\.name).sorted() ==
      ["CoreC", "CoreCInternal", "Extras", "HeaderOnly", "SwiftLib"])
    #expect(plan.binaries.map(\.name) == ["Prebuilt"])
    #expect(warnings.filter { $0.hasPrefix("frameworks.rename") } == [
      "frameworks.rename: Typo isn't a framework or binary in the plan; skipped.",
    ])
  }

  @Test func aParentListedAsItsOwnCompanionIsSkipped() async throws {
    let alone = try await customized(#""frameworks": { "merge": { "SwiftLib": ["SwiftLib"] } }"#)
    let unmerged = try await MiniPackage.plan()
    #expect(alone.result == unmerged)
    #expect(alone.warnings == ["frameworks.merge: SwiftLib lists itself as a companion; skipped."])

    let (plan, _) = try await customized("""
    "frameworks": { "merge": { "SwiftLib": ["SwiftLib", "CoreCInternal"] } }
    """)
    #expect(plan.frameworks.map(\.name) == ["CoreC", "HeaderOnly", "Mini-Extras", "SwiftLib"])
    #expect(try plan.framework("SwiftLib").sources.count == 2)
  }

  @Test func unknownNamesInLayoutAndProductsWarn() async throws {
    let (_, warnings) = try await customized("""
    "layout": { "privacyBundle": { "*": "{target}_Privacy", "Nope": "X", "CoreC": "C" },
                "resourceBundles": { "Gone": "R", "SwiftLib": "S" } },
    "products": { "withoutFolder": ["NoProduct", "MiniHeaders"],
                  "extraFrameworks": { "NoFolder": ["CoreC"], "MiniCore": ["HeaderOnly"] },
                  "base": { "product": "Mini", "frameworks": ["CoreC", "Missing"] } }
    """)
    #expect(warnings == [
      "layout.privacyBundle: Nope isn't a framework in the plan; skipped.",
      "layout.resourceBundles: Gone isn't a framework in the plan; skipped.",
      "products.withoutFolder: NoProduct isn't a shipped product; skipped.",
      "products.extraFrameworks: NoFolder isn't a shipped product; skipped.",
      "products.base.frameworks: Missing isn't a framework or binary; skipped.",
    ])
  }

  @Test func baseFrameworksArentCheckedWithoutTheBaseFolder() async throws {
    // As with `--product MiniCore`: the base product isn't shipped, so `base` doesn't apply.
    let (_, warnings) = try await customized("""
    "products": { "base": { "product": "Gone", "frameworks": ["Missing"] } }
    """)
    #expect(warnings.isEmpty)
  }

  @Test func warnSkippedNamesTheKeyAndWhatTheNameIsnt() async {
    let (_, warnings) = await collectingWarnings {
      warnSkipped("Nope", key: "zip.files", kind: "a folder")
    }
    #expect(warnings == ["zip.files: Nope isn't a folder; skipped."])
  }

  /// Every skip warning reads the same way: `<key>: <name> isn't <kind>; skipped.`
  @Test func unknownNamesInOtherKeysWarn() async throws {
    let (_, warnings) = try await customized("""
    "frameworks": { "rename": { "Nope": "New" }, "publicHeaders": { "Gone": ["x"] } },
    "build": { "architectures": { "nowhere": ["arm64"] } },
    "products": { "extraFrameworks": { "MiniCore": ["Missing"] } },
    "zip": { "files": [{ "to": "NoFolder", "files": ["README.md"] }] }
    """)
    #expect(warnings == [
      "frameworks.rename: Nope isn't a framework or binary in the plan; skipped.",
      "frameworks.publicHeaders: Gone isn't a framework in the plan; skipped.",
      "build.architectures: nowhere isn't a destination; skipped.",
      "products.extraFrameworks: Missing isn't a framework or binary; skipped.",
      "zip.files: NoFolder isn't a folder; skipped.",
    ])
  }
}
