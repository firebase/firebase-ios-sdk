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

struct BuildSettingsTests {
  @Test func appendTurnsAStringIntoAList() {
    var settings: BuildSettings = ["OTHER_CFLAGS": "-DA"]
    settings.append(["-DB", "-DC"], to: "OTHER_CFLAGS")
    settings.append(["$(inherited)"], to: "HEADER_SEARCH_PATHS[sdk=iphoneos*]")
    #expect(settings["OTHER_CFLAGS"] == ["-DA", "-DB", "-DC"])
    #expect(settings["HEADER_SEARCH_PATHS[sdk=iphoneos*]"] == ["$(inherited)"])
  }

  @Test func mergeReplacesExistingKeys() {
    let project: BuildSettings = ["SWIFT_VERSION": "5.0", "ARCHS": ["arm64"]]
    let merged = project.merging(["SWIFT_VERSION": "6.0", "DEFINES_MODULE": "YES"])
    #expect(merged == ["SWIFT_VERSION": "6.0", "ARCHS": ["arm64"], "DEFINES_MODULE": "YES"])
    #expect(merged.keys == ["ARCHS", "DEFINES_MODULE", "SWIFT_VERSION"])
  }

  @Test func encodesStringsAndListsAsJSON() throws {
    let settings: BuildSettings = ["A": "YES", "B": ["x", "y"]]
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let json = try String(decoding: encoder.encode(settings), as: UTF8.self)
    #expect(json == #"{"A":"YES","B":["x","y"]}"#)
    #expect(try JSONDecoder().decode(BuildSettings.self, from: Data(json.utf8)) == settings)
  }

