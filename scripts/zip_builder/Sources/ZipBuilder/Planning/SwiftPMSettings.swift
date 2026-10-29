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

/// Project-wide settings.
func projectSettings(_ root: ResolvedPackage) -> BuildSettings {
  let sdks = Platform.allCases.flatMap(\.sdks).uniqued() // macOS and Catalyst share `macosx`
  let settings: BuildSettings = [
    "SUPPORTED_PLATFORMS": .string(sdks.joined(separator: " ")),
    "SUPPORTS_MACCATALYST": "YES",
    // iPhone, iPad, TV, Watch, Vision. Mac Catalyst keeps the default iPad idiom, because 6
    // ("Optimize for Mac") would change how storyboards and asset catalogs compile.
    "TARGETED_DEVICE_FAMILY": "1,2,3,4,7",
    "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES",
    // Release builds optimize each Swift module as a whole, as SwiftPM's release builds and
    // CocoaPods' Release configuration do; Xcode's default compiles file by file.
    "SWIFT_COMPILATION_MODE": "wholemodule",
    // Set by SwiftPM for every package target, so sources compile as they do under SwiftPM.
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_ENABLE_MODULES": "YES",
    "USE_HEADERMAP": "NO",
    "GENERATE_INFOPLIST_FILE": "YES",
    // Every framework's Info.plist gets CFBundleVersion = 1, as in earlier release zips.
    "CURRENT_PROJECT_VERSION": "1",
    // Every framework defines <Name>VersionNumber/String, as in earlier release zips.
    "VERSIONING_SYSTEM": "apple-generic",
    "SKIP_INSTALL": "NO",
    "DEFINES_MODULE": "YES",
    "CODE_SIGNING_ALLOWED": "NO",
    "CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES": "YES",
    // Defined by SwiftPM for package builds.
    "GCC_PREPROCESSOR_DEFINITIONS": ["SWIFT_PACKAGE=1"],
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": ["SWIFT_PACKAGE"],
  ]
  return settings.merging(deploymentTargets(root))
}

/// Declared deployment targets, else SwiftPM's derived ones.
func deploymentTargets(_ root: ResolvedPackage) -> BuildSettings {
  func version(_ platform: Platform) -> String {
    // SwiftPM's derived version raises a declared one to the oldest it supports (macOS 11 → 12),
    // so it's only the fallback.
    let declared = root.supportedPlatforms.first { $0.platform == platform.swiftPM }
    let supported = declared
      ?? root.getSupportedPlatform(for: platform.swiftPM, usingXCTest: false)
    return supported.version.versionString
  }
  var settings = BuildSettings()
  for platform in Platform.allCases where platform != .catalyst {
    settings[platform.deploymentTargetKey] = .string(version(platform))
  }
  // Mac Catalyst reads IPHONEOS_DEPLOYMENT_TARGET, which macOS ignores, so conditioning it on
  // the shared macosx SDK only affects Catalyst.
  if version(.catalyst) != version(.ios) {
    settings["IPHONEOS_DEPLOYMENT_TARGET[sdk=macosx*]"] = .string(version(.catalyst))
  }
  return settings
}

/// What makes a framework dynamic. Its install name is `@rpath/<Name>.framework/<Name>`, as with
/// CocoaPods, so an app finds it in its own `Frameworks/`; Xcode's default base is
/// `/Library/Frameworks`, where no app can embed it.
let dynamicFrameworkSettings: BuildSettings = [
  "MACH_O_TYPE": "mh_dylib",
  "DYLIB_INSTALL_NAME_BASE": "@rpath",
]

