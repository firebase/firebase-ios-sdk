// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import FirebaseCoreInternal
import XCTest

/// The expected strings match what `GTMFetcherStandardUserAgentString(nil)` returns on each
/// platform. The Storage wire compatibility tests compare the two strings on the test platform.
class FirebaseUserAgentTests: XCTestCase {
  func testSystemPartForEachPlatform() {
    let rows: [(platform: String, system: String, expected: String)] = [
      ("iOS device",
       deviceSystem("iPhone", "18.3", hardware: (isSimulator: false, machine: "iPhone17,1")),
       "iPhone/18.3 hw/iPhone17_1"),
      ("iOS simulator",
       deviceSystem("iPhone", "18.3", hardware: (isSimulator: true, machine: "arm64")),
       "iPhone/18.3 hw/sim"),
      ("iPadOS",
       deviceSystem("iPad", "18.3.1", hardware: (isSimulator: false, machine: "iPad16,3")),
       "iPad/18.3.1 hw/iPad16_3"),
      ("tvOS",
       deviceSystem("Apple TV", "18.2", hardware: (isSimulator: false, machine: "AppleTV14,1")),
       "Apple_TV/18.2 hw/AppleTV14_1"),
      ("watchOS",
       deviceSystem("Apple Watch", "11.2", hardware: (isSimulator: false, machine: "Watch7,1")),
       "Apple_Watch/11.2 hw/Watch7_1"),
      ("watchOS simulator",
       deviceSystem("Apple Watch", "11.2", hardware: (isSimulator: true, machine: "arm64")),
       "Apple_Watch/11.2 hw/sim"),
      ("Mac Catalyst",
       deviceSystem("iPad", "15.2", hardware: (isSimulator: false, machine: "arm64")),
       "iPad/15.2 hw/arm64"),
      ("unknown hardware",
       deviceSystem("iPod touch", "15.8", hardware: (isSimulator: false, machine: nil)),
       "iPod_touch/15.8 hw/unk"),
      ("macOS",
       FirebaseUserAgent.macSystem(version: OperatingSystemVersion(majorVersion: 15,
                                                                   minorVersion: 2,
                                                                   patchVersion: 0)),
       "MacOSX/15.2.0"),
      ("visionOS",
       FirebaseUserAgent.kernelSystem(name: "Darwin", release: "24.2.0"),
       "Darwin/24.2.0"),
    ]
    for row in rows {
      XCTAssertEqual(row.system, row.expected, row.platform)
    }
  }

  func testApplicationIdentifier() {
    let rows: [(description: String, bundleIdentifier: String?, info: [String: Any],
                expected: String)] = [
      ("bundle ID and short version", "com.example.app",
       ["CFBundleShortVersionString": "1.2.3", "CFBundleVersion": "45"],
       "com.example.app/1.2.3"),
      ("bundle version when there's no short version", "com.example.app",
       ["CFBundleVersion": "45"],
       "com.example.app/45"),
      ("no version", "com.example.app", [:], "com.example.app"),
      ("empty short version", "com.example.app",
       ["CFBundleShortVersionString": "", "CFBundleVersion": "45"],
       "com.example.app/45"),
      ("process name without a bundle ID", nil, ["CFBundleShortVersionString": "1.0"],
       "proc_xctest/1.0"),
      ("process name with an empty bundle ID", "", [:], "proc_xctest"),
      ("GTMUserAgentID override", "com.example.app",
       ["GTMUserAgentID": "My App (Beta)", "CFBundleShortVersionString": "1.0"],
       "My_App_Beta/1.0"),
      ("GTMUserAgentVersion override", "com.example.app",
       ["GTMUserAgentVersion": "2.0 rc1", "CFBundleShortVersionString": "1.0"],
       "com.example.app/2.0_rc1"),
      ("cleaned version", "com.example.app", ["CFBundleShortVersionString": "1.0 (42)"],
       "com.example.app/1.0_42"),
      ("non-string values", "com.example.app",
       ["GTMUserAgentID": 7, "CFBundleShortVersionString": 3],
       "com.example.app"),
    ]
    for row in rows {
      let identifier = FirebaseUserAgent.applicationIdentifier(
        bundleIdentifier: row.bundleIdentifier, processName: "xctest",
        infoValue: { row.info[$0] }
      )
      XCTAssertEqual(identifier, row.expected, row.description)
    }
  }

  func testCleaning() {
    let rows: [(input: String?, expected: String)] = [
      (nil, ""),
      ("", ""),
      ("Apple TV", "Apple_TV"),
      ("iPhone17,1", "iPhone17_1"),
      ("a()<>@;:\\\"/[]?={}b", "ab"),
      ("tab\tnew\nline\r", "tabnewline"),
      ("no\u{00A0}break", "nobreak"),
      ("1.2.3-beta+4", "1.2.3-beta+4"),
      ("Café", "Café"),
    ]
    for row in rows {
      XCTAssertEqual(FirebaseUserAgent.cleaned(row.input), row.expected,
                     String(describing: row.input))
    }
  }

  func testStandardUserAgentJoinsTheAppAndSystemParts() {
    XCTAssertEqual(
      FirebaseUserAgent.userAgent(applicationIdentifier: "com.example.app/1.0",
                                  system: "iPhone/18.3 hw/sim"),
      "com.example.app/1.0 iPhone/18.3 hw/sim"
    )
  }

  func testStandardUserAgentOnThisPlatform() {
    let standard = FirebaseUserAgent.standard

    XCTAssertTrue(standard.hasPrefix(FirebaseUserAgent.applicationIdentifier(bundle: .main) + " "),
                  standard)
    #if os(macOS)
      XCTAssertTrue(standard.contains(" MacOSX/"), standard)
    #elseif os(visionOS)
      // visionOS sends the kernel name and release, without a hardware part.
      XCTAssertTrue(standard.contains(" Darwin/"), standard)
      XCTAssertFalse(standard.contains(" hw/"), standard)
    #elseif targetEnvironment(simulator)
      XCTAssertTrue(standard.hasSuffix(" hw/sim"), standard)
    #endif
    XCTAssertEqual(FirebaseUserAgent.standard, standard, "The User-Agent is computed once")
  }

  private func deviceSystem(_ model: String, _ systemVersion: String,
                            hardware: (isSimulator: Bool, machine: String?)) -> String {
    FirebaseUserAgent.deviceSystem(
      model: model,
      systemVersion: systemVersion,
      hardwareModel: FirebaseUserAgent.hardwareModel(isSimulator: hardware.isSimulator,
                                                     machine: hardware.machine)
    )
  }
}
