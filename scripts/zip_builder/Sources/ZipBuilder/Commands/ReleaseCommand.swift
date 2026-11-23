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

struct ReleaseCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "release",
    abstract: "Plan, build and package the release, then verify it."
  )

  @OptionGroup var options: SharedOptions
  @OptionGroup var logging: LoggingOptions

  @Option(help: "Sign every unsigned .xcframework with this identity (\"-\" for ad-hoc).")
  var sign: String?

  @Option(help: "The framework cache.")
  var cacheDir = FrameworkCache.defaultDirectory

  @Flag(help: "After building, remove the cache entries this build didn't use.")
  var pruneCache = false

  func run() async throws {
    logging.apply()
    let config = try options.loadConfig()
    let version = try options.releaseVersion(config)
    var timings: [String] = []
    // Runs one stage and records how long it took, for the `Stages:` line.
    func timed<T>(_ stage: String, _ body: () async throws -> T) async rethrows -> T {
      let start = ContinuousClock.now
      defer { timings.append("\(stage) \(formatted(.now - start))") }
      return try await body()
    }

    let plan = try await timed("plan") {
      let plan = try await options.makeCustomizedPlan(config)
      let planFile = try options.writePlan(plan)
      logger.info("Planned: \(planFile.path)")
      return plan
    }
    let xcframeworks = try await timed("build") {
      try await options.build(plan, cacheDir: cacheDir, pruneCache: pruneCache)
    }
    let root = try await timed("package") {
      try await options.package(plan, config, xcframeworks: xcframeworks, sign: sign,
                                version: version)
    }
    let passed = try await timed("verify") {
      let distribution = try await readDistribution(at: root.path)
      // Dependencies left out of the folders were still built: verify links against them.
      // Otherwise none are passed, so a normal release verifies exactly as before.
      let leftOut = options.applyingFlags(to: config).products.withoutDependencies
      let dependencies = try await leftOut ? readXCFrameworks(in: xcframeworks) : []
      return try await verifyAndReport(distribution, at: root.path, config: config,
                                       requireSignatures: sign != nil,
                                       dependencies: dependencies)
    }
    // Logged before failing, so a failed verification still reports how long each stage took.
    logger.info("Stages: \(timings.joined(separator: ", "))")
    if !passed {
      throw ExitCode.failure
    }
  }
}
