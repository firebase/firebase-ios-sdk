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

/// `verify`'s `dependencies`: `.xcframework`s a distribution built without its dependencies needs
/// but doesn't ship.
struct VerifyDependenciesTests {
  /// Replaces the iOS device binary of `<folder>/<name>.xcframework` in `fake` with a static
  /// archive compiled from `source` (`file`'s extension picks the language) for `verifyTarget`.
  private func compile(_ source: String, as file: String, into name: String, in folder: String,
                       of fake: FakeDistribution) async throws {
    let framework = "\(fake.root)/\(folder)/\(name).xcframework/ios-arm64/\(name).framework"
    try source.write(toFile: framework + "/" + file, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(atPath: framework + "/" + file) }
    try await shell("xcrun", ["--sdk", "iphoneos", "clang", "-target", verifyTarget, "-fmodules",
                              "-c", file, "-o", "code.o"], in: framework)
    try FileManager.default.removeItem(atPath: framework + "/" + name)
    try await shell("xcrun", ["libtool", "-static", "-o", name, "code.o"], in: framework)
    try FileManager.default.removeItem(atPath: framework + "/code.o")
  }

  /// A device-only slice whose module map declares `name`, so the import check can find it.
  private func slice(_ name: String) -> FakeSlice {
    var slice = FakeSlice.device
    slice.headers = ["\(name).h"]
    slice.moduleMap = "framework module \(name) {\n  umbrella header \"\(name).h\"\n}\n"
    return slice
  }

  /// `App` ships an Objective-C class (so `-ObjC` loads it) that calls `dep_value`, which only
  /// the `Dep` dependency defines: the link fails without it and passes with it.
  @Test func theLinkCheckLinksTheDependencies() async throws {
    let distribution = try FakeDistribution()
    try distribution.addXCFramework("App", in: "App", slices: [slice("App")])
    try await compile("""
    #import <Foundation/Foundation.h>
    int dep_value(void);
    @interface AppThing : NSObject
    @end
    @implementation AppThing
    - (int)value { return dep_value(); }
    @end
    """, as: "app.m", into: "App", in: "App", of: distribution)
    let work = try FakeDistribution()
    try work.addXCFramework("Dep", in: "xcframeworks", slices: [slice("Dep")])
    try await compile("int dep_value(void) { return 1; }\n", as: "dep.c", into: "Dep",
                      in: "xcframeworks", of: work)
    let read = try await distribution.read()

    let alone = try await verify(read, baseFolder: nil, skippedImports: [],
                                 requireSignatures: false)
    #expect(alone[0].title == "Every folder links into an app with -ObjC")
    #expect(alone[0].items.map(\.status) == [.failed])
    #expect(alone[0].items.first?.detail.contains("_dep_value") == true)

    // A dependency the distribution ships is ignored, so it's linked once.
    let dependencies = try await readXCFrameworks(in: work.root + "/xcframeworks")
      + read.xcframeworks
    let linked = try await verify(read, baseFolder: nil, skippedImports: [],
                                  requireSignatures: false, dependencies: dependencies)
    #expect(linked[0].title == "Every folder links into an app with -ObjC (with 1 dependency)")
    #expect(linked[0].items == [CheckItem(name: "App", status: .passed)])
    // Dependencies aren't checked themselves.
    #expect(linked[1].items == [CheckItem(name: "App", status: .passed)])
    #expect(linked[2].items.map(\.name) == ["App/App"])
    #expect(linked[3].items.map(\.name) == ["App/App"])
  }

  @Test func theLinkCheckTitleNamesWhatEveryFolderLinksWith() {
    let title = "Every folder links into an app with -ObjC"
    #expect(linkCheckTitle(baseFolder: nil, dependencyCount: 0) == title)
    #expect(linkCheckTitle(baseFolder: "Core", dependencyCount: 0) == title + " (with Core)")
    #expect(linkCheckTitle(baseFolder: nil, dependencyCount: 1) == title + " (with 1 dependency)")
    #expect(linkCheckTitle(baseFolder: "Core", dependencyCount: 3)
      == title + " (with Core and 3 dependencies)")
  }

  @Test func readsTheXCFrameworksInADirectory() async throws {
    let work = try FakeDistribution()
    try work.addXCFramework("B", in: "xcframeworks")
    try work.addXCFramework("A", in: "xcframeworks")
    try work.addFile("xcframeworks/notes.txt")
    let xcframeworks = try await readXCFrameworks(in: work.root + "/xcframeworks")
    #expect(xcframeworks.map(\.qualifiedName) == ["xcframeworks/A", "xcframeworks/B"])
    #expect(xcframeworks.allSatisfy { $0.iOSDeviceSlice != nil })
    await #expect(throws: ZipBuilderError.self) {
      try await readXCFrameworks(in: work.root + "/missing")
    }
  }

  @Test func verifyTakesADependenciesDirectory() throws {
    let command = try #require(try ZipBuilderCommand.parseAsRoot([
      "verify", "dist", "--dependencies", "build/xcframeworks",
    ]) as? VerifyCommand)
    #expect(command.dependencies == "build/xcframeworks")
    let defaults = try #require(try ZipBuilderCommand.parseAsRoot(["verify", "dist"])
      as? VerifyCommand)
    #expect(defaults.dependencies == nil)
  }
}
