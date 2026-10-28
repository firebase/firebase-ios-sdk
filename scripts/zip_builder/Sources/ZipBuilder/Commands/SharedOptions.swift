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

import ArgumentParser
import Foundation

/// Options shared by the pipeline stages, and the stage steps that use them (plan, build,
/// package).
struct SharedOptions: ParsableArguments {
  @Option(help: "The Swift package to build.")
  var packagePath = "."

  @Option(help: ArgumentHelp(
    "The config file.",
    discussion: "Default: <package-path>/zip_builder.jsonc, else <package-path>/zip_builder.json."
  ))
  var config: String?

  @Option(help: "Where each stage writes its output.")
  var workDir = "build"

  @Option(help: "Only this product and what it needs.")
  var product: String?

  @Option(help: "The release version (x.y.z). Takes precedence over release.version.")
  var version: String?

  @Option(help: ArgumentHelp(
    "How the frameworks built from source link. Takes precedence over build.linkage.",
    valueName: "static|dynamic"
  ))
  var linkage: Linkage?

  @Flag(help: ArgumentHelp(
    "Ship --product without its dependencies: they're built, but not zipped.",
    discussion: "Sets products.withoutDependencies. Needs --product."
  ))
  var withoutDependencies = false

  func validate() throws {
    if withoutDependencies, product == nil {
      throw ValidationError("""
      --without-dependencies needs --product; to ship every product without its dependencies, \
      set products.withoutDependencies in the config.
      """)
    }
  }

  /// `--config`, else the package's config file; names the preferred file when there's none.
  var configPath: Path {
    config ?? Config.file(in: packagePath) ?? Config.paths(in: packagePath)[0]
  }

  /// The config: `--config`, else the package's config file, which must exist.
  func loadConfig() throws -> Config {
    guard let found = try Config.load(from: config, orDefaultIn: packagePath) else {
      throw ZipBuilderError("No config: \(configPath) doesn't exist. Add it, or pass --config.")
    }
    return found
  }

  /// `--version`, else `release.version` from the config.
  func releaseVersion(_ config: Config) throws -> String {
    guard let version = version ?? config.release.version else {
      throw ZipBuilderError(
        "No release version: pass --version or set release.version in \(configPath)."
      )
    }
    return version
  }

  /// `--linkage`, else `build.linkage` from the config.
  func releaseLinkage(_ config: Config) -> Linkage {
    linkage ?? config.build.linkage
  }

  /// The config planning and `customize` get: `config` with the flags that override it
  /// (`--linkage`, `--without-dependencies`) applied, since both stages read those keys.
  func applyingFlags(to config: Config) -> Config {
    var config = config
    config.build.linkage = releaseLinkage(config)
    if withoutDependencies {
      config.products.withoutDependencies = true
    }
    return config
  }

  /// Plans the release from the package and config (`makePlan`, then `customize`).
  func makeCustomizedPlan(_ config: Config) async throws -> Plan {
    let version = try releaseVersion(config)
    let config = applyingFlags(to: config)
    let graph = try await loadPackage(at: packagePath)
    let plan = try makePlan(graph, config, version: version, product: product)
    return customize(plan, config, packageRoot: packagePath, version: version)
  }

  /// The plan at `path` (`--plan`), else a new one. `--product`, `--linkage` and
  /// `--without-dependencies` don't apply to a given plan.
  func loadOrMakePlan(_ path: Path?, _ config: Config) async throws -> Plan {
    guard let path else { return try await makeCustomizedPlan(config) }
    if product != nil {
      warn("--product is ignored with --plan: the plan already holds its frameworks.")
    }
    if linkage != nil {
      warn("--linkage is ignored with --plan: the plan already holds each framework's linkage.")
    }
    if withoutDependencies {
      warn("--without-dependencies is ignored with --plan: the plan already holds its folders.")
    }
    do {
      return try Plan.read(from: path)
    } catch {
      throw ZipBuilderError("Couldn't read the plan at \(path): \(error)")
    }
  }

  /// Writes `<work-dir>/plan.json`.
  func writePlan(_ plan: Plan) throws -> URL {
    let workDir = URL(fileURLWithPath: workDir)
    try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    let planURL = workDir.appendingPathComponent("plan.json")
    try plan.json().write(to: planURL)
    return planURL
  }

  /// Builds the `.xcframeworks` (`buildXCFrameworks`) and returns `<work-dir>/xcframeworks`.
  func build(_ plan: Plan, cacheDir: Path, project: Path? = nil) async throws -> Path {
    let start = ContinuousClock.now
    let paths = try await buildXCFrameworks(plan, packageRoot: packagePath, workDir: workDir,
                                            cache: FrameworkCache(directory: cacheDir),
                                            project: project)
    let output = xcframeworksDirectory(workDir: workDir).path
    logger.info("""
    Built \(paths.count) .xcframeworks (\(plan.frameworks.count) frameworks, \
    \(plan.binaries.count) binaries) in \(formatted(.now - start)): \(output)
    """)
    return output
  }

  /// Lays out, signs and zips the distribution (`makeZip`); returns the distribution root.
  func package(_ plan: Plan, _ config: Config, xcframeworks: Path, sign: String?,
               version: String) async throws -> URL {
    let zip = try await makeZip(xcframeworks: xcframeworks, plan: plan, config: config,
                                packageRoot: packagePath, workDir: workDir,
                                signingIdentity: sign, version: version)
    let root = distributionRoot(workDir: workDir, config: config)
    logger.info("Distribution: \(root.path)")
    logger.info("Zip: \(zip) (\(formattedSize(ofFile: zip)))")
    return root
  }
}

/// `--linkage static|dynamic`, spelled like `build.linkage`.
extension Linkage: ExpressibleByArgument {}
