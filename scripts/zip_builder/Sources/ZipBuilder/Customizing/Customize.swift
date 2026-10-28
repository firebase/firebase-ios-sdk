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

/// Applies the config's customizations. Each step does nothing when its config keys are empty,
/// and warns about names that aren't in the plan instead of failing, so `--product` keeps working
/// while typos stay visible. `packageRoot` resolves `frameworks.publicHeaders`; `version` is the
/// release version, for `build.versionMacro`. Folders are arranged last
/// (`Customizing/Folders.swift`), because restricting platforms needs every product's closure.
func customize(_ plan: Plan, _ config: Config, packageRoot: Path, version: String) -> Plan {
  let frameworks = config.frameworks
  return plan
    .aggregatingPackages(frameworks.aggregate)
    .merging(frameworks.merge, platforms: frameworks.platforms)
    .renaming(frameworks.rename)
    .addingPublicHeaders(frameworks.publicHeaders, packageRoot: packageRoot)
    .markingPrivateHeaders(frameworks.privateHeaders)
    .hidingHeaders(frameworks.hiddenHeaders)
    .restrictingPlatforms(frameworks.platforms, config.products.platforms,
                          release: config.build.platforms)
    .applyingBuildMode(config.build, dynamic: frameworks.dynamic, static: frameworks.static,
                       version: version)
    .applyingLayout(config.layout)
    .arrangingFolders(config.products, files: config.zip.files)
}

extension Plan {
  /// `frameworks.publicHeaders`: adds the headers under package-root-relative directories,
  /// recursively, as public headers.
  func addingPublicHeaders(_ directoriesByFramework: [String: [Path]],
                           packageRoot: Path) -> Plan {
    var plan = self
    for (name, directories) in directoriesByFramework.sorted(by: { $0.key < $1.key }) {
      guard plan.containsFramework(name, warningIfMissing: "frameworks.publicHeaders"),
            let index = plan.frameworks.firstIndex(where: { $0.name == name }) else { continue }
      for directory in directories {
        let headers = headerFiles(in: directory, packageRoot: packageRoot)
        if headers.isEmpty {
          warn("frameworks.publicHeaders: \(directory) has no headers.")
        }
        for path in headers {
          // Added, or made public if it's already one of the framework's headers.
          plan.frameworks[index].headers.removeAll { $0.path == path }
          plan.frameworks[index].headers.append(Header(path: path, visibility: .public))
        }
      }
      plan.frameworks[index].headers.sort { $0.path < $1.path }
    }
    return plan
  }

  /// `frameworks.privateHeaders`: headers that ship in `PrivateHeaders/`.
  func markingPrivateHeaders(_ patterns: [String]) -> Plan {
    settingVisibility(.private, ofHeadersMatching: patterns, for: "frameworks.privateHeaders")
  }

  /// `frameworks.hiddenHeaders`: headers that don't ship.
  func hidingHeaders(_ patterns: [String]) -> Plan {
    settingVisibility(.project, ofHeadersMatching: patterns, for: "frameworks.hiddenHeaders")
  }

  /// `frameworks.platforms`, `products.platforms`: a framework ships on the platforms of the
  /// products (folders) that contain it, narrowed by its own restriction and by the release's
  /// platforms. Binaries are narrowed the same way, and a dependency only applies where its
  /// target is built. A framework or binary left with no platform can't be built, so it's
  /// dropped.
  func restrictingPlatforms(_ frameworkPlatforms: [String: [Platform]],
                            _ productPlatforms: [String: [Platform]],
                            release: [Platform]) -> Plan {
    warnAboutUnknown(productPlatforms.keys, known: Set(folders.map(\.name)),
                     key: "products.platforms", kind: "a shipped product")
    var plan = self
    for index in plan.frameworks.indices {
      let name = plan.frameworks[index].name
      plan.frameworks[index].platforms = shippingPlatforms(
        of: name, restriction: frameworkPlatforms[name], productPlatforms, release: release
      )
    }
    for index in plan.binaries.indices {
      let name = plan.binaries[index].name
      plan.binaries[index].platforms.formIntersection(shippingPlatforms(
        of: name, restriction: frameworkPlatforms[name], productPlatforms, release: release
      ))
    }
    return plan.droppingWhatShipsNowhere().narrowingDependenciesToWhereBuilt()
  }

  /// Where `name` ships: on the platforms of the products (folders) that contain it, narrowed
  /// to the release's platforms and to its own `restriction`.
  private func shippingPlatforms(of name: String, restriction: [Platform]?,
                                 _ productPlatforms: [String: [Platform]],
                                 release: [Platform]) -> Set<Platform> {
    let products = folders.filter { $0.frameworks.contains(name) }.map(\.name)
    // Until `arrangingFolders`, every framework and binary is in some product's folder;
    // `release` is only a fallback.
    let fromProducts = products.isEmpty
      ? release
      : products.flatMap { productPlatforms[$0] ?? release }
    return Set(fromProducts).intersection(release).intersection(restriction ?? release)
  }

