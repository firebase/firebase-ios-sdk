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
import PathKit
import XcodeProj

/// The only configuration: only Release is archived, so a Debug one would just repeat it.
private let configurationName = "Release"

/// Writes the plan as an `.xcodeproj` at `projectPath`. The project directory is the package
/// root (an absolute path), so the plan's relative paths resolve against `SRCROOT`. Generated
/// files go in `Generated/<Framework>/` next to the project.
func makeProject(_ plan: Plan, packageRoot: Path, at projectPath: Path) throws {
  let projectURL = URL(fileURLWithPath: projectPath).standardizedFileURL
  let generated = projectURL.deletingLastPathComponent().appendingPathComponent("Generated")
  try? FileManager.default.removeItem(at: generated)
  let root = URL(fileURLWithPath: packageRoot).standardizedFileURL.path

  let pbxproj = PBXProj()
  let mainGroup = pbxproj.adding(PBXGroup(sourceTree: .group))
  let productsGroup = pbxproj.adding(PBXGroup(sourceTree: .group, name: "Products"))
  let binariesGroup = pbxproj.adding(PBXGroup(sourceTree: .group, name: "Binaries"))
  let project = pbxproj.adding(PBXProject(
    name: projectURL.deletingPathExtension().lastPathComponent,
    buildConfigurationList: pbxproj.configurations(xcodeSettings(plan.settings, isTarget: false)),
    compatibilityVersion: Xcode.Default.compatibilityVersion,
    preferredProjectObjectVersion: nil, minimizedProjectReferenceProxies: nil,
    mainGroup: mainGroup, developmentRegion: Xcode.Default.developmentRegion,
    knownRegions: knownRegions(plan), productsGroup: productsGroup, projectDirPath: root,
    attributes: ["BuildIndependentTargetsInParallel": "YES"]
  ))
  pbxproj.rootObject = project

  // Binaries and framework products are what dependents link.
  var linked: [String: PBXFileReference] = [:]
  for binary in plan.binaries {
    linked[binary.name] = pbxproj.fileReference(binary.path, in: binariesGroup)
  }
  var targets: [String: PBXNativeTarget] = [:]
  for framework in plan.frameworks {
    let framework = try addingGeneratedFiles(
      to: framework, packageRoot: root,
      directory: generated.appendingPathComponent(framework.name).path
    )
    let group = pbxproj.adding(PBXGroup(sourceTree: .group, name: framework.name))
    mainGroup.children.append(group)
    let product = pbxproj.adding(PBXFileReference(
      sourceTree: .buildProductsDir, explicitFileType: "wrapper.framework",
      path: "\(framework.name).framework", includeInIndex: false
    ))
    productsGroup.children.append(product)
    let target = pbxproj.target(for: framework, product: product, group: group)
    project.targets.append(target)
    targets[framework.name] = target
    linked[framework.name] = product
  }
  mainGroup.children += [binariesGroup, productsGroup]

  // Dependencies.
  for framework in plan.frameworks {
    let target = targets[framework.name]! // every framework got a target above
    let linkPhase = target.buildPhases.compactMap { $0 as? PBXFrameworksBuildPhase }.first
    for dependency in framework.dependencies {
      let filters = platformFilters(dependency.platforms)
      // A framework built here is also a target dependency, so Xcode builds it first; a binary
      // is only linked.
      if let dependencyTarget = targets[dependency.name] {
        let proxy = pbxproj.adding(PBXContainerItemProxy(
          containerPortal: .project(project), remoteGlobalID: .object(dependencyTarget),
          proxyType: .nativeTarget, remoteInfo: dependency.name
        ))
        target.dependencies.append(pbxproj.adding(PBXTargetDependency(
          name: dependency.name, platformFilters: filters, target: dependencyTarget,
          targetProxy: proxy
        )))
      }
      guard let file = linked[dependency.name] else {
        warn("\(framework.name) depends on \(dependency.name), which isn't in the plan.")
        continue
      }
      linkPhase?.files?.append(pbxproj.adding(PBXBuildFile(file: file, platformFilters: filters)))
    }
  }

  let schemes = schemeDestinations(plan).map { destination in
    scheme(named: destination.name, building: plan.frameworks.filter {
      $0.platforms.contains(destination.platform)
    }.compactMap { targets[$0.name] }, projectPath: projectURL.path)
  }
  try? FileManager.default.removeItem(at: projectURL)
  let path = PathKit.Path(projectURL.path)
  try XcodeProj(workspace: XCWorkspace(), pbxproj: pbxproj,
                sharedData: XCSharedData(schemes: schemes)).write(path: path)
  // Only the destination schemes; Xcode would otherwise add one per target.
  let workspaceData = XcodeProj.workspacePath(path) + "xcshareddata"
  try workspaceData.mkpath()
  try WorkspaceSettings(autoCreateSchemes: false)
    .write(path: workspaceData + "WorkspaceSettings.xcsettings", override: true)
}

