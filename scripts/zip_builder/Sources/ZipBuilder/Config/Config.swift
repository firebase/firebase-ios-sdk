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

/// The release config (`zip_builder.jsonc`, else `zip_builder.json`), grouped by stage.
///
/// Every key is optional except `release.name` and `release.bundleIdPrefix`; a missing key takes
/// the default of its `@Default` wrapper.
struct Config: Codable, Equatable, Sendable {
  var release: Release
  @Default<Empty<Products>> var products: Products
  @Default<Empty<Frameworks>> var frameworks: Frameworks
  @Default<Empty<Build>> var build: Build
  @Default<Empty<Layout>> var layout: Layout
  @Default<Empty<Zip>> var zip: Zip
  @Default<Empty<Verify>> var verify: Verify

  /// The release's identity.
  struct Release: Codable, Equatable, Sendable {
    var name: String // project and archive name, e.g. "Firebase"
    var version: String? // `--version` takes precedence
    var bundleIdPrefix: String
    var dependencyBundleIdPrefix: String? // for frameworks from dependency packages
    @Default<DefaultArchiveName> var archiveName: String // `{name}` and `{version}` are replaced
  }

  /// Which products ship, and their folders.
  ///
  /// `exclude`, `add` and `rename` use the package's product names; the other keys use folder
  /// names, i.e. the renamed ones.
  struct Products: Codable, Equatable, Sendable {
    @Default<Empty<[String]>> var exclude: [String]
    @Default<Empty<[Product]>> var add: [Product]
    @Default<Empty<[String: String]>> var rename: [String: String] // product: folder name
    @Default<Empty<[String]>> var withoutFolder: [String] // built, but no folder
    var base: BaseProduct? // the folder that owns shared frameworks
    @Default<Empty<[String: [Platform]]>> var platforms: [String: [Platform]] // folder: platforms
    // folder: frameworks or binaries it also lists
    @Default<Empty<[String: [String]]>> var extraFrameworks: [String: [String]]
    /// Folders hold only their product's own frameworks; dependencies are built but not shipped.
    /// `--without-dependencies` turns it on.
    @Default<False> var withoutDependencies: Bool
  }

  /// A product that isn't declared in `Package.swift`.
  struct Product: Codable, Equatable, Sendable {
    var name: String
    var targets: [String]
  }

  /// The product whose folder holds `frameworks`; other folders don't repeat them.
  struct BaseProduct: Codable, Equatable, Sendable {
    var product: String
    var frameworks: [String]
  }

  /// How targets become frameworks.
  struct Frameworks: Codable, Equatable, Sendable {
    @Default<Empty<[String]>> var aggregate: [String] // package names
    @Default<Empty<[String: [String]]>> var merge: [String: [String]] // target: companions
    @Default<Empty<[String: String]>> var rename: [String: String] // framework: new name
    @Default<Empty<[String: [Path]]>> var publicHeaders: [String: [Path]] // extra header dirs
    @Default<Empty<[String]>> var privateHeaders: [String] // file name patterns
    @Default<Empty<[String]>> var hiddenHeaders: [String] // file name patterns
    // framework: the platforms it ships for
    @Default<Empty<[String: [Platform]]>> var platforms: [String: [Platform]]
    @Default<Empty<[String]>> var dynamic: [String] // framework names
    @Default<Empty<[String]>> var `static`: [String] // framework names
  }

  /// How the project is compiled.
  struct Build: Codable, Equatable, Sendable {
    @Default<DefaultPlatforms> var platforms: [Platform]
    @Default<Empty<[Platform: String]>> var deploymentTargets: [Platform: String]
    /// Keyed by destination name (`watchos`, `watchos-simulator`, …), not platform.
    @Default<Empty<[String: [String]]>> var architectures: [String: [String]]
    @Default<True> var defineSwiftPackage: Bool
    @Default<Empty<[String]>> var defines: [String] // preprocessor macros, e.g. "COCOAPODS=1"
    @Default<Empty<[String]>> var swiftConditions: [String] // Swift compilation conditions
    @Default<Empty<[String: String]>> var swiftVersion: [String: String] // target or "*"
    @Default<Empty<BuildSettings>> var settings: BuildSettings
    var versionMacro: String? // a macro defined as the release version, e.g. "Firebase_VERSION"
    @Default<DefaultLinkage> var linkage: Linkage // `--linkage` takes precedence
  }

  /// Changes applied to finished frameworks.
  struct Layout: Codable, Equatable, Sendable {
    /// Target or `"*"` to bundle name; `{target}` is replaced with the framework name.
    @Default<Empty<[String: String]>> var privacyBundle: [String: String]
    @Default<Empty<[String: String]>> var resourceBundles: [String: String] // framework: bundle
    @Default<Empty<[String: String]>> var infoPlist: [String: String] // key: value, every framework
  }

