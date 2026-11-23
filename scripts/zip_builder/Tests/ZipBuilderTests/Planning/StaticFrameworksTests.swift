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

/// `frameworks.static`: frameworks a dynamic release keeps static.
struct StaticFrameworksTests {
  private let dynamicRelease = #""build": { "linkage": "dynamic" }"#

  @Test func staticTargetsComeFromFinalNamesInADynamicRelease() throws {
    let packages = ["A": "P", "B": "P", "C": "C", "D": "D"]
    let frameworks = #""frameworks": { "merge": { "A": ["B"] }, "rename": { "D": "E" }, "#
      + #""static": ["A", "E"] }"#
    let dynamic = try MiniPackage.config(frameworks + ", " + dynamicRelease)
    #expect(dynamicTargets(packages: packages, dynamicProducts: [], dynamic, binaries: [])
      == ["C"])
    // A `.dynamic` product's module stays dynamic.
    #expect(dynamicTargets(packages: packages, dynamicProducts: ["B"], dynamic, binaries: [])
      == ["B", "C"])
    // Aggregated parts follow their aggregate.
    let aggregated = try MiniPackage.config(
      #""frameworks": { "aggregate": ["P"], "static": ["P"] }, "# + dynamicRelease
    )
    #expect(dynamicTargets(packages: packages, dynamicProducts: [], aggregated, binaries: [])
      == ["C", "D"])
    // A static release ignores the list.
    let staticRelease = try MiniPackage.config(frameworks)
    #expect(dynamicTargets(packages: packages, dynamicProducts: [], staticRelease, binaries: [])
      .isEmpty)
  }

  /// A listed framework stays static, without translated linker settings; the plan records it.
  @Test func aListedFrameworkStaysStaticInADynamicRelease() async throws {
    let (plan, warnings) = try await collectingWarnings {
      try await MiniPackage.customizedPlan(
        #""frameworks": { "static": ["CoreC"] }, "# + dynamicRelease
      )
    }
    let coreC = try plan.framework("CoreC")
    #expect(!coreC.isDynamic && coreC.settings["MACH_O_TYPE"] != "mh_dylib")
    #expect(coreC.settings["OTHER_LDFLAGS"] == nil)
    #expect(plan.frameworks.filter { $0.name != "CoreC" }.allSatisfy { $0.isDynamic })
    #expect(plan.keptStatic == ["CoreC"])
    #expect(warnings.isEmpty)
  }

  /// A static release ignores `frameworks.static`, and a release without it keeps its plan.
  @Test func plansWithoutKeptFrameworksDontChange() async throws {
    let staticPlan = try await MiniPackage.customizedPlan("")
    let listed = try await MiniPackage.customizedPlan(#""frameworks": { "static": ["CoreC"] }"#)
    #expect(try listed.json() == staticPlan.json())
    let dynamicPlan = try await MiniPackage.customizedPlan(dynamicRelease)
    #expect(dynamicPlan.keptStatic == nil)
    #expect(try !String(decoding: dynamicPlan.json(), as: UTF8.self).contains("keptStatic"))
  }

  /// A merged companion stays static with its parent, and brings no linker settings.
  @Test func mergedCompanionOfAStaticParent() async throws {
    let sections = #""frameworks": { "merge": { "SwiftLib": ["CoreCInternal", "CoreC"] }, "#
      + #""static": ["SwiftLib"] }, "# + dynamicRelease
    let planned = try await MiniPackage.plan(sections)
    for name in ["SwiftLib", "CoreCInternal", "CoreC"] {
      #expect(try !planned.framework(name).isDynamic, "\(name)")
    }
    let plan = try await MiniPackage.customizedPlan(sections)
    let swiftLib = try plan.framework("SwiftLib")
    #expect(!swiftLib.isDynamic && swiftLib.settings["OTHER_LDFLAGS"] == nil)
    #expect(try plan.framework("Mini-Extras").isDynamic)
    #expect(plan.keptStatic == ["SwiftLib"])
  }

  /// An aggregated part stays static with its aggregate.
  @Test func aggregatedPartOfAStaticAggregate() async throws {
    let sections = #""frameworks": { "aggregate": ["Mini"], "static": ["Mini"] }, "#
      + dynamicRelease
    let planned = try await MiniPackage.plan(sections)
    // HeaderOnly is in a `.dynamic` product.
    #expect(planned.frameworks.filter { $0.name != "HeaderOnly" }.allSatisfy { !$0.isDynamic })
    let (plan, warnings) = try await collectingWarnings {
      try await MiniPackage.customizedPlan(sections)
    }
    #expect(plan.frameworks.map(\.name) == ["Mini"])
    #expect(try !plan.framework("Mini").isDynamic)
    #expect(plan.keptStatic == ["Mini"])
    #expect(warnings.isEmpty)
  }

  /// `frameworks.static` names the framework after renaming; the target name isn't one.
  @Test func renamedStaticFramework() async throws {
    let sections = #""frameworks": { "rename": { "CoreC": "Core" }, "static": ["Core"] }, "#
      + dynamicRelease
    #expect(try await MiniPackage.plan(sections).framework("CoreC").settings["OTHER_LDFLAGS"]
      == nil)
    #expect(try await !MiniPackage.customizedPlan(sections).framework("Core").isDynamic)

    let (byTarget, warnings) = try await collectingWarnings {
      try await MiniPackage.customizedPlan(
        #""frameworks": { "rename": { "CoreC": "Core" }, "static": ["CoreC"] }, "#
          + dynamicRelease
      )
    }
    #expect(try byTarget.framework("Core").isDynamic)
    #expect(warnings == ["frameworks.static: CoreC isn't a framework in the plan; skipped."])
  }

  /// Unknown names warn and are skipped whatever the linkage, as in `frameworks.dynamic`.
  @Test(arguments: ["static", "dynamic"])
  func unknownNamesWarn(linkage: String) async throws {
    let (plan, warnings) = try await collectingWarnings {
      try await MiniPackage.customizedPlan(
        #""frameworks": { "static": ["Zed", "Zed"] }, "build": { "linkage": "\#(linkage)" }"#
      )
    }
    #expect(warnings == ["frameworks.static: Zed isn't a framework in the plan; skipped."])
    #expect(plan.keptStatic == nil)
  }

  /// A `.dynamic` product's framework stays dynamic: its package's author declared it so.
  @Test func aDynamicProductWins() async throws {
    let sections = #""frameworks": { "static": ["HeaderOnly"] }"#
    let (plan, warnings) = try await collectingWarnings {
      try await MiniPackage.customizedPlan(sections + ", " + dynamicRelease)
    }
    #expect(try plan.framework("HeaderOnly").isDynamic)
    #expect(plan.keptStatic == nil)
    #expect(warnings == [
      "frameworks.static: HeaderOnly is in a .dynamic library product, so it stays dynamic; "
        + "ignored.",
    ])
    // A static release ignores the list, so there's nothing to warn about.
    let (_, staticWarnings) = try await collectingWarnings {
      try await MiniPackage.customizedPlan(sections)
    }
    #expect(staticWarnings.isEmpty)
  }

  /// A kept framework is planned as in a static release, so it shares the static release's cache
  /// entries; the plan's `keptStatic` isn't hashed.
  @Test func aKeptFrameworkHasTheStaticFingerprint() async throws {
    let platforms = #""build": { "platforms": ["ios"] }"#
    let staticPlan = try await MiniPackage.customizedPlan(platforms)
    let dynamicPlan = try await MiniPackage.customizedPlan(
      #""frameworks": { "static": ["CoreC"] }, "build": { "platforms": ["ios"], "#
        + #""linkage": "dynamic" }"#
    )
    func fingerprints(_ plan: Plan) throws -> [String: String] {
      try ZipBuilder.fingerprints(of: plan, packageRoot: MiniPackage.path, xcodeVersion: "Xcode")
    }
    let before = try fingerprints(staticPlan)
    let after = try fingerprints(dynamicPlan)
    #expect(after["CoreC"] == before["CoreC"])
    #expect(after["CoreCInternal"] != before["CoreCInternal"])
  }
}
