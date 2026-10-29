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

struct PlatformTests {
  @Test func destinations() {
    #expect(Platform.ios.destinations.map(\.name) == ["ios", "ios-simulator"])
    #expect(Platform.catalyst.destinations.map(\.name) == ["catalyst"])
    #expect(Platform.macos.destinations.map(\.name) == ["macos"])
    #expect(Platform.tvos.destinations.map(\.name) == ["tvos", "tvos-simulator"])
    #expect(Platform.watchos.destinations.map(\.name) == ["watchos", "watchos-simulator"])
    #expect(Platform.visionos.destinations.map(\.name) == ["visionos", "visionos-simulator"])
  }

  @Test func xcodebuildDestinations() {
    let all = Platform.allCases.flatMap(\.destinations).map(\.xcodebuildDestination)
    #expect(all == [
      "generic/platform=iOS", "generic/platform=iOS Simulator",
      "generic/platform=macOS,variant=Mac Catalyst",
      "generic/platform=macOS",
      "generic/platform=tvOS", "generic/platform=tvOS Simulator",
      "generic/platform=watchOS", "generic/platform=watchOS Simulator",
      "generic/platform=visionOS", "generic/platform=visionOS Simulator",
    ])
  }

  @Test func sdks() {
    #expect(Platform.ios.sdks == ["iphoneos", "iphonesimulator"])
    #expect(Platform.catalyst.sdks == ["macosx"])
    #expect(Platform.macos.sdks == ["macosx"])
    #expect(Platform.tvos.sdks == ["appletvos", "appletvsimulator"])
    #expect(Platform.watchos.sdks == ["watchos", "watchsimulator"])
    #expect(Platform.visionos.sdks == ["xros", "xrsimulator"])
  }

  @Test func deploymentTargetKeys() {
    #expect(Platform.allCases.map(\.deploymentTargetKey) == [
      "IPHONEOS_DEPLOYMENT_TARGET", "IPHONEOS_DEPLOYMENT_TARGET", "MACOSX_DEPLOYMENT_TARGET",
      "TVOS_DEPLOYMENT_TARGET", "WATCHOS_DEPLOYMENT_TARGET", "XROS_DEPLOYMENT_TARGET",
    ])
  }

  @Test func platformFiltersAndConfigSpellings() {
    #expect(Platform.allCases.map(\.platformFilter) ==
      ["ios", "maccatalyst", "macos", "tvos", "watchos", "xros"])
    #expect(Platform.allCases.map(\.rawValue) ==
      ["ios", "catalyst", "macos", "tvos", "watchos", "visionos"])
  }

  @Test func sortsInDeclarationOrder() {
    #expect([Platform.visionos, .ios, .macos, .catalyst].sorted() ==
      [.ios, .catalyst, .macos, .visionos])
  }
}
