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

// What frameworks link beyond their own dependencies, and the static binaries and frameworks
// dynamic frameworks mustn't link. See docs/how-it-works.md#linkage.

/// Every framework and binary that `framework` reaches through its dependencies, each on the
/// platforms of the paths that reach it (`nil` when that's all of the framework's).
func reachedDependencies(from framework: Framework, in plan: Plan) -> [Dependency] {
  let frameworks = Dictionary(plan.frameworks.map { ($0.name, $0) }) { first, _ in first }
  var reached: [String: Set<Platform>] = [:] // name → platforms some dependency path reaches it on
  var pending = framework.dependencies.map { ($0.name, $0.platforms ?? framework.platforms) }
  while let (name, platforms) = pending.popLast() {
    // Only platforms not yet reached for `name` go further, so each (name, platform) pair is
    // walked once, and cycles end.
    let added = platforms.subtracting(reached[name] ?? [])
    guard !added.isEmpty else { continue }
    reached[name, default: []].formUnion(added)
    for dependency in frameworks[name]?.dependencies ?? [] {
      pending.append((dependency.name, added.intersection(dependency.platforms ?? added)))
    }
  }
  return reached.map { name, platforms in
    Dependency(name: name, platforms: ownPlatformsAsNil(platforms, own: framework.platforms))
  }.sorted { $0.name < $1.name }
}

/// The plan's binaries that some dynamic framework reaches and that are static libraries, judged
/// by one slice each, since an `.xcframework`'s slices are built alike. A plan without dynamic
/// frameworks inspects nothing.
func staticBinaries(reachedByDynamicFrameworksIn plan: Plan,
                    packageRoot: Path) async throws -> Set<String> {
  let reached = Set(plan.frameworks.filter(\.isDynamic).flatMap {
    reachedDependencies(from: $0, in: plan).map(\.name)
  })
  var found = Set<String>()
  for binary in plan.binaries where reached.contains(binary.name) {
    if try await isStaticLibrary(xcframework: fullPath(binary.path, packageRoot)) {
      found.insert(binary.name)
    }
  }
  return found
}

/// Whether the `.xcframework`'s first slice is a static library. A binary that can't be told
/// (no slice, a missing binary, or one `file` doesn't recognize) doesn't count as static.
func isStaticLibrary(xcframework: Path) async throws -> Bool {
  guard let library = availableLibraries(of: xcframework).first else { return false }
  return try await binaryKind(of: binaryPath(of: library, in: xcframework)) == "static"
}

/// Fails when a dynamic framework reaches, directly or through its dependencies, one of
/// `staticBinaries` or a framework the plan keeps static (`Plan.keptStatic`). Linking it would
/// copy its code into the dynamic framework, duplicating its symbols wherever the original, or
/// another framework holding a copy, is linked too.
///
/// Of the static frameworks, only kept ones count. A static release's dynamic frameworks
/// (`frameworks.dynamic`, `.dynamic` products) have always been allowed to absorb the static
/// frameworks they reach, as SwiftPM's dynamic products do, and those releases shouldn't start
/// failing; in a dynamic release, the kept frameworks are the only static ones.
func checkDynamicFrameworksLinkNothingStatic(_ plan: Plan, staticBinaries: Set<String>) throws {
  let keptStatic = Set(plan.keptStatic ?? [])
  var problems: [String] = []
  for framework in plan.frameworks where framework.isDynamic {
    for name in reachedDependencies(from: framework, in: plan).map(\.name) {
      if staticBinaries.contains(name) {
        problems.append("""
        \(framework.name) is dynamic, but it depends on the static binary \(name), directly or \
        through its dependencies, so \(name)'s code would be copied into it. Build \(name) \
        from source (some packages offer a source form, e.g. through an environment variable), \
        or keep \(framework.name) static (frameworks.static).
        """)
      } else if keptStatic.contains(name) {
        problems.append("""
        \(framework.name) is dynamic, but it depends on the static framework \(name), directly \
        or through its dependencies, so \(name)'s code would be copied into it. Make \(name) \
        dynamic, or keep \(framework.name) static too, e.g. by listing it in frameworks.static.
        """)
      }
    }
  }
  if !problems.isEmpty {
    throw ZipBuilderError(problems.joined(separator: "\n"))
  }
}
