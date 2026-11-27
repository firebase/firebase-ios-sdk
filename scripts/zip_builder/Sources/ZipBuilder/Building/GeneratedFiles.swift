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

private typealias URL = Foundation.URL

// The files `makeProject` writes next to the project, beyond what the plan lists: umbrella
// headers, module maps, combined privacy manifests, and embedded resources.
// The module map text comes from ModuleMaps.swift.

/// The framework as its target needs it: header name collisions resolved, plus the files written
/// into `directory` (absolute paths) in place of what they replace.
func addingGeneratedFiles(to framework: Framework, packageRoot: Path,
                          directory: Path) throws -> Framework {
  let directory = URL(fileURLWithPath: directory)

  var framework = framework
  framework.headers = resolvingHeaderCollisions(framework, packageRoot: packageRoot)
  if let custom = framework.moduleMap {
    try translateCustomModuleMap(custom, of: &framework, packageRoot: packageRoot,
                                 directory: directory)
  } else {
    try addUmbrellaHeader(to: &framework, packageRoot: packageRoot, directory: directory)
  }
  try combinePrivacyManifests(of: &framework, packageRoot: packageRoot, directory: directory)
  try embedResources(of: &framework, packageRoot: packageRoot, directory: directory)

  return framework
}

/// A framework's `Headers/` is flat, so only one public header per file name can ship. A
/// code-free header, i.e. a forwarder like nanopb's `spm_headers/pb.h` (`#include "nanopb/pb.h"`),
/// gives way to one with declarations; otherwise the first one wins. The others become project
/// headers.
func resolvingHeaderCollisions(_ framework: Framework, packageRoot: Path) -> [Header] {
  var headers = framework.headers
  let publicIndices = headers.indices.filter { headers[$0].visibility == .public }
  let byName = Dictionary(grouping: publicIndices) { fileName(headers[$0].path) }
  for (name, indices) in byName.sorted(by: { $0.key < $1.key }) where indices.count > 1 {
    let kept = indices.first { !isCodeFreeFile(fullPath(headers[$0].path, packageRoot)) }
      ?? indices[0]

    for index in indices where index != kept {
      headers[index].visibility = .project
      warn("\(framework.name): \(headers[index].path) collides with the public header "
        + "\(headers[kept].path) named \(name); it ships as a project header.")
    }
  }
  return headers
}

/// SwiftPM's custom module map, translated into a framework module map, so headers it lists stay
/// in the module even when the umbrella doesn't import them. It replaces the umbrella header, so
/// nothing else is generated.
private func translateCustomModuleMap(_ custom: Path, of framework: inout Framework,
                                      packageRoot: Path, directory: URL) throws {
  let text = try String(contentsOfFile: fullPath(custom, packageRoot), encoding: .utf8)
  let moduleMap = try frameworkModuleMap(rewriting: text, at: custom,
                                         moduleName: framework.moduleName,
                                         publicHeaders: Set(framework.publicHeaders.map(fileName)),
                                         hasSwift: framework.hasSwiftSources)
  try useModuleMap(moduleMap, for: &framework, in: directory)
}

/// Makes sure the framework has the umbrella header Xcode builds its module from: `<Module>.h`.
/// See docs/how-it-works.md#umbrella-headers-and-module-maps.
private func addUmbrellaHeader(to framework: inout Framework, packageRoot: Path,
                               directory: URL) throws {
  let module = framework.moduleName
  let publicHeaders = framework.publicHeaders

  // A code-free public `<Module>.h` already is the umbrella.
  let ownHeader = publicHeaders.first { fileName($0) == "\(module).h" }
  if let ownHeader, isCodeFreeFile(fullPath(ownHeader, packageRoot)) {
    return
  }

  // Otherwise generate one that imports every public header. A pure-Swift framework gets one too,
  // with just the version symbols, as in earlier release zips.
  // A `<Module>.h` with declarations of its own (GTMSessionFetcher) can't be replaced, so the
  // generated umbrella gets another name, and a module map points at it.
  let umbrellaName = ownHeader == nil ? "\(module).h" : "\(module)-umbrella.h"
  let umbrella = directory.appendingPathComponent(umbrellaName)
  let imports = publicHeaders.map { "\(framework.name)/\(fileName($0))" }
  try writeFile(umbrellaHeader(importing: imports, moduleName: module), to: umbrella)
  framework.headers.append(Header(path: umbrella.path, visibility: .public))
  if ownHeader != nil {
    try useModuleMap(frameworkModuleMap(module, umbrella: umbrellaName,
                                        hasSwift: framework.hasSwiftSources),
                     for: &framework, in: directory)
  }
}

/// Writes `text` as the framework's module map and points `MODULEMAP_FILE` at it.
private func useModuleMap(_ text: String, for framework: inout Framework,
                          in directory: URL) throws {
  let moduleMap = directory.appendingPathComponent("module.modulemap")
  try writeFile(text, to: moduleMap)
  framework.settings["MODULEMAP_FILE"] = .string(moduleMap.path)
}