  /// Extra contents of the zip.
  struct Zip: Codable, Equatable, Sendable {
    @Default<Empty<[Files]>> var files: [Files]
    @Default<Empty<[ExternalArtifact]>> var externalArtifacts: [ExternalArtifact]
  }

  /// Repo-relative files copied into the zip root (`"."`) or a folder.
  struct Files: Codable, Equatable, Sendable {
    var to: String
    var files: [Path]
  }

  /// A prebuilt zip downloaded and unpacked into a folder (`"."` is the zip root).
  ///
  /// The archive's top-level entries, or the item at `subpath`, go into the folder. A plain
  /// directory (no extension) contributes its entries; a file or a bundle such as an
  /// `.xcframework` is placed as is. `stripSignatures` removes every `_CodeSignature` directory.
  struct ExternalArtifact: Codable, Equatable, Sendable {
    var to: String
    var url: String
    var subpath: Path? // inside the downloaded archive
    @Default<False> var stripSignatures: Bool
  }

  /// How `verify` checks a finished distribution.
  struct Verify: Codable, Equatable, Sendable {
    /// Modules the import check skips, e.g. C++-only dependencies nobody imports directly.
    @Default<Empty<[String]>> var skipImports: [String]
  }

  /// The config file names, preferred first. Both are read as JSON5, so `//` comments work in
  /// either; `.jsonc` tells editors and code review to render those comments as comments.
  static let fileNames = ["zip_builder.jsonc", "zip_builder.json"]

  /// Where the config files would be in `directory`, preferred first.
  static func paths(in directory: Path) -> [Path] {
    fileNames.map { URL(fileURLWithPath: directory).appendingPathComponent($0).path }
  }

  /// The config files that exist in `directory`, preferred first.
  private static func existingFiles(in directory: Path) -> [Path] {
    paths(in: directory).filter { FileManager.default.fileExists(atPath: $0) }
  }

  /// The config file in `directory`, by `fileNames` preference; nil when there's none.
  static func file(in directory: Path) -> Path? {
    existingFiles(in: directory).first
  }

  /// Reads the config file in `directory` (see `file(in:)`); nil when there's none. Warns when
  /// both files exist, since only the preferred one is read.
  static func loadDefault(in directory: Path) throws -> Config? {
    let existing = existingFiles(in: directory)
    guard let path = existing.first else { return nil }
    for ignored in existing.dropFirst() {
      warn("\(ignored) is ignored: \(fileName(path)) takes precedence.")
    }
    return try load(from: path)
  }

  /// Reads the config at `explicitPath` (`--config`) when there is one, else the config file in
  /// `directory` (see `loadDefault(in:)`). A missing explicit file is an error; a missing default
  /// is nil.
  static func load(from explicitPath: Path?, orDefaultIn directory: Path) throws -> Config? {
    if let explicitPath {
      return try load(from: explicitPath)
    }
    return try loadDefault(in: directory)
  }

  /// Reads the config at `path`, whatever its extension. `//` comments and other JSON5 syntax
  /// are allowed. Warns about keys that aren't config keys (see `warnAboutUnknownKeys`).
  static func load(from path: Path) throws -> Config {
    let data: Data
    do {
      data = try Data(contentsOf: URL(fileURLWithPath: path))
    } catch {
      throw ZipBuilderError("Couldn't read the config at \(path): \(error.localizedDescription)")
    }
    let decoder = JSONDecoder()
    decoder.allowsJSON5 = true
    let config: Config
    do {
      config = try decoder.decode(Config.self, from: data)
    } catch let error as DecodingError {
      throw ZipBuilderError("Invalid config at \(path): \(describe(error))")
    }
    // The decoder only reads the keys it knows, so read the file again to see all of them.
    let json = try JSONSerialization.jsonObject(with: data, options: .json5Allowed)
    warnAboutUnknownKeys(in: json, of: config)
    return config
  }
}

/// How the frameworks built from source link: `build.linkage`, or `--linkage`.
/// Prebuilt binaries keep whatever linkage they were built with.
enum Linkage: String, Codable, CaseIterable, Sendable {
  case `static` // `frameworks.dynamic` and `.dynamic` products are still dynamic
  case dynamic // every framework built from source, except those in `frameworks.static`
}

/// A short, key-path based description of a decoding error.
private func describe(_ error: DecodingError) -> String {
  func keyPath(_ path: [CodingKey]) -> String {
    if path.isEmpty {
      return "the top level"
    }
    // Array elements: a key's stringValue is "Index 1", so use its intValue (`build.platforms.1`).
    return path.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".")
  }
  switch error {
  case let .keyNotFound(key, context):
    return "missing required key `\(keyPath(context.codingPath + [key]))`"
  case let .typeMismatch(_, context), let .valueNotFound(_, context),
       let .dataCorrupted(context):
    var description = "\(keyPath(context.codingPath)): \(context.debugDescription)"
    if let underlying = context.underlyingError as NSError? {
      description += " (\(underlying.debugDescription))"
    }
    return description
  @unknown default:
    return "\(error)"
  }
}
