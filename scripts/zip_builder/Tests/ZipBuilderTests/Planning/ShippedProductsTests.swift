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

/// `products.exclude`, `products.rename` and `products.add` names that match nothing warn and are
/// skipped, like the names `customize` checks.
struct ShippedProductsTests {
  private func planned(_ sections: String,
                       product: String? = nil) async throws -> (result: Plan, warnings: [String]) {
    try await collectingWarnings { try await MiniPackage.plan(sections, product: product) }
  }

  @Test func warnsAboutExcludedAndRenamedNamesThatAreNotProducts() async throws {
    let (plan, warnings) = try await planned("""
    "products": { "exclude": ["MiniPrebuilt", "Nope", "SwiftLib"],
                  "rename": { "MiniCore": "Core", "Missing": "M" } }
    """)
    #expect(plan.folders.map(\.name) == ["Core", "Mini", "MiniHeaders"])
    #expect(warnings == [
      "products.exclude: Nope isn't a library product; skipped.",
      "products.exclude: SwiftLib isn't a library product; skipped.",
      "products.rename: Missing isn't a library product; skipped.",
    ])
  }

  /// `--product` plans one product, but the others are still products, so naming them is fine.
  @Test func productOptionDoesNotCauseWarnings() async throws {
    let (plan, warnings) = try await planned("""
    "products": { "exclude": ["MiniPrebuilt"], "rename": { "MiniCore": "Core", "Extras": "E" },
                  "add": [{ "name": "Extras", "targets": ["Mini-Extras"] }] }
    """, product: "Mini")
    #expect(plan.folders.map(\.name) == ["Mini"])
    #expect(warnings.isEmpty)
  }

  @Test func skipsAnAddedTargetThePackageDoesNotHave() async throws {
    let (plan, warnings) = try await planned("""
    "products": { "add": [{ "name": "Extras", "targets": ["Nope", "Mini-Extras"] }] }
    """)
    #expect(plan.folders.first { $0.name == "Extras" }?.frameworks == ["Mini-Extras"])
    #expect(warnings == ["products.add (Extras): Nope isn't a target in the package; skipped."])
  }

  @Test func skipsAnAddedProductWithoutKnownTargets() async throws {
    let (plan, warnings) = try await planned("""
    "products": { "add": [{ "name": "Extras", "targets": ["Nope"] }],
                  "rename": { "Extras": "E" } }
    """)
    #expect(plan.folders.map(\.name) == ["Mini", "MiniCore", "MiniHeaders", "MiniPrebuilt"])
    #expect(warnings == [
      "products.add (Extras): Nope isn't a target in the package; skipped.",
      "products.add: Extras has no targets in the package; skipped.",
    ])
  }
}
