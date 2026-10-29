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
@preconcurrency import PackageGraph
@preconcurrency import PackageModel

// Connecting dependencies, and the algebra of platform sets where `nil` means every platform.

/// The module's dependencies as framework and binary names. A wrapper is replaced by its own
/// dependencies, on the platforms where both conditions hold.
func dependencies(of module: ResolvedModule, wrappers: Set<String>) -> [Dependency] {
  var found: [Dependency] = []
  for dependency in module.dependencies {
    let platforms = allPlatformsAsNil(Set(platforms(where: dependency.conditions)))
    for target in dependency.modules where target.type == .library || target.type == .binary {
      if wrappers.contains(target.name) {
        found += dependencies(of: target, wrappers: wrappers).map {
          Dependency(name: $0.name, platforms: intersection(platforms, $0.platforms))
        }
      } else {
        found.append(Dependency(name: target.name, platforms: platforms))
      }
    }
  }
  return mergingDuplicates(found)
}

/// Frameworks in dependency order; ties (and cycles) are broken by name.
func sortedByDependencies(_ frameworks: [Framework]) -> [Framework] {
  let names = Set(frameworks.map(\.name))
  var remaining = frameworks.sorted { $0.name < $1.name }
  var placed = Set<String>()
  var sorted: [Framework] = []
  while !remaining.isEmpty {
    let index = remaining.firstIndex { framework in
      // Binaries and names outside the plan never block.
      framework.dependencies.allSatisfy { placed.contains($0.name) || !names.contains($0.name) }
    } ?? 0 // a cycle: nothing is ready, so take the first by name
    let next = remaining.remove(at: index)
    placed.insert(next.name)
    sorted.append(next)
  }
  return sorted
}

/// One entry per name, on the union of its platforms, sorted; drops those that apply nowhere.
func mergingDuplicates(_ dependencies: [Dependency]) -> [Dependency] {
  var merged: [Dependency] = []
  for dependency in dependencies where dependency.platforms?.isEmpty != true {
    if let index = merged.firstIndex(where: { $0.name == dependency.name }) {
      merged[index].platforms = union(merged[index].platforms, dependency.platforms)
    } else {
      merged.append(dependency)
    }
  }
  return merged.sorted { $0.name < $1.name }
}

/// The platforms in both sets, where `nil` means every platform.
func intersection(_ lhs: Set<Platform>?, _ rhs: Set<Platform>?) -> Set<Platform>? {
  guard let lhs else { return rhs }
  guard let rhs else { return lhs }
  return lhs.intersection(rhs)
}

/// The platforms in either set, where `nil` means every platform.
func union(_ lhs: Set<Platform>?, _ rhs: Set<Platform>?) -> Set<Platform>? {
  guard let lhs, let rhs else { return nil }
  return allPlatformsAsNil(lhs.union(rhs))
}

/// `nil` when `platforms` is every platform, else `platforms`.
func allPlatformsAsNil(_ platforms: Set<Platform>) -> Set<Platform>? {
  platforms == Set(Platform.allCases) ? nil : platforms
}

/// A dependency's platforms on a framework that ships on `own`: `nil` when they're the same,
/// since a dependency can't apply where its framework doesn't ship.
func ownPlatformsAsNil(_ platforms: Set<Platform>, own: Set<Platform>) -> Set<Platform>? {
  platforms == own ? nil : platforms
}