  /// A framework or binary on no platform can't be built, since an `.xcframework` needs at least
  /// one slice: it leaves the plan, every folder, and every dependency on it.
  private func droppingWhatShipsNowhere() -> Plan {
    let nowhere = Set(frameworks.filter(\.platforms.isEmpty).map(\.name)
      + binaries.filter(\.platforms.isEmpty).map(\.name))
    for name in nowhere.sorted() {
      warn("\(name) ships on no platform; dropped.")
    }
    var plan = self
    plan.frameworks.removeAll { nowhere.contains($0.name) }
    plan.binaries.removeAll { nowhere.contains($0.name) }
    for index in plan.folders.indices {
      plan.folders[index].frameworks.removeAll { nowhere.contains($0) }
    }
    for index in plan.frameworks.indices {
      plan.frameworks[index].dependencies.removeAll { nowhere.contains($0.name) }
    }
    return plan
  }

  /// A dependency only applies where both sides are built; its platforms are `nil` when that's
  /// everywhere the framework is.
  private func narrowingDependenciesToWhereBuilt() -> Plan {
    let targets = frameworks.map { ($0.name, $0.platforms) } + binaries
      .map { ($0.name, $0.platforms) }
    let built = Dictionary(targets, uniquingKeysWith: { first, _ in first })
    var plan = self
    for index in plan.frameworks.indices {
      let own = plan.frameworks[index].platforms
      let dependencies = plan.frameworks[index].dependencies
      plan.frameworks[index].dependencies = dependencies.compactMap { dependency in
        guard let available = built[dependency.name] else { return dependency }
        let platforms = own.intersection(available).intersection(dependency.platforms ?? own)
        if platforms.isEmpty {
          return nil
        }
        return Dependency(name: dependency.name, platforms: ownPlatformsAsNil(platforms, own: own))
      }
    }
    return plan
  }

  /// `build`, `frameworks.dynamic`, `frameworks.static` and `build.linkage`: compile the way the
  /// release needs. See docs/how-it-works.md#build-mode.
  func applyingBuildMode(_ build: Config.Build, dynamic: [String], static keptStatic: [String],
                         version: String) -> Plan {
    var plan = self
    if !build.defineSwiftPackage {
      let isSwiftPackage = { (item: String) in
        item == "SWIFT_PACKAGE" || item.hasPrefix("SWIFT_PACKAGE=")
      }
      plan.changeAllSettings {
        $0.removeItems(from: "GCC_PREPROCESSOR_DEFINITIONS", where: isSwiftPackage)
        $0.removeItems(from: "SWIFT_ACTIVE_COMPILATION_CONDITIONS", where: isSwiftPackage)
      }
    }
    var definitions = build.defines
    if let macro = build.versionMacro {
      definitions.append("\(macro)=\(version)")
    }
    if !definitions.isEmpty {
      plan.settings.append(definitions, to: "GCC_PREPROCESSOR_DEFINITIONS")
    }
    if !build.swiftConditions.isEmpty {
      plan.settings.append(build.swiftConditions, to: "SWIFT_ACTIVE_COMPILATION_CONDITIONS")
    }
    // macOS and Mac Catalyst share the macosx SDK, so either name sets both.
    let destinations = Destination.all
    for (name, architectures) in build.architectures.sorted(by: { $0.key < $1.key }) {
      guard let destination = destinations.first(where: { $0.name == name }) else {
        warnSkipped(name, key: "build.architectures", kind: "a destination")
        continue
      }
      plan.settings["ARCHS[sdk=\(destination.sdk)*]"] = .list(architectures)
    }
    plan.settings.overrideDeploymentTargets(build.deploymentTargets)
    // `"*"` means every framework in `build.swiftVersion`; in `frameworks.dynamic` it's ignored.
    let names = plan.frameworkNames
    warnAboutUnknown(Set(dynamic).subtracting(["*"]), known: names, key: "frameworks.dynamic",
                     kind: "a framework in the plan")
    warnAboutUnknown(Set(keptStatic), known: names, key: "frameworks.static",
                     kind: "a framework in the plan")
    warnAboutUnknown(build.swiftVersion.keys.filter { $0 != "*" }, known: names,
                     key: "build.swiftVersion", kind: "a framework in the plan")
    for index in plan.frameworks.indices {
      let name = plan.frameworks[index].name
      if let swiftVersion = build.swiftVersion[name] ?? build.swiftVersion["*"] {
        plan.frameworks[index].settings["SWIFT_VERSION"] = .string(swiftVersion)
      }
      // Each list only departs from the release's linkage: `frameworks.static` from a dynamic
      // release, `frameworks.dynamic` from a static one.
      let isDynamic = build.linkage == .dynamic
        ? !keptStatic.contains(name)
        : dynamic.contains(name)
      if isDynamic {
        plan.frameworks[index].isDynamic = true
        plan.frameworks[index].settings.merge(dynamicFrameworkSettings)
      } else if build.linkage == .dynamic, plan.frameworks[index].isDynamic {
        // Planning keeps a `.dynamic` product's modules dynamic even when they're listed.
        warn("frameworks.static: \(name) is in a .dynamic library product, so it stays dynamic; "
          + "ignored.")
      }
    }
    if build.linkage == .dynamic {
      // Every other framework is dynamic now, so these are the release's static ones.
      let kept = plan.frameworks.filter { !$0.isDynamic }.map(\.name).sorted()
      plan.keptStatic = kept.isEmpty ? nil : kept
    }
    // Last, so a configured setting replaces every other value of it. Sorted keys: a key comes
    // before its variants, so a configured variant isn't removed.
    for key in build.settings.keys {
      plan.changeAllSettings { $0.removeAllVariants(of: key) }
      plan.settings[key] = build.settings[key]
    }
    return plan
  }

