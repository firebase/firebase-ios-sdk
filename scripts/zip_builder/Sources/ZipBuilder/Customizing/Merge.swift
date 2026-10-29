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
import TSCUtility

// The customizations that combine and rename frameworks.

extension Plan {
  /// `frameworks.aggregate`: merges each package's frameworks into one named after the package.
  /// See docs/how-it-works.md#aggregating-packages.
  func aggregatingPackages(_ packages: [String]) -> Plan {
    var plan = self
    for package in packages {
      let parts = plan.frameworks.filter { $0.package == package }
      guard let first = parts.first else {
        warn("frameworks.aggregate: no framework comes from the package \(package); skipped.")
        continue
      }
      if !parts.contains(where: { $0.name == package }) {
        plan.frameworks.append(emptyFramework(named: package, like: first))
      }
      let companions = parts.map(\.name).filter { $0 != package }
      plan = plan.absorbing(companions, into: package, onlyOn: [:])
      // A part's custom module map only described that part; the aggregate gets an umbrella.
      if let index = plan.frameworks.firstIndex(where: { $0.name == package }) {
        plan.frameworks[index].moduleMap = nil
      }
    }
    return plan
  }

  /// `frameworks.merge`: each parent absorbs its companions.
  /// A companion in `platforms` (`frameworks.platforms`) only compiles on those platforms.
  func merging(_ merges: [String: [String]], platforms: [String: [Platform]]) -> Plan {
    var plan = self
    for (parent, companions) in merges.sorted(by: { $0.key < $1.key }) {
      if companions.contains(parent) {
        warn("frameworks.merge: \(parent) lists itself as a companion; skipped.")
      }
      // Check the parent first, then the companions, so each missing name is warned about once,
      // even when the parent is missing.
      let hasParent = plan.containsFramework(parent, warningIfMissing: "frameworks.merge")
      let found = companions.filter { $0 != parent }
        .filter { plan.containsFramework($0, warningIfMissing: "frameworks.merge") }
      if hasParent {
        plan = plan.absorbing(found, into: parent, onlyOn: platforms)
      }
    }
    return plan
  }

  /// `frameworks.rename`: ships frameworks under new names.
  /// Binaries keep their names: their module and `.xcframework` contents are prebuilt. A new
  /// name that's already taken is skipped, so names stay unique. A rename whose old name is
  /// missing but whose new name is already a framework or binary is already done, e.g. a source
  /// target renamed to the name its prebuilt binary has, so it's skipped without a warning.
  func renaming(_ names: [String: String]) -> Plan {
    guard !names.isEmpty else { return self }
    var plan = self
    var renamed: [String: String] = [:]
    for (old, new) in names.sorted(by: { $0.key < $1.key }) {
      guard let index = plan.frameworks.firstIndex(where: { $0.name == old }) else {
        if plan.binaries.contains(where: { $0.name == old }) {
          warn("frameworks.rename: \(old) is a prebuilt binary; binaries can't be renamed; "
            + "skipped.")
        } else if plan.hasFrameworkOrBinary(named: new) {
          logger.debug("""
          frameworks.rename: \(old) isn't in the plan, but \(new) already is; nothing to rename.
          """)
        } else {
          warnSkipped(old, key: "frameworks.rename", kind: "a framework or binary in the plan")
        }
        continue
      }
      if plan.hasFrameworkOrBinary(named: new) {
        warn("frameworks.rename: \(new) is already a framework or binary; \(old) skipped.")
        continue
      }
      plan.frameworks[index].rename(to: new)
      renamed[old] = new
    }
    return plan.replacingReferences(renamed)
  }

  /// Moves the companions into `parentName`; references to them now point at it.
  private func absorbing(_ companions: [String], into parentName: String,
                         onlyOn platforms: [String: [Platform]]) -> Plan {
    guard var parent = frameworks.first(where: { $0.name == parentName }) else { return self }
    for companion in frameworks where companions.contains(companion.name) {
      parent.absorb(companion, onlyOn: platforms[companion.name].map { Set($0) })
    }
    var plan = self
    plan.frameworks = frameworks.filter { !companions.contains($0.name) }
      .map { $0.name == parentName ? parent : $0 }
    let replacements = Dictionary(companions.map { ($0, parentName) },
                                  uniquingKeysWith: { first, _ in first })
    return plan.replacingReferences(replacements)
  }

