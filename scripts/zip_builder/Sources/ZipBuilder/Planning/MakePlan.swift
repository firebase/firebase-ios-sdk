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

@preconcurrency import Basics
import Foundation
@preconcurrency import PackageGraph
@preconcurrency import PackageModel

/// Turns the package into a plan, before any customization.
/// See docs/how-it-works.md#from-packageswift-to-frameworks.
///
/// `product` keeps just that product and what it needs.
func makePlan(_ graph: ModulesGraph, _ config: Config, version: String,
              product: String? = nil) throws -> Plan {
  guard let root = graph.rootPackages.first else {
    throw ZipBuilderError("The package graph has no root package.")
  }
  let products = try shippedProducts(root, graph, config, product: product)
  let reachable = try modules(reachableFrom: products)
  try checkSupported(reachable)
  let libraries = reachable.filter { $0.type == .library }
  let wrappers = Set(libraries.filter(isWrapper).map(\.name))
  let targets = libraries.filter { !wrappers.contains($0.name) }
  let packages = Dictionary(targets.map { ($0.name, packageName(of: $0, graph)) },
                            uniquingKeysWith: { first, _ in first })
  let binaryNames = Set(reachable.filter { $0.type == .binary }.map(\.name))
  let dynamicModules = dynamicTargets(
    packages: packages,
    dynamicProducts: Set(products.filter(\.isDynamic).flatMap { $0.modules.map(\.name) }),
    config, binaries: binaryNames
  )
  let context = Planning(
    graph: graph, packageRoot: root.path, config: config, releaseVersion: version,
    wrappers: wrappers, dynamicModules: dynamicModules,
    frameworkNames: finalFrameworkNames(packages: packages, config.frameworks,
                                        binaries: binaryNames)
  )
  let frameworks = try targets.map { try framework(for: $0, context) }
  let binaries = try reachable.filter { $0.type == .binary }.map { try binary(for: $0, context) }
  return Plan(
    settings: projectSettings(root),
    frameworks: sortedByDependencies(frameworks),
    binaries: binaries,
    folders: folders(for: products, frameworks, context)
  )
}

/// A product that ships: a library product of the root package, or one added in the config.
private struct ShippedProduct {
  var name: String
  var modules: [ResolvedModule]
  var isDynamic: Bool
}

/// What planning one module needs to know about the rest of the package.
private struct Planning {
  var graph: ModulesGraph
  var packageRoot: AbsolutePath
  var config: Config
  var releaseVersion: String
  var wrappers: Set<String>
  var dynamicModules: Set<String>
  var frameworkNames: [String: String] // target → the framework it ends up in

  /// Plan paths are relative to the package root, so plans match across machines.
  func relative(_ path: AbsolutePath) -> Path {
    path.relative(to: packageRoot).pathString
  }

  func isRoot(_ module: ResolvedModule) -> Bool {
    graph.package(for: module).map(graph.isRootPackage) ?? false
  }

  /// The release version for the root package's modules, else their package's version.
  func version(of module: ResolvedModule) -> String {
    if isRoot(module) {
      return releaseVersion
    }
    if let packageVersion = graph.package(for: module)?.manifest.version {
      return packageVersion.description
    }
    warn("\(module.name): its package has no version (not resolved to a tag); "
      + "using \(releaseVersion).")
    return releaseVersion
  }

  func bundleID(of module: ResolvedModule) -> String {
    let release = config.release
    let prefix = isRoot(module)
      ? release.bundleIdPrefix
      : (release.dependencyBundleIdPrefix ?? release.bundleIdPrefix)
    return "\(prefix).\(bundleIDComponent(module.name))"
  }
}

/// The display name of the package `module` comes from, as in `Framework.package`.
private func packageName(of module: ResolvedModule, _ graph: ModulesGraph) -> String {
  graph.package(for: module)?.manifest.displayName ?? ""
}

