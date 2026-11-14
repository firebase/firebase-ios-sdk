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

import Foundation
#if os(watchOS)
  // Links WatchKit, which provides `WKInterfaceDevice`.
  private import WatchKit
#endif

/// The standard User-Agent that Firebase SDKs send.
///
/// It's the same string that `GTMFetcherStandardUserAgentString(nil)` from GTMSessionFetcher
/// returns, so the User-Agent doesn't change when an SDK stops using GTMSessionFetcher.
public enum FirebaseUserAgent {
  /// `<app>/<version> <system>`, for example `com.example.app/1.2 iPhone/18.3 hw/iPhone17_1`.
  ///
  /// - On iOS, tvOS, watchOS, and Mac Catalyst, the system part is
  ///   `<device model>/<system version> hw/<hardware model>`, with `hw/sim` in simulators.
  /// - On macOS, it's `MacOSX/<major>.<minor>.<patch>`.
  /// - On other platforms, it's `<kernel name>/<kernel release>`.
  ///
  /// The `GTMUserAgentID` and `GTMUserAgentVersion` Info.plist keys override the app part.
  public static let standard = userAgent(
    applicationIdentifier: applicationIdentifier(bundle: .main),
    system: currentSystem()
  )

  static func userAgent(applicationIdentifier: String, system: String) -> String {
    "\(applicationIdentifier) \(system)"
  }

  // MARK: - App part

  static func applicationIdentifier(bundle: Bundle) -> String {
    applicationIdentifier(
      bundleIdentifier: bundle.bundleIdentifier,
      processName: ProcessInfo.processInfo.processName,
      infoValue: { bundle.object(forInfoDictionaryKey: $0) }
    )
  }

  /// The app's identifier and version, separated by `/`.
  ///
  /// The identifier is the `GTMUserAgentID` Info.plist value, the bundle identifier, or
  /// `proc_<process name>`, in that order. The version is the `GTMUserAgentVersion`,
  /// `CFBundleShortVersionString`, or `CFBundleVersion` value. Without a version, the result is
  /// just the identifier.
  static func applicationIdentifier(bundleIdentifier: String?, processName: String,
                                    infoValue: (String) -> Any?) -> String {
    var identifier = infoValue("GTMUserAgentID") as? String ?? ""
    if identifier.isEmpty {
      if let bundleIdentifier, !bundleIdentifier.isEmpty {
        identifier = bundleIdentifier
      } else {
        // A process name might not be stable, so the "proc_" prefix flags it.
        identifier = "proc_\(processName)"
      }
    }
    identifier = cleaned(identifier)

    var version = infoValue("GTMUserAgentVersion") as? String ?? ""
    if version.isEmpty {
      version = infoValue("CFBundleShortVersionString") as? String ?? ""
    }
    if version.isEmpty {
      version = infoValue("CFBundleVersion") as? String ?? ""
    }
    version = cleaned(version)

    return version.isEmpty ? identifier : "\(identifier)/\(version)"
  }

  /// Makes `string` safe to use in a User-Agent: replaces spaces and commas with underscores, then
  /// deletes whitespace, newlines, and the HTTP separators `()<>@;:\"/[]?={}`.
  static func cleaned(_ string: String?) -> String {
    guard let string else {
      return ""
    }
    let underscored = string.replacingOccurrences(of: " ", with: "_")
      .replacingOccurrences(of: ",", with: "_")
    let deleted = CharacterSet.whitespacesAndNewlines
      .union(CharacterSet(charactersIn: "()<>@;:\\\"/[]?={}"))
    return String(String.UnicodeScalarView(underscored.unicodeScalars.filter {
      !deleted.contains($0)
    }))
  }

  // MARK: - System part

  /// The system part for the current platform.
  static func currentSystem() -> String {
    #if os(watchOS)
      let device = currentDevice(className: "WKInterfaceDevice")
      return deviceSystem(model: device.model, systemVersion: device.systemVersion,
                          hardwareModel: currentHardwareModel())
    #elseif os(iOS) || os(tvOS)
      // `os(iOS)` includes Mac Catalyst.
      let device = currentDevice(className: "UIDevice")
      return deviceSystem(model: device.model, systemVersion: device.systemVersion,
                          hardwareModel: currentHardwareModel())
    #elseif os(macOS)
      return macSystem(version: ProcessInfo.processInfo.operatingSystemVersion)
    #else
      let info = systemInfo()
      return kernelSystem(name: info?.name ?? "", release: info?.release ?? "")
    #endif
  }

  /// `<device model>/<system version> hw/<hardware model>`, for example `iPhone/18.3 hw/sim`.
  static func deviceSystem(model: String, systemVersion: String, hardwareModel: String) -> String {
    "\(cleaned(model))/\(systemVersion) hw/\(hardwareModel)"
  }

  /// `sim` in simulators. Otherwise the cleaned machine name, for example `iPhone17_1`, or `unk`
  /// if it's unknown.
  static func hardwareModel(isSimulator: Bool, machine: String?) -> String {
    if isSimulator {
      return "sim"
    }
    let hardwareModel = cleaned(machine)
    return hardwareModel.isEmpty ? "unk" : hardwareModel
  }

  /// `MacOSX/<major>.<minor>.<patch>`, for example `MacOSX/15.2.0`.
  static func macSystem(version: OperatingSystemVersion) -> String {
    "MacOSX/\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
  }

  /// `<kernel name>/<kernel release>`, for example `Darwin/24.2.0`.
  static func kernelSystem(name: String, release: String) -> String {
    "\(name)/\(release)"
  }

  private static func currentHardwareModel() -> String {
    #if targetEnvironment(simulator)
      return hardwareModel(isSimulator: true, machine: nil)
    #else
      return hardwareModel(isSimulator: false, machine: systemInfo()?.machine)
    #endif
  }

  /// Reads `model` and `systemVersion` from `UIDevice.current` or `WKInterfaceDevice.current()`.
  ///
  /// The values are read through the Objective-C runtime. Those classes are main-actor isolated
  /// in Swift, but the User-Agent is computed on whatever thread first needs it.
  private static func currentDevice(className: String) -> (model: String,
                                                           systemVersion: String) {
    if let deviceClass = NSClassFromString(className),
       let device = object(from: deviceClass as AnyObject, getter: "currentDevice"),
       let model = object(from: device, getter: "model") as? String,
       let systemVersion = object(from: device, getter: "systemVersion") as? String {
      return (model, systemVersion)
    }
    // Apps always load UIKit or WatchKit, so this is only a fallback for unusual processes.
    let version = ProcessInfo.processInfo.operatingSystemVersion
    let systemVersion = version.patchVersion == 0
      ? "\(version.majorVersion).\(version.minorVersion)"
      : "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    return ("unknown", systemVersion)
  }

  /// Calls the getter named `getter` on `target` if `target` responds to it.
  private static func object(from target: AnyObject, getter: String) -> AnyObject? {
    let selector = NSSelectorFromString(getter)
    guard target.responds(to: selector) else {
      return nil
    }
    return target.perform(selector)?.takeUnretainedValue()
  }

  /// The kernel name, kernel release, and machine name from `uname`.
  private static func systemInfo() -> (name: String, release: String, machine: String)? {
    var info = utsname()
    guard uname(&info) == 0 else {
      return nil
    }
    func string<T>(_ field: T) -> String {
      withUnsafeBytes(of: field) { bytes in
        String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
      }
    }
    return (string(info.sysname), string(info.release), string(info.machine))
  }
}