/// The destinations that have frameworks to build, one scheme each.
func schemeDestinations(_ plan: Plan) -> [Destination] {
  Destination.all.filter { destination in
    plan.frameworks.contains { $0.platforms.contains(destination.platform) }
  }
}

/// `platforms` as build-file and target-dependency platform filters; `nil` means every platform.
func platformFilters(_ platforms: Set<Platform>?) -> [String]? {
  platforms.map { $0.sorted().map(\.platformFilter) }
}

/// The plan's settings in XcodeProj's form. Relative search paths are rooted at `$(SRCROOT)`, and
/// a target's list settings start with `$(inherited)`, so they extend the project's instead of
/// hiding them.
func xcodeSettings(_ settings: BuildSettings, isTarget: Bool) -> [String: Any] {
  var result: [String: Any] = [:]
  for key in settings.keys {
    switch settings[key] {
    case let .string(value)?:
      result[key] = value
    case let .list(values)?:
      var items = isPathSetting(key) ? values.map(rootedAtSourceRoot) : values
      if isTarget, items.first != "$(inherited)" {
        items.insert("$(inherited)", at: 0)
      }
      result[key] = items
    case nil:
      continue
    }
  }
  return result
}

/// A framework target's settings: the plan's, plus the platforms it may be built for, so Xcode
/// never builds it elsewhere.
func targetSettings(_ framework: Framework) -> [String: Any] {
  var settings = framework.settings
  var sdks = framework.platforms.sorted().filter { $0 != .catalyst }.flatMap(\.sdks)
  if framework.platforms.contains(.catalyst), !framework.platforms.contains(.ios) {
    sdks.append("iphoneos") // Mac Catalyst builds iOS targets.
  }
  settings["SUPPORTED_PLATFORMS"] = .string(sdks.joined(separator: " "))
  if !framework.platforms.contains(.catalyst) {
    settings["SUPPORTS_MACCATALYST"] = "NO"
  }
  return xcodeSettings(settings, isTarget: true)
}

private func isPathSetting(_ key: String) -> Bool {
  isHeaderSearchPathSetting(key)
    || ["FRAMEWORK_SEARCH_PATHS", "LIBRARY_SEARCH_PATHS"].contains { key.hasPrefix($0) }
}

private func rootedAtSourceRoot(_ path: String) -> String {
  if path.hasPrefix("$(") || path.hasPrefix("/") {
    return path
  }
  return path == "." ? "$(SRCROOT)" : "$(SRCROOT)/\(path)"
}

/// The development region, `Base`, and every localization of a resource.
private func knownRegions(_ plan: Plan) -> [String] {
  var regions = [Xcode.Default.developmentRegion, "Base"]
  for resource in plan.frameworks.flatMap(\.resources) {
    if case let .process(localization?) = resource.rule, !regions.contains(localization) {
      regions.append(localization)
    }
  }
  return regions
}

/// A shared scheme that builds and archives `targets` in Release. Xcode resolves a `container:`
/// reference against the project directory (the package root), so it's absolute.
private func scheme(named name: String, building targets: [PBXNativeTarget],
                    projectPath: String) -> XCScheme {
  let entries = targets.map { target in
    XCScheme.BuildAction.Entry(
      buildableReference: XCScheme.BuildableReference(
        referencedContainer: "absolute:\(projectPath)", blueprint: target,
        buildableName: "\(target.name).framework", blueprintName: target.name
      ),
      buildFor: [.running, .profiling, .archiving, .analyzing]
    )
  }
  // What Xcode 16 and later write. XcodeProj's defaults (`Xcode.Default.lastUpgradeCheck`
  // "1300", `xcschemeFormatVersion` "1.3") are Xcode 13's, so Xcode would offer to upgrade the
  // schemes whenever the project is opened.
  return XCScheme(
    name: name, lastUpgradeVersion: "1600", version: "1.7",
    buildAction: XCScheme.BuildAction(buildActionEntries: entries, parallelizeBuild: true,
                                      buildImplicitDependencies: true),
    testAction: XCScheme.TestAction(buildConfiguration: configurationName, macroExpansion: nil),
    launchAction: XCScheme.LaunchAction(runnable: nil, buildConfiguration: configurationName),
    profileAction: XCScheme.ProfileAction(buildableProductRunnable: nil,
                                          buildConfiguration: configurationName),
    analyzeAction: XCScheme.AnalyzeAction(buildConfiguration: configurationName),
    archiveAction: XCScheme.ArchiveAction(buildConfiguration: configurationName,
                                          revealArchiveInOrganizer: false)
  )
}

