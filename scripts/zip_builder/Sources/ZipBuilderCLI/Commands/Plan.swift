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
import Common
import Foundation
import Logging
import ManifestReader

/// CLI subcommand that parses `Package.swift` and outputs a structured JSON or ASCII summary build
/// plan.
public struct Plan: AsyncParsableCommand {
  public enum Format: EnumerableFlag {
    case json
    case summary
  }

  /// Subcommand configuration and documentation.
  public static let configuration = CommandConfiguration(
    commandName: "plan",
    abstract: "Inspect Package.swift and export a build plan for all the products found.",
    discussion: """
    EXAMPLES:
      zip-builder plan --summary
      zip-builder plan --project-name Firebase --version 12.19.0 --bundle-id-prefix com.google.firebase -o ./plan.json
      zip-builder plan --platforms ios --platforms macos --summary
    """
  )

  /// Shared manifest options.
  @OptionGroup
  public var manifestOptions: ManifestOptions

  /// Shared platform options.
  @OptionGroup
  public var platformOptions: PlatformOptions

  /// Shared target options.
  @OptionGroup
  public var targetOptions: TargetOptions

  /// Output format mode (`json` or `summary`).
  @Flag(help: "Output format.")
  public var format: Format = .json

  /// Optional file path to write the JSON plan into.
  @Option(name: .shortAndLong, help: "Output file to write the plan to (defaults to stdout).")
  public var outputFile: String?

  /// Initializes the plan subcommand.
  public init() {}

  /// Executes build plan resolution and outputs the formatted plan.
  public mutating func run() async throws {
    LoggingConfig.bootstrap()
    let logger = Logger(label: "zip-builder.plan")
    logger.debug(
      "Resolving build plan",
      metadata: [
        "format": "\(format)",
        "outputFile": "\(outputFile ?? "stdout")",
      ]
    )

    let options = try manifestOptions.buildOptions(
      platformOptions: platformOptions,
      targetOptions: targetOptions
    )

    let plan = try await PlanningEngine.resolve(
      packageURL: URL(filePath: manifestOptions.packagePath),
      configURL: manifestOptions.config.map { URL(filePath: $0) },
      options: options,
      logger: logger
    )

    logger.debug(
      "Build plan resolved",
      metadata: [
        "productCount": "\(plan.products.count)",
        "helperModuleCount": "\(plan.aggregatedSubmodules.count)",
      ]
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let jsonData = try encoder.encode(plan)
    let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

    if format == .summary {
      print("========================================")
      print("Build Plan")
      print("========================================")
      print("Version: \(plan.config.version)")
      print("Project: \(plan.config.projectName)")
      print("Bundle ID: \(plan.config.bundleIdPrefix)")
      print("Total Products: \(plan.products.count)")
      print(
        "Target Platforms: \(plan.config.targetPlatforms.map(\.canonicalName).joined(separator: ", "))"
      )
      print("----------------------------------------")
      for product in plan.products {
        print("- Product: \(product.name)")
        let sourceNames = product.targets.map(\.name).joined(separator: ", ")
        let binaryNames = product.binaryTargets.map(\.name).joined(separator: ", ")
        if !sourceNames.isEmpty {
          print("  Source Targets: \(sourceNames)")
        }
        if !binaryNames.isEmpty {
          print("  Binary Targets: \(binaryNames)")
        }
        if !product.resourceBundles.isEmpty {
          print("  Resource Bundles: \(product.resourceBundles.joined(separator: ", "))")
        }
      }
      print("========================================")
    } else {
      if let outputFile {
        let outputURL = URL(filePath: outputFile)
        try jsonData.write(to: outputURL)
        logger.info("Successfully exported plan", metadata: ["path": "\(outputURL.path)"])
      } else {
        print(jsonString)
      }
    }
  }
}
