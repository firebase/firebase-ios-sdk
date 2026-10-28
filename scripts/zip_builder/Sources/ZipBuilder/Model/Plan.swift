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
import XcodeProj

/// A file path: relative to the package root (so plans and fingerprints match across machines),
/// or absolute.
typealias Path = String

/// The last component of `path`, e.g. `CoreC.h`.
func fileName(_ path: Path) -> String {
  (path as NSString).lastPathComponent
}

/// `path` as an absolute path; plan paths are relative to the package root.
func fullPath(_ path: Path, _ packageRoot: Path) -> Path {
  path.hasPrefix("/") ? path : URL(fileURLWithPath: packageRoot).appendingPathComponent(path)
    .standardizedFileURL.path
}

/// The file name of a privacy manifest.
let privacyManifestName = "PrivacyInfo.xcprivacy"

/// `name` as the last component of a bundle ID, whose components may only hold letters, digits
/// and hyphens: anything else becomes a hyphen (`openssl_grpc` → `openssl-grpc`), as Xcode's
/// `rfc1034identifier` makes CocoaPods' bundle IDs.
func bundleIDComponent(_ name: String) -> String {
  String(name.map { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") ? $0 : "-" })
}

/// The name of the folder whose contents go at the zip's root, not in a folder of their own.
/// It's how the config spells the zip root in `zip.files`.
let zipRootFolder = "."

/// Whether `path` names a C-family header or another includable file, by its extension
/// (XcodeProj's `Xcode.headersExtensions`: `.h`, `.hpp`, `.inc`, `.def`, …).
func isHeaderFile(_ path: Path) -> Bool {
  Xcode.headersExtensions.contains("." + (path as NSString).pathExtension)
}

/// Every decision the later stages need, made once while planning.
/// See docs/how-it-works.md#the-plan.
struct Plan: Codable, Equatable, Sendable {
  var settings: BuildSettings // project-wide, already in Xcode form
  var frameworks: [Framework] // one per shipped framework, in dependency order
  var binaries: [Binary] // prebuilt .xcframeworks
  var folders: [Folder] // the zip layout
  /// The frameworks `frameworks.static` keeps static in a dynamic release, sorted. No dynamic
  /// framework may reach them (`checkDynamicFrameworksLinkNothingStatic`). `nil` when there are
  /// none; `nil` isn't encoded, so the plans of releases without them don't change.
  var keptStatic: [String]? = nil

  /// The names of its frameworks.
  var frameworkNames: Set<String> {
    Set(frameworks.map(\.name))
  }

  /// Whether a framework or a binary is named `name`.
  func hasFrameworkOrBinary(named name: String) -> Bool {
    frameworks.contains { $0.name == name } || binaries.contains { $0.name == name }
  }

  /// The plan as `plan.json`: pretty-printed with sorted keys, so equal plans are equal bytes.
  func json() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(self)
  }

  /// Reads a plan written by `json()`, e.g. `plan.json`.
  static func read(from path: Path) throws -> Plan {
    try JSONDecoder().decode(Plan.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
  }
}

/// One shipped framework, built from source.
struct Framework: Codable, Equatable, Sendable {
  var name: String // PRODUCT_NAME
  var moduleName: String // PRODUCT_MODULE_NAME (c99name)
  var package: String // display name of the SwiftPM package it comes from
  var sources: [Source]
  var headers: [Header]
  var moduleMap: Path? = nil // SwiftPM's custom module map, if any; translated, not generated
  var resources: [Resource]
  var settings: BuildSettings // translated, platform-conditional keys included
  var dependencies: [Dependency] // frameworks and binaries
  var platforms: Set<Platform> // where it ships; each one's destinations are archived
  var bundleID: String
  var version: String
  var isDynamic: Bool
  var layout: Layout // applied after archiving

  /// The paths of its public headers.
  var publicHeaders: [Path] {
    headers.filter { $0.visibility == .public }.map(\.path)
  }

  /// Whether any of its sources is Swift (so its module has a `-Swift.h` submodule).
  var hasSwiftSources: Bool {
    sources.contains { $0.path.hasSuffix(".swift") }
  }

  /// What it's archived for: each of its platforms' destinations, platforms in order.
  var destinations: [Destination] {
    platforms.sorted().flatMap(\.destinations)
  }
}

/// A compiled source file, possibly only on some platforms (a merged companion's sources).
struct Source: Codable, Equatable, Sendable {
  var path: Path
  var platforms: Set<Platform>? = nil // nil: every platform
}

/// A framework's dependency on another framework or a binary, possibly only on some platforms.
struct Dependency: Codable, Equatable, Sendable {
  var name: String
  var platforms: Set<Platform>? = nil // nil: wherever the framework ships
}

/// A prebuilt `.xcframework`.
struct Binary: Codable, Equatable, Sendable {
  var name: String
  var path: Path
  var platforms: Set<Platform>
  var version: String
}

/// A folder of the zip: the frameworks it holds and extra files copied into it.
struct Folder: Codable, Equatable, Sendable {
  var name: String
  var frameworks: [String]
  var files: [Path]
  /// With `products.withoutDependencies`, the product's own frameworks: what `frameworks` keeps
  /// once `customize` has restricted platforms, which needs the whole closure until then. Only
  /// set between `makePlan` and `arrangingFolders`; `nil` isn't encoded, so `plan.json` doesn't
  /// change.
  var ownFrameworks: [String]? = nil
}

struct Header: Codable, Equatable, Sendable {
  enum Visibility: String, Codable, Sendable {
    case `public`, `private`, project
  }

  var path: Path
  var visibility: Visibility
}

struct Resource: Codable, Equatable, Sendable {
  /// SwiftPM's resource rules.
  enum Rule: Codable, Equatable, Sendable {
    case process(localization: String?)
    case copy
    case embedInCode
  }

  var path: Path
  var rule: Rule

  /// Whether it's a privacy manifest (`PrivacyInfo.xcprivacy`).
  var isPrivacyManifest: Bool {
    fileName(path) == privacyManifestName
  }
}

/// Changes applied to every slice of a finished `.xcframework`.
struct Layout: Codable, Equatable, Sendable {
  var privacyBundle: String? = nil // bundle that receives PrivacyInfo.xcprivacy
  var resourceBundle: String? = nil // bundle that receives the other resources
  var infoPlist: [String: String] = [:] // values written into each slice's Info.plist
}