  /// `layout`: what's applied to each finished framework. Only frameworks with a privacy
  /// manifest get a privacy bundle, and only static ones get `layout.infoPlist`.
  func applyingLayout(_ layout: Config.Layout) -> Plan {
    let names = frameworkNames
    warnAboutUnknown(layout.privacyBundle.keys.filter { $0 != "*" }, known: names,
                     key: "layout.privacyBundle", kind: "a framework in the plan")
    warnAboutUnknown(layout.resourceBundles.keys, known: names, key: "layout.resourceBundles",
                     kind: "a framework in the plan")
    var plan = self
    for index in plan.frameworks.indices {
      let name = plan.frameworks[index].name
      let hasPrivacyManifest = plan.frameworks[index].resources.contains(where: \.isPrivacyManifest)
      let privacyBundle = hasPrivacyManifest
        ? (layout.privacyBundle[name] ?? layout.privacyBundle["*"]) : nil
      plan.frameworks[index].layout = Layout(
        privacyBundle: privacyBundle?.replacingOccurrences(of: "{target}", with: name),
        resourceBundle: layout.resourceBundles[name],
        // Workarounds for static frameworks embedded in apps; a dynamic one keeps Xcode's values,
        // since `MinimumOSVersion = 100.0` there would stop the app from launching.
        infoPlist: plan.frameworks[index].isDynamic ? [:] : layout.infoPlist
      )
    }
    return plan
  }

  // MARK: - Helpers

  /// Whether a framework is named `name`. If not, warns that the config key `key` names
  /// something that isn't in the plan.
  func containsFramework(_ name: String, warningIfMissing key: String) -> Bool {
    if frameworkNames.contains(name) {
      return true
    }
    warnSkipped(name, key: key, kind: "a framework in the plan")
    return false
  }

  private func settingVisibility(_ visibility: Header.Visibility,
                                 ofHeadersMatching patterns: [String], for key: String) -> Plan {
    var plan = self
    for pattern in patterns {
      var matched = false
      for i in plan.frameworks.indices {
        // fnmatch(3) returns 0 when the name matches the glob.
        for j in plan.frameworks[i].headers.indices
          where fnmatch(pattern, fileName(plan.frameworks[i].headers[j].path), 0) == 0 {
          plan.frameworks[i].headers[j].visibility = visibility
          matched = true
        }
      }
      if !matched {
        warn("\(key): \(pattern) matches no header.")
      }
    }
    return plan
  }

  /// Applies `change` to the project's and every framework's settings.
  private mutating func changeAllSettings(_ change: (inout BuildSettings) -> Void) {
    change(&settings)
    for index in frameworks.indices {
      change(&frameworks[index].settings)
    }
  }
}

/// Warns, for each of `names` that isn't in `known`, that the config key `key` names something
/// that isn't `kind` (e.g. "a shipped product"), and that it's skipped.
func warnAboutUnknown(_ names: some Sequence<String>, known: Set<String>, key: String,
                      kind: String) {
  for name in names.sorted() where !known.contains(name) {
    warnSkipped(name, key: key, kind: kind)
  }
}

/// Warns that the config key `key` names `name`, which isn't `kind`, so it's skipped.
func warnSkipped(_ name: String, key: String, kind: String) {
  warn("\(key): \(name) isn't \(kind); skipped.")
}

/// The header files under `directory`, recursively; both are relative to `packageRoot`.
func headerFiles(in directory: Path, packageRoot: Path) -> [Path] {
  let base = directory.hasSuffix("/") ? String(directory.dropLast()) : directory
  let root = URL(fileURLWithPath: packageRoot).appendingPathComponent(base).path
  let files = FileManager.default.enumerator(atPath: root)?.allObjects as? [String] ?? []
  return files.filter(isHeaderFile).map { "\(base)/\($0)" }.sorted()
}
