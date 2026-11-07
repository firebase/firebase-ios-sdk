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

// Which targets build dynamic. Planning decides, because a target's linker settings only become
// `OTHER_LDFLAGS` in a dynamic framework, and they can only be translated while planning.

/// The targets (of `packages`: target name → package name) that build dynamic: those in
/// `dynamicProducts` (modules of `.dynamic` products), and with `build.linkage: dynamic` every
/// target whose framework, after combining and renaming, isn't in `frameworks.static`; else those
/// whose framework is in `frameworks.dynamic`.
///
/// Going by the final framework name means a merged companion or an aggregated part translates
/// its linker settings the way its parent links, and a renamed framework is found by its new
/// name, as `customize` finds it. `binaries` are the binary names, which a rename can't take.
/// A `.dynamic` product's modules stay dynamic even in `frameworks.static`: the package's author
/// declared them so (`customize` warns about the listing).
func dynamicTargets(packages: [String: String], dynamicProducts: Set<String>, _ config: Config,
                    binaries: Set<String>) -> Set<String> {
  let finalNames = finalFrameworkNames(packages: packages, config.frameworks, binaries: binaries)
  func isListed(_ target: String, in frameworks: [String]) -> Bool {
    frameworks.contains(finalNames[target] ?? target)
  }
  let fromConfig = config.build.linkage == .dynamic
    ? packages.keys.filter { !isListed($0, in: config.frameworks.static) }
    : packages.keys.filter { isListed($0, in: config.frameworks.dynamic) }
  return Set(fromConfig).union(dynamicProducts)
}

/// The framework each target ends up in (target name → framework name), worked out from the
/// config the way `customize` combines and renames frameworks: `frameworks.aggregate`, then
/// `frameworks.merge`, then `frameworks.rename`, each with the names the step before left.
/// See docs/how-it-works.md#customizations.
func finalFrameworkNames(packages: [String: String], _ frameworks: Config.Frameworks,
                         binaries: Set<String>) -> [String: String] {
  // Aggregating: a package's targets go into one framework named after the package.
  var finalNames = Dictionary(uniqueKeysWithValues: packages.map { target, package in
    (target, frameworks.aggregate.contains(package) ? package : target)
  })
  func moveTargets(of framework: String, to newName: String) {
    for (target, name) in finalNames where name == framework {
      finalNames[target] = newName
    }
  }
  // Merging: parents in name order; a missing parent or companion is skipped.
  for (parent, companions) in frameworks.merge.sorted(by: { $0.key < $1.key }) {
    let existing = Set(finalNames.values)
    guard existing.contains(parent) else { continue }
    for companion in companions where companion != parent && existing.contains(companion) {
      moveTargets(of: companion, to: parent)
    }
  }
  // Renaming: old names in order; a name that's already taken is skipped, and a missing old name
  // moves nothing, including a rename that's already done.
  for (old, new) in frameworks.rename.sorted(by: { $0.key < $1.key }) {
    let existing = Set(finalNames.values)
    if existing.contains(old), !existing.contains(new), !binaries.contains(new) {
      moveTargets(of: old, to: new)
    }
  }
  return finalNames
}
