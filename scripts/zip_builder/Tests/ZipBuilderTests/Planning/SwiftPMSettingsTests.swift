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
@preconcurrency import PackageModel
import Testing
@testable import ZipBuilder

struct TranslateTests {
  private func translated(_ declaration: PackageModel.BuildSettings.Declaration,
                          _ values: [String], isDynamic: Bool = false) async throws
    -> (key: String, values: [String])? {
    let coreC = try await MiniPackage.module("CoreC")
    let root = try AbsolutePath(validating: MiniPackage.path)
    return translate(declaration, values, coreC, isDynamic: isDynamic, packageRoot: root)
  }

  @Test func headerSearchPathsAreRelativeToTheTargetDirectory() async throws {
    let result = try await translated(.HEADER_SEARCH_PATHS,
                                      [".", "include/../Sub", "$(SRCROOT)/x", "/abs"])
    #expect(result?.key == "HEADER_SEARCH_PATHS")
    #expect(result?.values == ["Sources/CoreC", "Sources/CoreC/Sub", "$(SRCROOT)/x", "/abs"])
  }

  @Test func definitionsWithSpacesAreEscaped() async throws {
    let result = try await translated(.GCC_PREPROCESSOR_DEFINITIONS, ["A=1", "K=a b"])
    #expect(result?.key == "GCC_PREPROCESSOR_DEFINITIONS")
    #expect(result?.values == ["A=1", #"K=\"a\ b\""#])
  }

  @Test func linkerSettingsOnlyForDynamicFrameworks() async throws {
    #expect(try await translated(.LINK_FRAMEWORKS, ["Security"]) == nil)
    #expect(try await translated(.LINK_LIBRARIES, ["z"]) == nil)

    let frameworks = try await translated(.LINK_FRAMEWORKS, ["Security", "UIKit"], isDynamic: true)
    #expect(frameworks?.key == "OTHER_LDFLAGS")
    #expect(frameworks?.values == ["-framework", "Security", "-framework", "UIKit"])
    let libraries = try await translated(.LINK_LIBRARIES, ["z", "c++"], isDynamic: true)
    #expect(libraries?.key == "OTHER_LDFLAGS")
    #expect(libraries?.values == ["-lz", "-lc++"])
  }

  @Test func otherSettingsPassThrough() async throws {
    for declaration in [PackageModel.BuildSettings.Declaration.OTHER_CFLAGS, .OTHER_CPLUSPLUSFLAGS,
                        .OTHER_SWIFT_FLAGS, .SWIFT_ACTIVE_COMPILATION_CONDITIONS] {
      let result = try await translated(declaration, ["-x", "y"])
      #expect(result?.key == declaration.name)
      #expect(result?.values == ["-x", "y"])
    }
  }
}