  /// Points references in dependencies and folders at their new names (after a merge or
  /// rename), then re-sorts the frameworks by dependency.
  private func replacingReferences(_ replacements: [String: String]) -> Plan {
    var plan = self
    for index in plan.frameworks.indices {
      let framework = plan.frameworks[index]
      // A parent that depended on an absorbed companion now names itself; that dependency goes.
      plan.frameworks[index].dependencies = mergingDuplicates(framework.dependencies.map {
        Dependency(name: replacements[$0.name] ?? $0.name, platforms: $0.platforms)
      }.filter { $0.name != framework.name })
    }
    let replacing = { (names: [String]) in Set(names.map { replacements[$0] ?? $0 }).sorted() }
    for index in plan.folders.indices {
      plan.folders[index].frameworks = replacing(plan.folders[index].frameworks)
      // A product's own frameworks follow merges and renames too, so it keeps what its targets
      // became (`products.withoutDependencies`).
      plan.folders[index].ownFrameworks = plan.folders[index].ownFrameworks.map(replacing)
    }
    plan.frameworks = sortedByDependencies(plan.frameworks)
    return plan
  }
}

extension Framework {
  /// Adds a companion's sources, headers, resources, settings and dependencies. `platforms`
  /// limits its sources and dependencies, so it isn't compiled or linked anywhere else.
  /// The parent keeps its own custom module map; a companion's is dropped, like its umbrella.
  mutating func absorb(_ companion: Framework, onlyOn platforms: Set<Platform>?) {
    sources += companion.sources.map {
      Source(path: $0.path, platforms: intersection($0.platforms, platforms))
    }
    // A companion's own umbrella header only described its SwiftPM module.
    let umbrellas = ["\(companion.name).h", "\(companion.moduleName).h"]
    headers += companion.headers.filter { header in
      !umbrellas.contains(fileName(header.path)) && !headers.contains { $0.path == header.path }
    }
    // Only the same path is skipped, so the parent can end up with several privacy manifests;
    // they're combined into one when the project is made, because a framework ships one.
    resources += companion.resources.filter { resource in
      !resources.contains { $0.path == resource.path }
    }
    settings = settings.combined(with: companion.settings)
    dependencies = mergingDuplicates(dependencies + companion.dependencies.map {
      Dependency(name: $0.name, platforms: intersection($0.platforms, platforms))
    })
    sources.sort { $0.path < $1.path }
    headers.sort { $0.path < $1.path }
    resources.sort { $0.path < $1.path }
  }

  /// Gives the framework a new name, module name and bundle ID, in its settings too.
  mutating func rename(to newName: String) {
    let oldComponent = bundleIDComponent(name)
    if bundleID.hasSuffix(".\(oldComponent)") {
      bundleID = bundleID.dropLast(oldComponent.count) + bundleIDComponent(newName)
    }
    name = newName
    moduleName = newName.spm_mangledToC99ExtendedIdentifier()
    settings["PRODUCT_NAME"] = .string(name)
    settings["PRODUCT_MODULE_NAME"] = .string(moduleName)
    settings["PRODUCT_BUNDLE_IDENTIFIER"] = .string(bundleID)
  }
}

/// An empty framework named after a package, with the package, platforms, version and bundle ID
/// prefix of `part`, one of the package's frameworks. It's built field by field rather than
/// copied, so a field added to `Framework` later isn't inherited from `part` by accident.
private func emptyFramework(named name: String, like part: Framework) -> Framework {
  var framework = Framework(
    name: part.name, moduleName: part.moduleName, package: part.package, sources: [], headers: [],
    moduleMap: nil, resources: [],
    settings: ["MACH_O_TYPE": "staticlib", "MARKETING_VERSION": .string(part.version)],
    dependencies: [], platforms: part.platforms, bundleID: part.bundleID, version: part.version,
    isDynamic: false, layout: Layout()
  )
  // From `part`'s names, so the bundle ID keeps `part`'s prefix.
  framework.rename(to: name)
  return framework
}
