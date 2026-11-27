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

/// Synthetic SwiftPM modules and products, for what Fixtures/MiniPackage can't express cheaply
/// (a macro target, a dependency on another package's product).
enum SyntheticModule {
  static let package = PackageIdentity.plain("synthetic")

  /// A module with no files, with `dependencies`.
  static func module(_ name: String, type: PackageModel.Module.Kind = .library,
                     dependencies: [ResolvedModule.Dependency] = []) throws -> ResolvedModule {
    let path = try AbsolutePath(validating: "/synthetic/\(name)")
    let underlying = SwiftModule(name: name, type: type, path: path,
                                 sources: Sources(paths: [], root: path), packageAccess: false,
                                 usesUnsafeFlags: false, implicit: false)
    return ResolvedModule(
      packageIdentity: package, underlying: underlying, dependencies: dependencies,
      supportedPlatforms: [], platformConstraint: .all,
      platformVersionProvider: PlatformVersionProvider(
        implementation: .minimumDeploymentTargetDefault
      )
    )
  }

  /// A library product of `modules`.
  static func product(_ name: String, _ modules: [ResolvedModule]) throws -> ResolvedProduct {
    let product = try Product(package: package, name: name, type: .library(.automatic),
                              modules: modules.map(\.underlying))
    return ResolvedProduct(packageIdentity: package, product: product,
                           modules: IdentifiableSet(modules))
  }
}

/// The helpers that bridge SwiftPM's types (SwiftPMSettings.swift).
struct SwiftPMBridgingTests {
  @Test func aModuleDependencyBringsInThatModule() throws {
    let core = try SyntheticModule.module("Core")
    let dependency = ResolvedModule.Dependency.module(core, conditions: [])
    #expect(dependency.modules.map(\.name) == ["Core"])
  }

  @Test func aProductDependencyBringsInEveryModuleOfTheProduct() throws {
    let product = try SyntheticModule.product("Kit", [SyntheticModule.module("A"),
                                                      SyntheticModule.module("B")])
    let dependency = ResolvedModule.Dependency.product(product, conditions: [])
    #expect(dependency.modules.map(\.name).sorted() == ["A", "B"])
  }

  @Test func withoutConditionsEveryPlatform() {
    #expect(platforms(where: []) == Platform.allCases)
  }

  /// Platforms keep `Platform.allCases` order; SwiftPM platforms the zip doesn't ship are ignored.
  @Test func platformConditionsNarrowThePlatforms() {
    #expect(platforms(where: [PackageCondition(platforms: [.tvOS, .iOS, .linux])])
      == [.ios, .tvos])
    #expect(platforms(where: [PackageCondition(platforms: [.macCatalyst])]) == [.catalyst])
    #expect(platforms(where: [PackageCondition(platforms: [.linux])]) == [])
  }

  @Test func everyConditionMustHold() {
    let conditions = [PackageCondition(platforms: [.iOS, .macOS]),
                      PackageCondition(platforms: [.macOS, .tvOS])]
    #expect(platforms(where: conditions) == [.macos])
  }

  /// The zip is a Release build, so a Debug-only condition holds nowhere; trait conditions are
  /// evaluated while the graph loads, so they hold everywhere here.
  @Test func configurationAndTraitConditions() {
    #expect(platforms(where: [PackageCondition(configuration: .debug)]) == [])
    #expect(platforms(where: [PackageCondition(configuration: .release)]) == Platform.allCases)
    #expect(platforms(where: [.traits(TraitCondition(traits: ["Extra"]))]) == Platform.allCases)
  }
}
