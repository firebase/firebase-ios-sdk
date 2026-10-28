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

/// Builds every framework's `.xcframework` and copies them, with their layout applied, and the
/// plan's binaries into `<workDir>/xcframeworks/`.
///
/// Frameworks found in `cache` are linked as prebuilt binaries instead of compiled; the rest are
/// archived once per destination and stored in the cache. With `project` (a hand-edited project),
/// every framework is compiled from that project, and the cache is neither read nor written.
func buildXCFrameworks(_ plan: Plan, packageRoot: Path, workDir: Path, cache: FrameworkCache?,
                       project: Path? = nil) async throws -> [Path] {
  let packageRoot = URL(fileURLWithPath: packageRoot).standardizedFileURL.path
  let workDir = URL(fileURLWithPath: workDir).standardizedFileURL
  // Before any work: a dynamic framework that links a static binary, or a framework the plan
  // keeps static, can't be built correctly.
  let staticBinaries = try await staticBinaries(reachedByDynamicFrameworksIn: plan,
                                                packageRoot: packageRoot)
  try checkDynamicFrameworksLinkNothingStatic(plan, staticBinaries: staticBinaries)
  // A hand-edited project isn't what the plan describes, so the plan's fingerprints can't key it.
  let cache = project == nil ? cache : nil
  for directory in ["archives", "created"] {
    try? FileManager.default.removeItem(at: workDir.appendingPathComponent(directory))
  }
  try? FileManager.default.removeItem(at: xcframeworksDirectory(workDir: workDir.path))

  // Partition: cached frameworks become binaries, so Xcode links them instead of building them.
  var keys: [String: String] = [:]
  var cached: [String: Path] = [:]
  if let cache {
    keys = try await fingerprints(of: plan, packageRoot: packageRoot, xcodeVersion: xcodeVersion(),
                                  excluding: [workDir.path, cache.directory])
    for framework in plan.frameworks {
      let key = keys[framework.name]!
      let isCached = cache.has(key, name: framework.name)
      logger.debug("\(framework.name): fingerprint \(key), \(isCached ? "cached" : "not cached")")
      if isCached {
        cached[framework.name] = cache.path(for: key, name: framework.name)
      }
    }
  }
  let buildPlan = replacingCachedFrameworks(plan, with: cached, staticBinaries: staticBinaries)
  logger.info("""
  \(plan.frameworks.count) frameworks: \(cached.count) from the cache, \
  \(buildPlan.frameworks.count) to compile
  """)
  if !buildPlan.frameworks.isEmpty {
    logger.info("Compiling: \(buildPlan.frameworks.map(\.name).joined(separator: ", "))")
  }

  // Archive and create the missing frameworks.
  var finished = cached // name → finished `.xcframework`; the compiled ones are added below
  if !buildPlan.frameworks.isEmpty {
    let generatedProject = workDir.appendingPathComponent("build-project/Frameworks.xcodeproj").path
    let projectPath = project ?? generatedProject
    if project == nil {
      try makeProject(buildPlan, packageRoot: packageRoot, at: projectPath)
    }
    let archives = try await archive(buildPlan, project: projectPath, workDir: workDir)
    for framework in buildPlan.frameworks {
      let xcframework = try await createXCFramework(
        framework, from: archives, in: workDir.appendingPathComponent("created")
      )
      if let cache {
        let key = keys[framework.name]!
        try cache.store(xcframework, for: key)
        // The cache entry, not the copy in `created/`, so cached and newly built frameworks are
        // both copied into `xcframeworks/` from the cache.
        finished[framework.name] = cache.path(for: key, name: framework.name)
      } else {
        finished[framework.name] = xcframework
      }
    }
  } else {
    logger.info("Archives: none")
  }
  return try copyFinished(plan, xcframeworks: finished, packageRoot: packageRoot,
                          to: xcframeworksDirectory(workDir: workDir.path))
}

/// Where `buildXCFrameworks` puts the finished `.xcframework`s: `<workDir>/xcframeworks`.
func xcframeworksDirectory(workDir: Path) -> URL {
  URL(fileURLWithPath: workDir).appendingPathComponent("xcframeworks").standardizedFileURL
}

/// Copies every framework's finished `.xcframework` (`xcframeworks`: name → path) and every binary
/// into `output`, and applies each framework's layout to its copy. Layout comes after caching, so
/// it changes a copy (an APFS clone), never the cache.
private func copyFinished(_ plan: Plan, xcframeworks: [String: Path], packageRoot: Path,
                          to output: URL) throws -> [Path] {
  let manager = FileManager.default
  try manager.createDirectory(at: output, withIntermediateDirectories: true)
  var paths: [Path] = []
  for framework in plan.frameworks {
    let destination = output.appendingPathComponent("\(framework.name).xcframework")
    try manager.copyItem(at: URL(fileURLWithPath: xcframeworks[framework.name]!), to: destination)
    try applyLayout(framework.layout, to: destination.path, name: framework.name)
    paths.append(destination.path)
  }
  for binary in plan.binaries {
    let destination = output.appendingPathComponent("\(binary.name).xcframework")
    try manager.copyItem(at: URL(fileURLWithPath: fullPath(binary.path, packageRoot)),
                         to: destination)
    paths.append(destination.path)
  }
  return paths
}