extension PBXProj {
  /// Adds `object` to the project and returns it.
  @discardableResult
  func adding<Object: PBXObject>(_ object: Object) -> Object {
    add(object: object)
    return object
  }

  /// A framework target with its build phases. Dependencies are linked later.
  func target(for framework: Framework, product: PBXFileReference,
              group: PBXGroup) -> PBXNativeTarget {
    let headers = adding(PBXHeadersBuildPhase(files: framework.headers.map { header in
      let attributes: [String: Any]? = switch header.visibility {
      case .public: ["ATTRIBUTES": ["Public"]]
      case .private: ["ATTRIBUTES": ["Private"]]
      case .project: nil
      }
      return adding(PBXBuildFile(file: fileReference(header.path, in: group),
                                 settings: attributes))
    }))
    let sources = adding(PBXSourcesBuildPhase(files: framework.sources.map { source in
      adding(PBXBuildFile(file: fileReference(source.path, in: group),
                          platformFilters: platformFilters(source.platforms)))
    }))
    let resources = adding(PBXResourcesBuildPhase(files: resourceFiles(framework.resources,
                                                                       in: group)))
    return adding(PBXNativeTarget(
      name: framework.name,
      buildConfigurationList: configurations(targetSettings(framework)),
      buildPhases: [headers, sources, adding(PBXFrameworksBuildPhase(files: [])), resources],
      productName: framework.name, product: product,
      productType: framework.isDynamic ? .framework : .staticFramework
    ))
  }

  /// Resources phase entries: a processed file as it is, a localized one in a variant group
  /// (`en.lproj/Main.strings` → `Main.strings`), and a copied directory as a folder reference.
  /// Embedded resources are already generated sources.
  private func resourceFiles(_ resources: [Resource], in group: PBXGroup) -> [PBXBuildFile] {
    var files: [PBXBuildFile] = []
    var variantGroups: [String: PBXVariantGroup] = [:]
    for resource in resources {
      switch resource.rule {
      case .process(localization: nil):
        files.append(adding(PBXBuildFile(file: fileReference(resource.path, in: group))))
      case let .process(localization?):
        let name = fileName(resource.path)
        // `en.lproj/Main.strings` and `fr.lproj/Main.strings` share one variant group, keyed by
        // the directory that holds the `.lproj` directories, plus the file name.
        let lproj = (resource.path as NSString).deletingLastPathComponent
        let key = (lproj as NSString).deletingLastPathComponent + "/" + name
        if variantGroups[key] == nil {
          let created = adding(PBXVariantGroup(sourceTree: .group, name: name))
          group.children.append(created)
          files.append(adding(PBXBuildFile(file: created)))
          variantGroups[key] = created
        }
        fileReference(resource.path, in: variantGroups[key]!, name: localization)
      case .copy:
        files.append(adding(PBXBuildFile(file: fileReference(resource.path, in: group,
                                                             fileType: "folder"))))
      case .embedInCode:
        continue
      }
    }
    return files
  }

  /// A configuration list with a single Release configuration.
  func configurations(_ settings: [String: Any]) -> XCConfigurationList {
    let release = adding(XCBuildConfiguration(name: configurationName, buildSettings: settings))
    return adding(XCConfigurationList(buildConfigurations: [release],
                                      defaultConfigurationName: configurationName))
  }

  /// A reference to the file at `path`: relative to the package root (the project directory),
  /// or absolute (generated files).
  @discardableResult
  func fileReference(_ path: Path, in group: PBXGroup, name: String? = nil,
                     fileType: String? = nil) -> PBXFileReference {
    let pathExtension = (path as NSString).pathExtension
    let reference = adding(PBXFileReference(
      sourceTree: path.hasPrefix("/") ? .absolute : .sourceRoot,
      name: name ?? fileName(path),
      lastKnownFileType: fileType ?? Xcode.filetype(extension: pathExtension) ?? "file",
      path: path
    ))
    group.children.append(reference)
    return reference
  }
}