/// An umbrella header that imports `headers` (`<Framework/Header.h>`) and declares the version
/// symbols Xcode defines with `VERSIONING_SYSTEM = apple-generic`. While building, `<…>` finds a
/// header on the header search paths first, as the framework's own headers do; quoted imports of
/// the `Headers/` copies would define everything twice. Like CocoaPods' umbrellas, it imports
/// UIKit where it exists, so `import <Module>` re-exports it and code relying on that still builds.
func umbrellaHeader(importing headers: [String], moduleName: String) -> String {
  """
  // Generated by zip-builder: the umbrella header of the \(moduleName) module.

  #ifdef __OBJC__
  #import <Foundation/Foundation.h>
  #if __has_include(<UIKit/UIKit.h>)
  #import <UIKit/UIKit.h>
  #endif
  #else
  #ifndef FOUNDATION_EXPORT
  #if defined(__cplusplus)
  #define FOUNDATION_EXPORT extern "C"
  #else
  #define FOUNDATION_EXPORT extern
  #endif
  #endif
  #endif

  \(headers.map { "#import <\($0)>" }.joined(separator: "\n"))

  FOUNDATION_EXPORT double \(moduleName)VersionNumber;
  FOUNDATION_EXPORT const unsigned char \(moduleName)VersionString[];

  """
}

/// A framework ships one privacy manifest, so several (from merged targets) are combined into
/// one.
private func combinePrivacyManifests(of framework: inout Framework, packageRoot: Path,
                                     directory: URL) throws {
  let manifests = framework.resources.filter(\.isPrivacyManifest)
  guard manifests.count > 1 else { return }

  let contents = try manifests.map { manifest in
    let data = try Data(contentsOf: URL(fileURLWithPath: fullPath(manifest.path, packageRoot)))
    guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
      as? [String: Any] else {
      throw ZipBuilderError("\(manifest.path) isn't a property list dictionary.")
    }
    return plist
  }

  let combined = directory.appendingPathComponent(privacyManifestName)
  try writeFile(PropertyListSerialization.data(fromPropertyList: combinedPrivacyManifest(contents),
                                               format: .xml, options: 0),
                to: combined)

  framework.resources.removeAll(where: \.isPrivacyManifest)
  framework.resources.append(Resource(path: combined.path, rule: .process(localization: nil)))
}

/// One privacy manifest from several: `NSPrivacyTracking` is OR-ed, tracking domains and collected
/// data types are unioned, and accessed API types are unioned by type, with their reasons unioned.
/// Other keys keep their first value.
func combinedPrivacyManifest(_ manifests: [[String: Any]]) -> [String: Any] {
  /// Every manifest's list under `key`.
  func lists<Element>(_ key: String, of _: Element.Type) -> [[Element]] {
    manifests.map { $0[key] as? [Element] ?? [] }
  }

  let accessed = lists("NSPrivacyAccessedAPITypes", of: [String: Any].self).joined()
    .compactMap { item -> (type: String, reasons: [String])? in
      guard let type = item["NSPrivacyAccessedAPIType"] as? String else { return nil }

      return (type, item["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? [])
    }

  var combined: [String: Any] = manifests.reduce(into: [:]) { $0.merge($1) { first, _ in first } }

  combined["NSPrivacyTracking"] = manifests.contains { $0["NSPrivacyTracking"] as? Bool == true }
  combined["NSPrivacyTrackingDomains"] = lists("NSPrivacyTrackingDomains", of: String.self).union()
  combined["NSPrivacyCollectedDataTypes"] = lists(
    "NSPrivacyCollectedDataTypes",
    of: NSDictionary.self // so entries compare by value; `[String: Any]` isn't Equatable
  ).union()
  combined["NSPrivacyAccessedAPITypes"] = accessed.map(\.type).uniqued().map { type in
    ["NSPrivacyAccessedAPIType": type,
     "NSPrivacyAccessedAPITypeReasons": accessed.filter { $0.type == type }.map(\.reasons).union()]
  }

  return combined
}

/// SwiftPM's `.embedInCode` resources become a generated Swift source holding their bytes, as
/// `PackageResources.<file_name>`.
private func embedResources(of framework: inout Framework, packageRoot: Path,
                            directory: URL) throws {
  let embedded = framework.resources.filter { $0.rule == .embedInCode }
  guard !embedded.isEmpty else { return }

  var lines = ["// Generated by zip-builder: the embedded resources of \(framework.name).",
               "", "struct PackageResources {"]
  for resource in embedded {
    let bytes = try Data(contentsOf: URL(fileURLWithPath: fullPath(resource.path, packageRoot)))
    let name = fileName(resource.path).spm_mangledToC99ExtendedIdentifier()
    let values = bytes.map(String.init).joined(separator: ",")
    lines.append("  static let \(name): [UInt8] = [\(values)]")
  }
  lines.append("}\n")

  let source = directory.appendingPathComponent("embedded_resources.swift")
  try writeFile(lines.joined(separator: "\n"), to: source)

  framework.resources.removeAll { $0.rule == .embedInCode }
  framework.sources.append(Source(path: source.path))
}

/// Writes `data` to `url`, creating its directory first.
private func writeFile(_ data: Data, to url: URL) throws {
  try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                          withIntermediateDirectories: true)
  try data.write(to: url)
}

private func writeFile(_ text: String, to url: URL) throws {
  try writeFile(Data(text.utf8), to: url)
}