/// The plan Xcode builds: each framework in `cached` (name → cached `.xcframework`) becomes a
/// binary with the same name, platforms and version, so dependents link it.
///
/// Xcode only makes a linked `.xcframework`'s module visible to the targets that link it, while a
/// built target's module is visible to every later target. Sources may import any transitive
/// dependency, as in SwiftPM (`FirebaseAuth` imports `FirebaseCoreInternal` through
/// `FirebaseCore`), so each static framework left to build also links every binary it reaches.
///
/// A dynamic framework links everything it reaches, targets and cached binaries alike, even with
/// nothing cached, so a cached build adds no load commands an uncached one doesn't have. It never
/// links one of `staticBinaries`, which would copy their code into it (`buildXCFrameworks` fails
/// on those first).
func replacingCachedFrameworks(_ plan: Plan, with cached: [String: Path],
                               staticBinaries: Set<String> = []) -> Plan {
  guard !cached.isEmpty || plan.frameworks.contains(where: \.isDynamic) else { return plan }
  var result = plan
  result.frameworks = []
  for framework in plan.frameworks {
    if let path = cached[framework.name] {
      result.binaries.append(Binary(name: framework.name, path: path,
                                    platforms: framework.platforms, version: framework.version))
    } else {
      result.frameworks.append(framework)
    }
  }
  let binaries = Set(result.binaries.map(\.name))
  for index in result.frameworks.indices {
    let framework = result.frameworks[index]
    // Walked in `plan`, where cached frameworks still have their dependencies.
    let reached = reachedDependencies(from: framework, in: plan)
    if framework.isDynamic {
      result.frameworks[index].dependencies = mergingDuplicates(
        framework.dependencies + reached.filter { !staticBinaries.contains($0.name) }
      )
    } else if !cached.isEmpty {
      result.frameworks[index].dependencies = mergingDuplicates(
        framework.dependencies + reached.filter { binaries.contains($0.name) }
      )
    }
  }
  return result
}

/// Archives every destination that has frameworks to build, one after another, and returns the
/// archives by destination name. Each `xcodebuild`'s output goes to `<workDir>/logs/`.
private func archive(_ plan: Plan, project: Path, workDir: URL) async throws -> [String: URL] {
  let logs = workDir.appendingPathComponent("logs")
  let derivedData = workDir.appendingPathComponent("DerivedData")
  try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
  let settings = archiveSettings(plan)
  var archives: [String: URL] = [:]
  var times: [String] = []
  for destination in schemeDestinations(plan) {
    let archive = workDir.appendingPathComponent("archives/\(destination.name).xcarchive")
    let log = logs.appendingPathComponent("archive-\(destination.name).log").path
    logger.info("Archiving \(destination.name) (log: \(log))")
    let start = ContinuousClock.now
    let result = try await runTool("xcodebuild", [
      "archive", "-project", project, "-scheme", destination.name,
      "-destination", destination.xcodebuildDestination, "-archivePath", archive.path,
      "-derivedDataPath", derivedData.appendingPathComponent(destination.name).path,
    ] + settings, logFile: log)
    guard result.status == 0 else {
      throw ZipBuilderError("Archiving \(destination.name) failed:\n\(firstErrors(in: log))\n"
        + "Full log: \(log)")
    }
    let time = "\(destination.name) \(formatted(.now - start))"
    times.append(time)
    logger.info("Archived \(time)")
    archives[destination.name] = archive
  }
  logger.info("Archives: \(times.joined(separator: ", "))")
  return archives
}

/// The settings every archive passes: compilation caching on, and the two settings the plan's
/// project settings may already set.
private func archiveSettings(_ plan: Plan) -> [String] {
  var settings = ["COMPILATION_CACHE_ENABLE_CACHING=YES"]
  if plan.settings["SKIP_INSTALL"] == nil {
    settings.append("SKIP_INSTALL=NO")
  }
  if plan.settings["BUILD_LIBRARY_FOR_DISTRIBUTION"] == nil {
    settings.append("BUILD_LIBRARY_FOR_DISTRIBUTION=YES")
  }
  return settings
}

/// The first `error:` lines of an `xcodebuild` log, without repeats.
func firstErrors(in log: Path, limit: Int = 20) -> String {
  let text = (try? String(contentsOfFile: log, encoding: .utf8)) ?? ""
  var errors: [String] = []
  for line in text.split(separator: "\n") where line.contains("error:") {
    let line = String(line)
    if !errors.contains(line) {
      errors.append(line)
    }
    if errors.count == limit {
      break
    }
  }
  return errors.isEmpty ? "(no error: lines)" : errors.joined(separator: "\n")
}

/// `xcodebuild -create-xcframework` from the framework's slice in each of its destinations'
/// archives. No dSYMs, like the reference zip.
private func createXCFramework(_ framework: Framework, from archives: [String: URL],
                               in directory: URL) async throws -> Path {
  guard !framework.platforms.isEmpty else {
    throw ZipBuilderError("\(framework.name) has no platforms, so there's nothing to build.")
  }
  var arguments = ["-create-xcframework"]
  for destination in framework.destinations {
    let slice = archives[destination.name]?
      .appendingPathComponent("Products/Library/Frameworks/\(framework.name).framework")
    guard let slice, FileManager.default.fileExists(atPath: slice.path) else {
      throw ZipBuilderError("The \(destination.name) archive has no \(framework.name).framework.")
    }
    arguments += ["-framework", slice.path]
  }
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let output = directory.appendingPathComponent("\(framework.name).xcframework").path
  try await shell("xcodebuild", arguments + ["-output", output])
  return output
}