struct EvaluateBuildSettingsTests {
  @Test func iOSOnlyDefinitionIsConditionalOnTheiOSSDKs() async throws {
    let settings = try await MiniPackage.plan().framework("CoreC").settings
    #expect(settings["GCC_PREPROCESSOR_DEFINITIONS"] == ["CORE_FLAG=1"])
    #expect(settings["GCC_PREPROCESSOR_DEFINITIONS[sdk=iphoneos*]"] ==
      ["$(inherited)", "CORE_IOS_ONLY"])
    #expect(settings["GCC_PREPROCESSOR_DEFINITIONS[sdk=iphonesimulator*]"] ==
      ["$(inherited)", "CORE_IOS_ONLY"])
    #expect(settings["GCC_PREPROCESSOR_DEFINITIONS[sdk=macosx*]"] == nil)
    // CoreC is static, so `.linkedFramework("Security")` adds nothing.
    #expect(settings["OTHER_LDFLAGS"] == nil)
  }

  @Test func macOSOnlyConditionGoesThroughIsMacCatalyst() async throws {
    let settings = try await MiniPackage.plan().framework("SwiftLib").settings
    let key = "SWIFT_ACTIVE_COMPILATION_CONDITIONS"
    #expect(settings[key] == ["SWIFT_FLAG"])
    #expect(settings["\(key)_MACOS"] == ["SWIFT_MACOS_ONLY"])
    #expect(settings["\(key)_CATALYST"] == nil)
    #expect(settings["\(key)_NO"] == .string("$(\(key)_MACOS)"))
    #expect(settings["\(key)_YES"] == .string("$(\(key)_CATALYST)"))
    #expect(settings["\(key)[sdk=macosx*]"] == ["$(inherited)", "$(\(key)_$(IS_MACCATALYST))"])
    #expect(settings["\(key)[sdk=iphoneos*]"] == nil)
  }

  @Test func dynamicFrameworksLink() async throws {
    let coreC = try await MiniPackage.module("CoreC")
    let root = try AbsolutePath(validating: MiniPackage.path)
    let settings = evaluateBuildSettings(coreC, isDynamic: true, packageRoot: root)
    #expect(settings["OTHER_LDFLAGS"] == ["-framework", "Security"])
  }

  /// CppUser links UIKit on iOS and tvOS. Catalyst compiles the iOS code, so it links UIKit
  /// there too; macOS doesn't.
  @Test func linkerSettingsForIOSAlsoApplyToCatalyst() async throws {
    #expect(linkingPlatforms([.ios, .tvos]) == [.ios, .catalyst, .tvos])
    #expect(linkingPlatforms([.macos]) == [.macos])
    let cppUser = try await MiniPackage.module("CppUser")
    let root = try AbsolutePath(validating: MiniPackage.path)
    let settings = evaluateBuildSettings(cppUser, isDynamic: true, packageRoot: root)
    let uiKit = ["$(inherited)", "-framework", "UIKit"]
    #expect(settings["OTHER_LDFLAGS[sdk=iphoneos*]"] == .list(uiKit))
    #expect(settings["OTHER_LDFLAGS[sdk=appletvos*]"] == .list(uiKit))
    #expect(settings["OTHER_LDFLAGS_CATALYST"] == ["-framework", "UIKit"])
    #expect(settings["OTHER_LDFLAGS_MACOS"] == nil)
    #expect(evaluateBuildSettings(cppUser, isDynamic: false, packageRoot: root).keys.isEmpty)
  }

  @Test func languageModes() async throws {
    let plan = try await MiniPackage.plan()
    #expect(try plan.framework("SwiftLib").settings["SWIFT_VERSION"] == "5.0") // .swiftLanguageMode
    #expect(try plan.framework("CoreC").settings["SWIFT_VERSION"] == "6.0") // tools version 6.0
    #expect(try plan.framework("CoreC").settings["GCC_C_LANGUAGE_STANDARD"] == nil)
  }

  @Test func platformConditionalHelper() {
    var settings = BuildSettings()
    settings.add(["A"], to: "K", onlyFor: [.ios, .catalyst])
    settings.add(["B"], to: "K", onlyFor: [.ios, .tvos])
    #expect(settings["K[sdk=iphoneos*]"] == ["$(inherited)", "A", "B"])
    #expect(settings["K[sdk=iphonesimulator*]"] == ["$(inherited)", "A", "B"])
    #expect(settings["K[sdk=appletvos*]"] == ["$(inherited)", "B"])
    #expect(settings["K_CATALYST"] == ["A"])
    #expect(settings["K_MACOS"] == nil)
    #expect(settings["K[sdk=macosx*]"] == ["$(inherited)", "$(K_$(IS_MACCATALYST))"])
  }

  @Test func escapingSpaces() {
    #expect(ZipBuilder.escapingSpaces("NO_SPACES=1") == "NO_SPACES=1")
    #expect(ZipBuilder.escapingSpaces("K=a b c") == #"K=\"a\ b\ c\""#)
  }

  /// Today's output for the unusual shapes: no `=`, spaces in the name, an empty name, and `=` in
  /// the value.
  @Test func escapingSpacesEdgeCases() {
    // Without `=`, every space is escaped and nothing is quoted.
    #expect(ZipBuilder.escapingSpaces("A B") == #"A\ B"#)
    // Only the value is escaped and quoted, even when the name has spaces.
    #expect(ZipBuilder.escapingSpaces("MY KEY=a b") == #"MY KEY=\"a\ b\""#)
    #expect(ZipBuilder.escapingSpaces("MY KEY=1") == #"MY KEY=\"1\""#)
    // An empty name leaves one part, so it's treated like no `=`.
    #expect(ZipBuilder.escapingSpaces("=a b") == #"=a\ b"#)
    // Only the first `=` splits.
    #expect(ZipBuilder.escapingSpaces("K=a=b c") == #"K=\"a=b\ c\""#)
  }
}