/// The root package's library products minus `products.exclude`, plus `products.add`; `product`
/// keeps just that product (`--product`).
///
/// Config names that match nothing are warned about and skipped, like the names `customize`
/// checks. They're checked against every root product, before `--product` filters, so planning
/// one product doesn't warn about the others.
private func shippedProducts(_ root: ResolvedPackage, _ graph: ModulesGraph, _ config: Config,
                             product: String?) throws -> [ShippedProduct] {
  let libraries = root.products.filter(\.type.isLibrary)
  let libraryNames = Set(libraries.map(\.name))
  warnAboutUnknown(config.products.exclude, known: libraryNames, key: "products.exclude",
                   kind: "a library product")
  warnAboutUnknown(config.products.rename.keys,
                   known: libraryNames.union(config.products.add.map(\.name)),
                   key: "products.rename", kind: "a library product")
  var products = libraries
    .filter { !config.products.exclude.contains($0.name) }
    .map { product in
      ShippedProduct(name: product.name, modules: product.modules.sorted { $0.name < $1.name },
                     isDynamic: product.type == .library(.dynamic))
    }
  products += addedProducts(config.products.add, graph)
  if let product {
    products = products.filter { $0.name == product }
    if products.isEmpty {
      throw ZipBuilderError("--product: no shipped product is named \(product).")
    }
  }
  return products
}

/// The `products.add` products. A target the package doesn't have is skipped with a warning,
/// and so is a product left without targets.
private func addedProducts(_ added: [Config.Product], _ graph: ModulesGraph) -> [ShippedProduct] {
  added.compactMap { product in
    let modules = product.targets.compactMap { name in
      let module = graph.module(for: name)
      if module == nil {
        warnSkipped(name, key: "products.add (\(product.name))", kind: "a target in the package")
      }
      return module
    }
    if modules.isEmpty {
      warn("products.add: \(product.name) has no targets in the package; skipped.")
      return nil
    }
    return ShippedProduct(name: product.name, modules: modules, isDynamic: false)
  }
}

/// The products' modules and everything they depend on, by name. Test-only modules aren't
/// reachable from a library product, so they're never included.
private func modules(reachableFrom products: [ShippedProduct]) throws -> [ResolvedModule] {
  var byName: [String: ResolvedModule] = [:]
  for module in products.flatMap(\.modules) {
    byName[module.name] = module
    for dependency in try module.recursiveModuleDependencies() {
      byName[dependency.name] = dependency
    }
  }
  return byName.values.sorted { $0.name < $1.name }
}

/// The per-target mapping: the framework a library target becomes.
private func framework(for module: ResolvedModule, _ context: Planning) throws -> Framework {
  let isDynamic = context.dynamicModules.contains(module.name)
  let bundleID = context.bundleID(of: module)
  let version = context.version(of: module)
  return try Framework(
    name: module.name,
    moduleName: module.c99name,
    package: packageName(of: module, context.graph),
    sources: module.sources.paths.map(context.relative).sorted().map { Source(path: $0) },
    headers: headers(of: module).map { Header(
      path: context.relative($0.path),
      visibility: $0.visibility
    ) },
    moduleMap: customModuleMap(of: module).map(context.relative),
    resources: module.underlying.resources
      .map { Resource(path: context.relative($0.path), rule: Resource.Rule($0.rule)) }
      .sorted { $0.path < $1.path },
    settings: frameworkSettings(module, bundleID: bundleID, version: version,
                                isDynamic: isDynamic, packageRoot: context.packageRoot,
                                frameworkNames: context.frameworkNames),
    dependencies: dependencies(of: module, wrappers: context.wrappers),
    platforms: Set(context.config.build.platforms),
    bundleID: bundleID,
    version: version,
    isDynamic: isDynamic,
    layout: Layout()
  )
}

extension Resource.Rule {
  init(_ rule: PackageModel.Resource.Rule) {
    switch rule {
    case let .process(localization): self = .process(localization: localization)
    case .copy: self = .copy
    case .embedInCode: self = .embedInCode
    }
  }
}

/// The module's C-family headers, sorted. Headers under `includeDir` are public, the rest project.
func headers(of module: ResolvedModule) -> [(path: AbsolutePath, visibility: Header.Visibility)] {
  guard let clang = clangInfo(of: module) else { return [] }
  return clang.headers.sorted { $0.pathString < $1.pathString }.map { header in
    let isPublic = clang.includeDir.map { header.isDescendant(of: $0) } ?? false
    return (header, isPublic ? .public : .project)
  }
}

/// The module's custom module map (`include/module.modulemap`), for C-family and mixed modules.
func customModuleMap(of module: ResolvedModule) -> AbsolutePath? {
  if case let .custom(path) = clangInfo(of: module)?.moduleMapType {
    return path
  }
  return nil
}

