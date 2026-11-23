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

/// Turns a finished, unsigned distribution into Carthage archives and binary specs, as configured
/// by the config's `carthage` group (see docs/how-it-works.md#carthage).
struct CarthageCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "carthage",
    abstract: "Package a finished, unsigned distribution for Carthage."
  )

  @OptionGroup var options: SharedOptions
  @OptionGroup var logging: LoggingOptions

  @Argument(help: ArgumentHelp(
    "The distribution: a directory or a zip.",
    discussion: "Default: <work-dir>/dist/<release.name>."
  ))
  var distribution: String?

  @Option(help: ArgumentHelp(
    "Where the archives and binary specs go, in <output>/<version>/.",
    discussion: "Default: <work-dir>/carthage."
  ))
  var output: String?

  @Option(help: "The framework cache, for the extra build.")
  var cacheDir = FrameworkCache.defaultDirectory

  func validate() throws {
    // The extra build is limited by `carthage.rebuild`, and the distribution's folders are given.
    if options.product != nil {
      throw ValidationError("--product doesn't apply to carthage; set carthage.rebuild.")
    }
    if options.withoutDependencies {
      throw ValidationError("--without-dependencies doesn't apply to carthage.")
    }
  }

  func run() async throws {
    logging.apply()
    let config = try options.loadConfig()
    guard let carthage = config.carthage else {
      throw ZipBuilderError("No carthage group in \(options.configPath): add one to use "
        + "carthage (see docs/configuration.md#carthage).")
    }
    let rebuild = try extraBuild(of: carthage)
    let version = try options.releaseVersion(config)
    let workDir = URL(fileURLWithPath: options.workDir)
    let input = distribution ?? distributionRoot(workDir: options.workDir, config: config).path
    let found = try await readDistribution(at: input)
    defer { found.removeExtracted() }

    // The extra build's own work directory; its plan and logs land there too.
    var buildOptions = options
    buildOptions.workDir = workDir.appendingPathComponent("carthage-build").path
    var buildConfig = options.applyingFlags(to: config)
    buildConfig.build.defines += rebuild?.defines ?? []
    // Planned up front: the umbrella framework needs the iOS deployment target, and the extra
    // build's frameworks are checked for signatures before anything is compiled.
    let plans = try await carthagePlans(buildConfig, rebuild: rebuild?.product, version: version,
                                        needed: carthage.umbrellaFramework != nil)
    let rebuilt = plans?.rebuild?.frameworks.map(\.name) ?? []
    try checkUnsigned(xcframeworksChangedByCarthage(found, rebuilt: rebuilt,
                                                    files: carthage.files))

    let staged = try stageDistribution(found.root, at: distributionRoot(
      workDir: buildOptions.workDir, config: config
    ))
    if let rebuildPlan = plans?.rebuild {
      let defines = (rebuild?.defines ?? []).joined(separator: " ")
      logger.info("Extra build: \(rebuildPlan.frameworks.count) frameworks with \(defines)")
      let planFile = try buildOptions.writePlan(rebuildPlan)
      logger.info("Planned: \(planFile.path)")
      let xcframeworks = try await buildOptions.build(rebuildPlan, cacheDir: cacheDir)
      let replaced = try replacingFrameworks(rebuilt, in: staged, from: xcframeworks)
      let list = replaced.isEmpty ? "none" : replaced.joined(separator: ", ")
      logger.info("Replaced with the extra build: \(list)")
    }
    try addCarthageFiles(carthage.files, in: staged)
    if let umbrella = carthage.umbrellaFramework {
      try makeUmbrellaFramework(umbrella, in: staged, version: version,
                                iOSDeploymentTarget: plans?.iOSDeploymentTarget,
                                packageRoot: options.packagePath)
    }

    let outputDirectory = URL(fileURLWithPath: output ?? workDir.appendingPathComponent("carthage")
      .path).appendingPathComponent(version)
    // Archives are named by their contents, so an earlier run's would linger beside them.
    try? FileManager.default.removeItem(at: outputDirectory)
    let archives = try await makeCarthageArchives(of: staged, carthage, version: version,
                                                  packageRoot: options.packagePath,
                                                  output: outputDirectory)
    logger.info("Carthage: \(archives.count) archives and binary specs in \(outputDirectory.path)")
  }

  /// `carthage.rebuild` and `carthage.defines`, which go together; nil without an extra build.
  private func extraBuild(of carthage: Config.Carthage) throws
    -> (product: String, defines: [String])? {
    switch (carthage.rebuild, carthage.defines) {
    case (nil, nil):
      return nil
    case let (product?, defines?) where !defines.isEmpty:
      return (product, defines)
    default:
      throw ZipBuilderError("carthage.rebuild and carthage.defines go together: set both "
        + "(with at least one define), or neither.")
    }
  }

  /// The whole release's plan with `config`, for its iOS deployment target, and the extra build's
  /// plan (`restricting`) when there's a `rebuild` product. Nil when neither is `needed`.
  private func carthagePlans(_ config: Config, rebuild: String?, version: String,
                             needed: Bool) async throws
    -> (iOSDeploymentTarget: String?, rebuild: Plan?)? {
    guard needed || rebuild != nil else { return nil }
    let graph = try await loadPackage(at: options.packagePath)
    let root = options.packagePath
    let whole = try customize(makePlan(graph, config, version: version), config,
                              packageRoot: root, version: version)
    var target: String?
    if case let .string(value) = whole.settings["IPHONEOS_DEPLOYMENT_TARGET"] {
      target = value
    }
    guard let rebuild else { return (target, nil) }
    // Only its names are used. Its warnings repeat the whole plan's, or only reflect planning
    // one product (shared frameworks outside any folder), so they're dropped.
    let product = try Warnings.$collected.withValue(Warnings()) {
      do {
        return try customize(makePlan(graph, config, version: version, product: rebuild), config,
                             packageRoot: root, version: version)
      } catch {
        throw ZipBuilderError("carthage.rebuild: \(error)")
      }
    }
    let names = product.frameworkNames.union(product.binaries.map(\.name))
    return (target, restricting(whole, toWhatIsReachedFrom: names))
  }
}