/// All of a framework target's own settings: its identity, language versions, the settings its
/// module declares, and its header search paths. `frameworkNames` maps targets to the framework
/// they end up in (`finalFrameworkNames`), for `dependencyIncludeDirectories`.
func frameworkSettings(_ module: ResolvedModule, bundleID: String, version: String,
                       isDynamic: Bool, packageRoot: AbsolutePath,
                       frameworkNames: [String: String]) throws -> BuildSettings {
  var settings: BuildSettings = [
    "PRODUCT_NAME": .string(module.name),
    "PRODUCT_MODULE_NAME": .string(module.c99name),
    "MACH_O_TYPE": "staticlib",
    "PRODUCT_BUNDLE_IDENTIFIER": .string(bundleID),
    "MARKETING_VERSION": .string(version),
  ]
  if isDynamic {
    settings.merge(dynamicFrameworkSettings)
  }
  if let swiftVersion = swiftLanguageMode(module) {
    settings["SWIFT_VERSION"] = .string(swiftVersion)
  }
  if let standard = clangInfo(of: module)?.cLanguageStandard {
    settings["GCC_C_LANGUAGE_STANDARD"] = .string(standard)
  }
  if let standard = clangInfo(of: module)?.cxxLanguageStandard {
    settings["CLANG_CXX_LANGUAGE_STANDARD"] = .string(standard)
  }
  settings.merge(evaluateBuildSettings(module, isDynamic: isDynamic, packageRoot: packageRoot))
  // Declared paths first, then the module's own, then its C++ dependencies' that need it.
  let declared = settings["HEADER_SEARCH_PATHS"]?.list ?? []
  let searched = try ownHeaderSearchPaths(of: module)
    + dependencyIncludeDirectories(of: module, frameworkNames: frameworkNames)
  let paths = searched.map { $0.relative(to: packageRoot).pathString }
  settings["HEADER_SEARCH_PATHS"] = .list((declared + paths).uniqued())
  return settings
}

/// The module's language mode in Xcode's spelling (`5` → `5.0`): its `.swiftLanguageMode`, else
/// SwiftPM's default assignment for the tools version.
func swiftLanguageMode(_ module: ResolvedModule) -> String? {
  // A target gets one SWIFT_VERSION (`evaluateBuildSettings` skips it, so it's never made
  // platform-conditional). iOS stands in for every platform: a platform-conditional
  // `.swiftLanguageMode` gets its iOS value.
  let environment = BuildEnvironment(platform: .iOS, configuration: .release)
  let scope = PackageModel.BuildSettings.Scope(module.underlying.buildSettings,
                                               environment: environment)
  guard let mode = scope.evaluate(.SWIFT_VERSION).last else { return nil }
  return mode.contains(".") ? mode : "\(mode).0"
}

/// Turns the module's declared settings into Xcode settings for a Release build. A value that
/// holds on only some platforms becomes a platform-conditional setting.
func evaluateBuildSettings(_ module: ResolvedModule, isDynamic: Bool,
                           packageRoot: AbsolutePath) -> BuildSettings {
  var settings = BuildSettings()
  let table = module.underlying.buildSettings.assignments
  for declaration in table.keys.sorted() where declaration != .SWIFT_VERSION {
    for assignment in table[declaration, default: []] where !assignment.default {
      guard let (key, values) = translate(declaration, assignment.values, module,
                                          isDynamic: isDynamic, packageRoot: packageRoot)
      else { continue }
      var platforms = platforms(where: assignment.conditions)
      if declaration == .LINK_FRAMEWORKS || declaration == .LINK_LIBRARIES {
        platforms = linkingPlatforms(platforms)
      }
      if platforms == Platform.allCases {
        settings.append(values, to: key)
      } else if !platforms.isEmpty {
        settings.add(values, to: key, onlyFor: platforms)
      }
    }
  }
  return settings
}

/// The platforms a linker setting applies on: those of its conditions, plus Mac Catalyst wherever
/// iOS is one, in `Platform.allCases` order. Only dynamic frameworks link, and they must link what
/// their code uses: Catalyst compiles the iOS code (`TARGET_OS_IOS` is 1 there), so a framework
/// linked for iOS is used there too. SwiftPM conditions keep Catalyst apart, but SwiftPM's app
/// links everything, and module imports autolink; Objective-C++ and C++ compile without modules,
/// so nothing else would link UIKit into a dynamic framework on Catalyst. CocoaPods' `ios`
/// covered Catalyst too.
func linkingPlatforms(_ platforms: [Platform]) -> [Platform] {
  guard platforms.contains(.ios) else { return platforms }
  return Platform.allCases.filter { platforms.contains($0) || $0 == .catalyst }
}

/// The Xcode setting for one SwiftPM declaration, or `nil` when it has none.
func translate(_ declaration: PackageModel.BuildSettings.Declaration, _ values: [String],
               _ module: ResolvedModule, isDynamic: Bool,
               packageRoot: AbsolutePath) -> (key: String, values: [String])? {
  switch declaration {
  case .HEADER_SEARCH_PATHS:
    return (declaration.name, values.map {
      resolveSearchPath($0, relativeTo: module.sources.root, packageRoot: packageRoot)
    })
  case .GCC_PREPROCESSOR_DEFINITIONS:
    return (declaration.name, values.map(escapingSpaces))
  case .LINK_FRAMEWORKS:
    // Static frameworks don't link; their dependents autolink.
    return isDynamic ? ("OTHER_LDFLAGS", values.flatMap { ["-framework", $0] }) : nil
  case .LINK_LIBRARIES:
    return isDynamic ? ("OTHER_LDFLAGS", values.map { "-l\($0)" }) : nil
  default:
    return (declaration.name, values)
  }
}

