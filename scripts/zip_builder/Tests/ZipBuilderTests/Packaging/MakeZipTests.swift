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
import Testing
@testable import ZipBuilder

/// A temporary work dir with a package root and synthetic `.xcframework`s (`A`, `B`, `Bin`).
private final class ZipFixture {
  let fake: FakeDistribution // its root holds `xcframeworks/` and `package/`
  let base: URL

  init() throws {
    fake = try FakeDistribution()
    base = URL(fileURLWithPath: fake.root)
    for name in ["A", "B", "Bin"] {
      try fake.addXCFramework(name, in: "xcframeworks")
    }
    try fake.addFile("package/CoreOnly/NOTICES", "notices")
    try fake.addFile("package/Template/README.md", "# Read me")
    try fake.addFile("package/Crashlytics/run", "#!/bin/sh")
  }

  var xcframeworks: Path {
    base.appendingPathComponent("xcframeworks").path
  }

  var packageRoot: Path {
    base.appendingPathComponent("package").path
  }

  var workDir: Path {
    base.appendingPathComponent("work").path
  }

  static let plan: Plan = {
    var plan = SyntheticPackage.plan
    plan.folders = [
      Folder(name: ".", frameworks: [], files: ["CoreOnly/NOTICES", "Template/README.md"]),
      Folder(name: "Base", frameworks: ["Bin", "A"], files: []),
      Folder(name: "Other", frameworks: ["B"], files: ["Crashlytics/run"]),
    ]
    return plan
  }()
}

private func config(_ json: String = "") throws -> Config {
  try JSONDecoder().decode(Config.self, from: Data("""
  { "release": { "name": "Mini", "bundleIdPrefix": "com.example",
                 "archiveName": "{name}-{version}-latest.zip" },
    "products": { "base": { "product": "Base", "frameworks": ["A", "Bin"] } } \(json) }
  """.utf8))
}

private func artifact(_ to: String, _ url: String, subpath: Path? = nil,
                      strip: Bool = false) -> Config.ExternalArtifact {
  Config.ExternalArtifact(to: to, url: url, subpath: subpath,
                          stripSignatures: Default(wrappedValue: strip))
}

/// Visible paths under `root`, relative and sorted, without descending into `.xcframework`s.
private func layout(of root: URL) -> [String] {
  guard let enumerator = FileManager.default.enumerator(atPath: root.path) else { return [] }
  var paths: [String] = []
  while let path = enumerator.nextObject() as? String {
    paths.append(path)
    if path.hasSuffix(".xcframework") {
      enumerator.skipDescendants()
    }
  }
  return paths.sorted()
}

