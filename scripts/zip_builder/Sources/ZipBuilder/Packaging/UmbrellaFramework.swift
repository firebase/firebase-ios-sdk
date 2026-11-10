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

/// `carthage.umbrellaFramework`: creates `<folder>/<name>.framework` in the distribution at
/// `root`, holding only the umbrella header, a module map that exports it, a placeholder binary
/// and an `Info.plist`. Carthage only installs frameworks, so the distribution's loose umbrella
/// header and module map would otherwise be lost, and with them `import <name>`.
///
/// `iOSDeploymentTarget` is the planned `IPHONEOS_DEPLOYMENT_TARGET`, the `MinimumOSVersion`
/// the CocoaPods-era builder wrote; without one there's no `MinimumOSVersion`.
func makeUmbrellaFramework(_ umbrella: Config.UmbrellaFramework, in root: URL, version: String,
                           iOSDeploymentTarget: String?, packageRoot: Path) throws {
  let manager = FileManager.default
  let folder = root.appendingPathComponent(umbrella.folder)
  guard isDirectory(folder.path) else {
    throw ZipBuilderError(
      "carthage.umbrellaFramework: the distribution has no folder \(umbrella.folder)."
    )
  }
  let framework = folder.appendingPathComponent("\(umbrella.name).framework")
  guard !manager.fileExists(atPath: framework.path) else {
    throw ZipBuilderError("carthage.umbrellaFramework: \(umbrella.folder)/\(umbrella.name)"
      + ".framework is already in the distribution.")
  }
  let header = URL(fileURLWithPath: fullPath(umbrella.header, packageRoot))
  let binary = URL(fileURLWithPath: fullPath(umbrella.binary, packageRoot))
  for (key, file) in [("header", header), ("binary", binary)]
    where !manager.fileExists(atPath: file.path) {
    throw ZipBuilderError("carthage.umbrellaFramework.\(key): \(file.path) doesn't exist.")
  }

  let headers = framework.appendingPathComponent("Headers")
  let modules = framework.appendingPathComponent("Modules")
  try manager.createDirectory(at: headers, withIntermediateDirectories: true)
  try manager.createDirectory(at: modules, withIntermediateDirectories: true)
  try manager.copyItem(at: header, to: headers.appendingPathComponent(header.lastPathComponent))
  try Data(umbrellaModuleMap(name: umbrella.name, header: header.lastPathComponent).utf8)
    .write(to: modules.appendingPathComponent("module.modulemap"))
  try manager.copyItem(at: binary, to: framework.appendingPathComponent(umbrella.name))
  let plist = umbrellaInfoPlist(umbrella, version: version,
                                iOSDeploymentTarget: iOSDeploymentTarget)
  let encoder = PropertyListEncoder()
  encoder.outputFormat = .xml
  try encoder.encode(plist).write(to: framework.appendingPathComponent("Info.plist"))
  logger.info("Added \(umbrella.folder)/\(umbrella.name).framework")
}

/// The umbrella framework's module map: a framework module exporting its one header.
func umbrellaModuleMap(name: String, header: String) -> String {
  "framework module \(name) {\n  header \"\(header)\"\n  export *\n}\n"
}

/// The umbrella framework's `Info.plist`: the CocoaPods-era builder's keys, without its
/// hard-coded `DTSDKName` (`iphonesimulator11.2`), which described no SDK the framework was built
/// with. Versions drop any pre-release suffix (`13.2.0-beta` → `13.2.0`), since bundle versions
/// are only numbers.
func umbrellaInfoPlist(_ umbrella: Config.UmbrellaFramework, version: String,
                       iOSDeploymentTarget: String?) -> [String: String] {
  let bundleVersion = String(version.prefix { $0 != "-" })
  var plist = [
    "CFBundleExecutable": umbrella.name,
    "CFBundleIdentifier": umbrella.bundleIdentifier,
    "CFBundleInfoDictionaryVersion": "6.0",
    "CFBundleName": umbrella.name,
    "CFBundlePackageType": "FMWK",
    "CFBundleShortVersionString": bundleVersion,
    "CFBundleVersion": bundleVersion,
  ]
  plist["MinimumOSVersion"] = iOSDeploymentTarget
  return plist
}