/// A declared search path relative to the package root. Absolute paths and Xcode macros are
/// kept as they are.
func resolveSearchPath(_ path: String, relativeTo directory: AbsolutePath,
                       packageRoot: AbsolutePath) -> String {
  guard !path.hasPrefix("$("), !path.hasPrefix("/"),
        let absolute = try? AbsolutePath(validating: path, relativeTo: directory)
  else { return path }
  return absolute.relative(to: packageRoot).pathString
}

/// Quotes a definition whose value has spaces: `K=a b` → `K=\"a\ b\"`.
func escapingSpaces(_ definition: String) -> String {
  guard definition.contains(" ") else { return definition }
  // `split` omits empty pieces, so `=a b` has no key and takes the no-`=` branch.
  let parts = definition.split(separator: "=", maxSplits: 1)
  guard parts.count == 2 else { return definition.replacingOccurrences(of: " ", with: #"\ "#) }
  let value = parts[1].replacingOccurrences(of: " ", with: #"\ "#)
  return #"\#(parts[0])=\"\#(value)\""#
}

extension BuildSettings {
  /// Adds `values` to `key` on `platforms` only.
  ///
  /// macOS and Mac Catalyst share the `macosx` SDK, so both go through a helper setting picked by
  /// `IS_MACCATALYST`. Conditional keys start with `$(inherited)` to keep the unconditional value.
  mutating func add(_ values: [String], to key: String, onlyFor platforms: [Platform]) {
    for platform in platforms where platform != .macos && platform != .catalyst {
      for sdk in platform.sdks {
        appendInheriting(values, to: "\(key)[sdk=\(sdk)*]")
      }
    }
    guard platforms.contains(.macos) || platforms.contains(.catalyst) else { return }
    if platforms.contains(.macos) {
      append(values, to: "\(key)_MACOS")
    }
    if platforms.contains(.catalyst) {
      append(values, to: "\(key)_CATALYST")
    }
    // IS_MACCATALYST is YES or NO, so this picks KEY_YES or KEY_NO.
    self["\(key)_NO"] = .string("$(\(key)_MACOS)")
    self["\(key)_YES"] = .string("$(\(key)_CATALYST)")
    self["\(key)[sdk=macosx*]"] = .list(["$(inherited)", "$(\(key)_$(IS_MACCATALYST))"])
  }

  private mutating func appendInheriting(_ values: [String], to key: String) {
    if self[key] == nil {
      self[key] = ["$(inherited)"]
    }
    append(values, to: key)
  }
}

extension Platform {
  /// The SwiftPM platform, for evaluating conditions.
  var swiftPM: PackageModel.Platform {
    switch self {
    case .ios: .iOS
    case .catalyst: .macCatalyst
    case .macos: .macOS
    case .tvos: .tvOS
    case .watchos: .watchOS
    case .visionos: .visionOS
    }
  }

  /// The platform for a SwiftPM platform; `nil` for platforms the zip doesn't ship (e.g. Linux).
  init?(swiftPM platform: PackageModel.Platform) {
    guard let match = Platform.allCases.first(where: { $0.swiftPM == platform }) else {
      return nil
    }
    self = match
  }
}

/// The platforms on which every condition holds, for a Release build, in `Platform.allCases`
/// order. Used for both settings and dependency conditions.
func platforms(where conditions: [PackageCondition]) -> [Platform] {
  Platform.allCases.filter { platform in
    let environment = BuildEnvironment(platform: platform.swiftPM, configuration: .release)
    return conditions.allSatisfy { $0.satisfies(environment) }
  }
}

/// The C-family part of a module: a `ClangModule`, or a mixed-language `SwiftModule`.
func clangInfo(of module: ResolvedModule) -> ClangModuleInfo? {
  (module.underlying as? ClangModule)?.clangModuleInfo
    ?? (module.underlying as? SwiftModule)?.clangModuleInfo
}

extension ResolvedModule.Dependency {
  /// The modules it brings in: the module itself, or the product's modules.
  var modules: [ResolvedModule] {
    switch self {
    case let .module(module, _): [module]
    case let .product(product, _): Array(product.modules)
    }
  }
}