struct MakeZipTests {
  @Test func laysOutFoldersExtraFilesAndMetadata() async throws {
    let fixture = try ZipFixture()
    try await shell(
      "xattr",
      ["-w", "com.example.test", "1", fixture.packageRoot + "/CoreOnly/NOTICES"]
    )
    let zip = try await makeZip(xcframeworks: fixture.xcframeworks, plan: ZipFixture.plan,
                                config: config(), packageRoot: fixture.packageRoot,
                                workDir: fixture.workDir, signingIdentity: nil, version: "1.2.3")
    let root = try distributionRoot(workDir: fixture.workDir, config: config())
    #expect(root.path.hasSuffix("/work/dist/Mini"))
    #expect(layout(of: root) == [
      "Base", "Base/A.xcframework", "Base/Bin.xcframework", "METADATA.md", "NOTICES",
      "Other", "Other/B.xcframework", "Other/run", "README.md",
    ])
    // Extra files are copied by file name, with their contents, from anywhere in the package.
    #expect(try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)
      == "# Read me")
    #expect(try String(contentsOf: root.appendingPathComponent("NOTICES"), encoding: .utf8)
      == "notices")
    let run = try FileManager.default.attributesOfItem(atPath: root.path + "/Other/run")
    #expect(run[.type] as? FileAttributeType == .typeRegular)

    // The zip holds the distribution under its top-level directory.
    #expect(zip == fixture.workDir + "/Mini-1.2.3-latest.zip")
    let distribution = try await readDistribution(at: zip)
    defer { distribution.removeExtracted() }
    #expect(distribution.root.hasSuffix("/Mini"))
    #expect(distribution.files == ["METADATA.md", "NOTICES", "README.md"])
    #expect(distribution.folders.map(\.name) == ["Base", "Other"])
    #expect(distribution.xcframeworks.map(\.name).sorted() == ["A", "B", "Bin"])
    #expect(distribution.xcframeworks.allSatisfy { !$0.signature.isSigned })
    // Extended attributes (here on NOTICES) don't become `._*` or `__MACOSX` entries.
    let entries = try await shell("zipinfo", ["-1", zip]).split(separator: "\n")
    #expect(entries.contains("Mini/NOTICES"))
    #expect(!entries.contains { $0.contains("__MACOSX") || $0.contains("/._") })
  }

  @Test func aMissingXCFrameworkIsAnError() async throws {
    let fixture = try ZipFixture()
    var plan = ZipFixture.plan
    plan.folders[1].frameworks.append("Missing")
    let error = await #expect(throws: ZipBuilderError.self) {
      try await makeZip(xcframeworks: fixture.xcframeworks, plan: plan, config: config(),
                        packageRoot: fixture.packageRoot, workDir: fixture.workDir,
                        signingIdentity: nil, version: "1.2.3")
    }
    #expect(error?.description.contains("Base: Missing.xcframework isn't in") == true)
  }

  @Test func aMissingFolderFileIsAnError() throws {
    let fixture = try ZipFixture()
    let root = URL(fileURLWithPath: fixture.workDir).appendingPathComponent("layout")
    let folders = [Folder(name: "Other", frameworks: [], files: ["Nope.txt"])]
    let error = #expect(throws: ZipBuilderError.self) {
      try layOutFolders(folders, xcframeworks: fixture.xcframeworks,
                        packageRoot: fixture.packageRoot, in: root)
    }
    #expect(error?.description == "Other: Nope.txt doesn't exist in \(fixture.packageRoot).")
  }

  @Test func archiveNames() throws {
    #expect(try archiveName(config(), version: "13.0.0") == "Mini-13.0.0-latest.zip")
    let plain = try JSONDecoder().decode(Config.self, from: Data("""
    { "release": { "name": "Firebase", "bundleIdPrefix": "com.google.firebase" } }
    """.utf8))
    #expect(archiveName(plain, version: "13.0.0") == "Firebase-13.0.0.zip")
  }

  @Test func placesExternalArtifacts() async throws {
    let fixture = try ZipFixture()
    // An archive with `pkg/Frameworks/Ext.xcframework` (signed) and `pkg/LICENSE`.
    let source = fixture.base.appendingPathComponent("artifact")
    try fixture.fake.addXCFramework("Ext", in: "artifact/pkg/Frameworks")
    try fixture.fake.addFile("artifact/pkg/LICENSE", "license")
    let ext = source.appendingPathComponent("pkg/Frameworks/Ext.xcframework").path
    try await shell("codesign", ["--sign", "-", ext])
    let zip = fixture.base.appendingPathComponent("artifact.zip")
    try await shell("ditto", ["-c", "-k", source.appendingPathComponent("pkg").path, zip.path])
    let url = zip.absoluteString
    #expect(url.hasPrefix("file://"))

    let root = fixture.base.appendingPathComponent("dist")
    let downloads = fixture.base.appendingPathComponent("downloads")
    try await placeExternalArtifacts([
      artifact("Ext", url, subpath: "Frameworks", strip: true),
      artifact(".", url, subpath: "LICENSE"),
      artifact("Signed", url, subpath: "Frameworks/Ext.xcframework"),
      artifact("All", url),
    ], in: root, downloads: downloads)

    #expect(layout(of: root) == [
      "All", "All/Frameworks", "All/Frameworks/Ext.xcframework", "All/LICENSE",
      "Ext", "Ext/Ext.xcframework", "LICENSE", "Signed", "Signed/Ext.xcframework",
    ])
    let manager = FileManager.default
    #expect(!manager.fileExists(atPath: root.path + "/Ext/Ext.xcframework/_CodeSignature"))
    #expect(manager.fileExists(atPath: root.path + "/Signed/Ext.xcframework/_CodeSignature"))
    #expect(manager.fileExists(atPath: root.path + "/Ext/Ext.xcframework/ios-arm64/Ext.framework"))
    // One cached download per URL; the unpacked copies are gone.
    #expect(try manager.contentsOfDirectory(atPath: downloads.path).count == 1)

    let missing = await #expect(throws: ZipBuilderError.self) {
      try await placeExternalArtifacts([artifact("X", url, subpath: "Nope")], in: root,
                                       downloads: downloads)
    }
    #expect(missing?.description.contains("Nope isn't in") == true)
  }

  @Test func signsUnsignedXCFrameworksAndKeepsExistingSignatures() async throws {
    let fixture = try ZipFixture()
    let root = fixture.base.appendingPathComponent("xcframeworks")
    try await shell(
      "codesign",
      ["--sign", "-", root.appendingPathComponent("Bin.xcframework").path]
    )

    let (signed, kept) = try await signXCFrameworks(in: root, identity: "-")
    #expect(signed == 2 && kept == 1)
    for name in ["A", "B", "Bin"] {
      let path = root.appendingPathComponent("\(name).xcframework").path
      #expect(try await runTool("codesign", ["--verify", "--strict", path]).status == 0)
    }
    let distribution = try await readDistribution(at: fixture.fake.root)
    #expect(distribution.xcframeworks.filter { $0.folder == "xcframeworks" }
      .allSatisfy { $0.signature == Signature(isSigned: true, authority: "ad-hoc") })
  }

  @Test func findsOutermostXCFrameworks() throws {
    let fixture = try ZipFixture()
    try fixture.fake.addXCFramework("Nested", in: "deep/er")
    try fixture.fake.addFile("deep/Outer.xcframework/Inner.xcframework/Info.plist")
    #expect(xcframeworkPaths(in: fixture.base).map {
      String($0.dropFirst(fixture.base.path.count + 1))
    } == [
      "deep/Outer.xcframework", "deep/er/Nested.xcframework", "xcframeworks/A.xcframework",
      "xcframeworks/B.xcframework", "xcframeworks/Bin.xcframework",
    ])
  }

  /// The `"."` folder is the distribution root; any other folder is a directory in it.
  @Test func folderDirectories() {
    let root = URL(fileURLWithPath: "/dist/Firebase")
    #expect(directory(ofFolder: zipRootFolder, in: root) == root)
    #expect(directory(ofFolder: "FirebaseAuth", in: root).path == "/dist/Firebase/FirebaseAuth")
  }
}