/// Fails on SwiftPM features a framework can't express.
/// Trait conditions aren't checked: SwiftPM evaluates them while loading the graph.
private func checkSupported(_ modules: [ResolvedModule]) throws {
  for module in modules {
    if let problem = unsupportedFeature(of: module) {
      throw ZipBuilderError("\(module.name): \(problem).")
    }
  }
}

/// Why `module` can't become a framework or binary, or `nil` when it can.
func unsupportedFeature(of module: ResolvedModule) -> String? {
  if module.type == .systemModule {
    return "system library targets aren't supported"
  }
  if !module.underlying.pluginUsages.isEmpty {
    return "build tool plugins aren't supported"
  }
  if module.dependencies.flatMap(\.modules).contains(where: { $0.type == .macro }) {
    return "macros aren't supported"
  }
  if module.moduleAliases?.isEmpty == false {
    return "module aliases aren't supported"
  }
  if let binary = module.underlying as? BinaryModule, !isXCFramework(binary) {
    return "only .xcframework binary targets are supported"
  }
  return nil
}

/// Whether a binary target is an `.xcframework`, the only kind of binary target a zip can ship.
private func isXCFramework(_ binary: BinaryModule) -> Bool {
  if case .xcframework = binary.kind {
    return true
  }
  return false
}

/// One folder per product, named by `products.rename`, with every framework and binary it needs.
/// `customize` arranges them into the zip layout last, because restricting platforms needs each
/// product's full closure. With `products.withoutDependencies`, the product's own frameworks are
/// recorded too, for `arrangingFolders` to keep.
private func folders(for products: [ShippedProduct], _ frameworks: [Framework],
                     _ context: Planning) -> [Folder] {
  let dependencyNames = Dictionary(uniqueKeysWithValues: frameworks.map {
    ($0.name, $0.dependencies.map(\.name))
  })
  return products.map { product in
    // A wrapper isn't a framework, so the folder gets what it forwards to.
    let roots = product.modules.flatMap { module in
      context.wrappers.contains(module.name)
        ? dependencies(of: module, wrappers: context.wrappers).map(\.name) : [module.name]
    }
    let name = context.config.products.rename[product.name] ?? product.name
    var folder = Folder(name: name, frameworks: closure(of: roots, dependencyNames).sorted(),
                        files: [])
    if context.config.products.withoutDependencies {
      folder.ownFrameworks = Set(roots).sorted()
    }
    return folder
  }.sorted { $0.name < $1.name }
}

/// `names` and everything they depend on, transitively. Names missing from `dependencies` (such
/// as binaries) have no dependencies.
private func closure(of names: [String], _ dependencies: [String: [String]]) -> Set<String> {
  var pending = names
  var found = Set<String>()
  while let name = pending.popLast() {
    if found.insert(name).inserted {
      pending += dependencies[name] ?? []
    }
  }
  return found
}

/// A binary target, on the platforms its `.xcframework` has slices for.
private func binary(for module: ResolvedModule, _ context: Planning) throws -> Binary {
  guard let binary = module.underlying as? BinaryModule, isXCFramework(binary) else {
    throw ZipBuilderError("\(module.name): only .xcframework binary targets are supported.")
  }
  return try Binary(name: module.name, path: context.relative(binary.artifactPath),
                    platforms: xcframeworkPlatforms(at: binary.artifactPath.pathString),
                    version: context.version(of: module))
}

/// The platforms an `.xcframework` has slices for, from its `Info.plist`.
func xcframeworkPlatforms(at path: Path) throws -> Set<Platform> {
  struct Info: Decodable {
    struct Library: Decodable {
      var SupportedPlatform: String
      var SupportedPlatformVariant: String?
    }

    var AvailableLibraries: [Library]
  }
  let url = URL(fileURLWithPath: path).appendingPathComponent("Info.plist")
  let info = try PropertyListDecoder().decode(Info.self, from: Data(contentsOf: url))
  return Set(info.AvailableLibraries.compactMap { library in
    switch library.SupportedPlatform {
    case "ios": library.SupportedPlatformVariant == "maccatalyst" ? .catalyst : .ios
    case "macos": .macos
    case "tvos": .tvos
    case "watchos": .watchos
    case "xros": .visionos
    default: nil
    }
  })
}
