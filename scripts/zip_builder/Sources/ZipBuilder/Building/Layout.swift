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

/// Applies `layout` to every slice of the `.xcframework` at `xcframework`.
/// See docs/how-it-works.md#post-archive-layout.
func applyLayout(_ layout: Layout, to xcframework: Path, name: String) throws {
  let root = URL(fileURLWithPath: xcframework)
  for slice in try FileManager.default.contentsOfDirectory(atPath: xcframework).sorted() {
    let framework = root.appendingPathComponent("\(slice)/\(name).framework")
    if FileManager.default.fileExists(atPath: framework.path) {
      try applyLayout(layout, toSlice: framework, name: name)
    }
  }
}

/// One slice: the privacy manifest and the other resources move into their bundles, and the
/// `Info.plist` values are set. macOS-style (versioned) frameworks keep their resources in
/// `Versions/A/Resources`, and their bundles use `Contents/`.
private func applyLayout(_ layout: Layout, toSlice framework: URL, name: String) throws {
  let manager = FileManager.default
  let versionedResources = framework.appendingPathComponent("Versions/A/Resources")
  let isVersioned = manager.fileExists(atPath: versionedResources.path)
  let resources = isVersioned ? versionedResources : framework
  let infoURL = resources.appendingPathComponent("Info.plist")
  var format = PropertyListSerialization.PropertyListFormat.binary
  guard let info = try? PropertyListSerialization.propertyList(
    from: Data(contentsOf: infoURL), options: [], format: &format
  ) as? [String: Any] else {
    throw ZipBuilderError("\(framework.path) has no readable Info.plist.")
  }

  let manifest = resources.appendingPathComponent(privacyManifestName)
  if let bundle = layout.privacyBundle, manager.fileExists(atPath: manifest.path) {
    try move([manifest], intoBundle: bundle, in: resources, isVersioned: isVersioned, info: info)
  }
  if let bundle = layout.resourceBundle {
    // What makes up the framework itself; everything else here is a resource to move. Without a
    // privacy bundle, the last entry is a bare `.bundle`, which is kept as well.
    let frameworkItems: Set = ["Info.plist", name, "Headers", "PrivateHeaders", "Modules",
                               "_CodeSignature", "Versions", "Resources", privacyManifestName,
                               "\(bundle).bundle", "\(layout.privacyBundle ?? "").bundle"]
    let items = try manager.contentsOfDirectory(atPath: resources.path).sorted()
      .filter { !frameworkItems.contains($0) }.map { resources.appendingPathComponent($0) }
    if !items.isEmpty {
      try move(items, intoBundle: bundle, in: resources, isVersioned: isVersioned, info: info)
    }
  }
  if !layout.infoPlist.isEmpty {
    let updated = info.merging(layout.infoPlist) { _, new in new }
    try PropertyListSerialization.data(fromPropertyList: updated, format: format, options: 0)
      .write(to: infoURL)
  }
}

/// Moves `items` into `<resources>/<name>.bundle`, creating the bundle with an `Info.plist`
/// derived from the framework's, because a bundle without one risks failing App Store validation.
private func move(_ items: [URL], intoBundle name: String, in resources: URL, isVersioned: Bool,
                  info: [String: Any]) throws {
  let manager = FileManager.default
  let bundle = resources.appendingPathComponent("\(name).bundle")
  let contents = isVersioned ? bundle.appendingPathComponent("Contents") : bundle
  let destination = isVersioned ? contents.appendingPathComponent("Resources") : contents
  try manager.createDirectory(at: destination, withIntermediateDirectories: true)
  for item in items {
    let target = destination.appendingPathComponent(item.lastPathComponent)
    try? manager.removeItem(at: target)
    try manager.moveItem(at: item, to: target)
  }
  let bundleInfo = contents.appendingPathComponent("Info.plist")
  if !manager.fileExists(atPath: bundleInfo.path) {
    try PropertyListSerialization.data(fromPropertyList: bundleInfoPlist(info, name: name),
                                       format: .binary, options: 0).write(to: bundleInfo)
  }
}

/// A resource bundle's `Info.plist`: the framework's, without an executable, as a `BNDL` named
/// after the bundle. The reference zip's bundles have the same keys.
func bundleInfoPlist(_ frameworkInfo: [String: Any], name: String) -> [String: Any] {
  var info = frameworkInfo
  info["CFBundleExecutable"] = nil
  info["CFBundleName"] = name
  info["CFBundlePackageType"] = "BNDL"
  return info
}