  @Test func combiningSettings() {
    let parent: BuildSettings = [
      "PRODUCT_NAME": "Parent", "SWIFT_VERSION": "5.0", "OTHER_LDFLAGS": ["-framework", "UIKit"],
    ]
    let companion: BuildSettings = [
      "PRODUCT_NAME": "Companion", "GCC_C_LANGUAGE_STANDARD": "c11",
      "OTHER_LDFLAGS": ["-framework", "Security", "-framework", "UIKit"],
    ]
    #expect(parent.combined(with: companion) == [
      "PRODUCT_NAME": "Parent", "SWIFT_VERSION": "5.0", "GCC_C_LANGUAGE_STANDARD": "c11",
      "OTHER_LDFLAGS": ["-framework", "UIKit", "-framework", "Security"],
    ])
  }

  /// A string combined with a list is unioned like two lists, and duplicates already in ours
  /// stay.
  @Test func combiningMixedValuesAndKeepingOurDuplicates() {
    let parent: BuildSettings = ["A": "x", "B": ["-DX", "-DX"], "C": ["y"]]
    let companion: BuildSettings = ["A": ["z", "x"], "B": ["-DY"], "C": "y"]
    #expect(parent.combined(with: companion) == [
      "A": ["x", "z"], "B": ["-DX", "-DX", "-DY"], "C": ["y"],
    ])
  }

  @Test func configuredCatalystDeploymentTarget() {
    var settings: BuildSettings = ["IPHONEOS_DEPLOYMENT_TARGET": "15.0"]
    settings.overrideDeploymentTargets([.ios: "16.0", .catalyst: "15.0"])
    #expect(settings["IPHONEOS_DEPLOYMENT_TARGET[sdk=macosx*]"] == "15.0")
    settings = ["IPHONEOS_DEPLOYMENT_TARGET": "15.0",
                "IPHONEOS_DEPLOYMENT_TARGET[sdk=macosx*]": "17.0"]
    settings.overrideDeploymentTargets([.ios: "16.0"])
    #expect(settings["IPHONEOS_DEPLOYMENT_TARGET[sdk=macosx*]"] == "17.0")
  }

  /// An unconfigured Catalyst target is raised to iOS, and then needs no key of its own.
  @Test func catalystFollowsIOSUp() {
    let catalystKey = "IPHONEOS_DEPLOYMENT_TARGET[sdk=macosx*]"
    var settings: BuildSettings = ["IPHONEOS_DEPLOYMENT_TARGET": "15.0", catalystKey: "15.5"]
    settings.overrideDeploymentTargets([.ios: "16.0"])
    #expect(settings == ["IPHONEOS_DEPLOYMENT_TARGET": "16.0"])

    settings = ["IPHONEOS_DEPLOYMENT_TARGET": "15.0"]
    settings.overrideDeploymentTargets([.ios: "16.0"])
    #expect(settings == ["IPHONEOS_DEPLOYMENT_TARGET": "16.0"])

    // Overriding another platform still raises an existing Catalyst target that's below iOS.
    settings = ["IPHONEOS_DEPLOYMENT_TARGET": "15.0", catalystKey: "13.1"]
    settings.overrideDeploymentTargets([.tvos: "16.0"])
    #expect(settings == ["IPHONEOS_DEPLOYMENT_TARGET": "15.0", "TVOS_DEPLOYMENT_TARGET": "16.0"])

    // Versions compare numerically: 10.0 is newer than 9.0.
    settings = ["IPHONEOS_DEPLOYMENT_TARGET": "9.0", catalystKey: "10.0"]
    settings.overrideDeploymentTargets([.tvos: "16.0"])
    #expect(settings[catalystKey] == "10.0")
  }

  @Test func catalystWithoutAnIOSTarget() {
    let catalystKey = "IPHONEOS_DEPLOYMENT_TARGET[sdk=macosx*]"
    var settings: BuildSettings = [catalystKey: "14.0"]
    settings.overrideDeploymentTargets([.tvos: "16.0"])
    #expect(settings == [catalystKey: "14.0", "TVOS_DEPLOYMENT_TARGET": "16.0"])

    settings = [:]
    settings.overrideDeploymentTargets([.macos: "12.0"])
    #expect(settings == ["MACOSX_DEPLOYMENT_TARGET": "12.0"])
  }

  @Test func noDeploymentTargetsChangeNothing() {
    let original: BuildSettings = [
      "IPHONEOS_DEPLOYMENT_TARGET": "15.0", "IPHONEOS_DEPLOYMENT_TARGET[sdk=macosx*]": "13.1",
    ]
    var settings = original
    settings.overrideDeploymentTargets([:])
    #expect(settings == original)
  }

  @Test func removeAllVariantsRemovesConditionalAndHelperKeys() {
    var settings: BuildSettings = [
      "OTHER_CFLAGS": "-DA", "OTHER_CFLAGS[sdk=iphoneos*]": ["-DB"], "OTHER_CFLAGS_MACOS": ["-DC"],
      "OTHER_CFLAGS_CATALYST": ["-DD"], "OTHER_CFLAGS_NO": "$(OTHER_CFLAGS_MACOS)",
      "OTHER_CFLAGS_YES": "$(OTHER_CFLAGS_CATALYST)", "OTHER_CFLAGS_EXTRA": "kept",
      "OTHER_CPLUSPLUSFLAGS": "kept",
    ]
    settings.removeAllVariants(of: "OTHER_CFLAGS")
    #expect(settings == ["OTHER_CFLAGS_EXTRA": "kept", "OTHER_CPLUSPLUSFLAGS": "kept"])
  }

  @Test func removeItemsFiltersEveryVariantAndDropsEmptyLists() {
    var settings: BuildSettings = [
      "GCC_PREPROCESSOR_DEFINITIONS": ["SWIFT_PACKAGE=1", "A=1"],
      "GCC_PREPROCESSOR_DEFINITIONS[sdk=iphoneos*]": ["$(inherited)", "SWIFT_PACKAGE=1"],
      "GCC_PREPROCESSOR_DEFINITIONS_MACOS": ["SWIFT_PACKAGE=1"],
    ]
    settings.removeItems(from: "GCC_PREPROCESSOR_DEFINITIONS") { $0.hasPrefix("SWIFT_PACKAGE") }
    #expect(settings == [
      "GCC_PREPROCESSOR_DEFINITIONS": ["A=1"],
      "GCC_PREPROCESSOR_DEFINITIONS[sdk=iphoneos*]": ["$(inherited)"],
    ])
  }

  @Test func headerSearchPathSettingsIncludeConditionalKeys() {
    #expect(isHeaderSearchPathSetting("HEADER_SEARCH_PATHS"))
    #expect(isHeaderSearchPathSetting("USER_HEADER_SEARCH_PATHS"))
    #expect(isHeaderSearchPathSetting("SYSTEM_HEADER_SEARCH_PATHS[sdk=iphoneos*]"))
    #expect(!isHeaderSearchPathSetting("FRAMEWORK_SEARCH_PATHS"))
  }
}
