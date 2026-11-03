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
import PackagePlugin

#if canImport(XcodeProjectPlugin)
  import XcodeProjectPlugin
#endif

@main
struct FirebaseAppCheckDebugTokenPlugin: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    let outputURL = context.pluginWorkDirectoryURL
      .appending(path: "AppCheckDebugToken.generated.swift")
    let scriptURL = context.package.directoryURL
      .appending(path: "FirebaseAppCheck/Scripts/inject_debug_token.sh")

    var plistURL: URL?
    if let sourceTarget = target as? SourceModuleTarget {
      for file in sourceTarget.sourceFiles where file.url.lastPathComponent == "GoogleService-Info.plist" {
        plistURL = file.url
        break
      }
    }
    if plistURL == nil {
      let candidate = target.directoryURL.appending(path: "GoogleService-Info.plist")
      if FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
        plistURL = candidate
      }
    }

    return [
      makeBuildCommand(
        scriptURL: scriptURL,
        outputURL: outputURL,
        plistURL: plistURL
      ),
    ]
  }

  private func makeBuildCommand(scriptURL: URL, outputURL: URL, plistURL: URL?) -> Command {
    let outputPath = outputURL.path(percentEncoded: false)
    let plistPath = plistURL?.path(percentEncoded: false) ?? ""
    var inputFiles: [URL] = []
    if let plistURL {
      inputFiles.append(plistURL)
    }

    let scriptPath = scriptURL.path(percentEncoded: false)
    if FileManager.default.fileExists(atPath: scriptPath) {
      inputFiles.append(scriptURL)
      return .buildCommand(
        displayName: "Generate Firebase App Check Debug Token (Debug only)",
        executable: URL(fileURLWithPath: "/bin/sh"),
        arguments: [scriptPath, outputPath, plistPath],
        inputFiles: inputFiles,
        outputFiles: [outputURL]
      )
    }

    let inlineScript = #"""
    set -eu
    OUTPUT_FILE="$1"
    PLIST_PATH="${2:-}"
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    cat > "$OUTPUT_FILE" << 'EOF'
    import Foundation

    #if DEBUG
      @objc(FIRAppCheckInjectedDebugToken)
      public final class FIRAppCheckInjectedDebugToken: NSObject {
        @objc public static let tokens: [String: String] = [:]
        @objc public static let token: String? = nil
      }
    #endif
    EOF
    """#

    return .buildCommand(
      displayName: "Generate Firebase App Check Debug Token (Debug only)",
      executable: URL(fileURLWithPath: "/bin/sh"),
      arguments: ["-c", inlineScript, "inject_debug_token", outputPath, plistPath],
      inputFiles: inputFiles,
      outputFiles: [outputURL]
    )
  }
}

#if canImport(XcodeProjectPlugin)
  extension FirebaseAppCheckDebugTokenPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
      let outputURL = context.pluginWorkDirectoryURL
        .appending(path: "AppCheckDebugToken.generated.swift")
      let scriptURL = context.xcodeProject.directoryURL
        .appending(path: "FirebaseAppCheck/Scripts/inject_debug_token.sh")

      var plistURL: URL?
      for file in target.inputFiles where file.url.lastPathComponent == "GoogleService-Info.plist" {
        plistURL = file.url
        break
      }
      if plistURL == nil {
        let candidate = context.xcodeProject.directoryURL.appending(path: "GoogleService-Info.plist")
        if FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
          plistURL = candidate
        }
      }

      return [
        makeBuildCommand(
          scriptURL: scriptURL,
          outputURL: outputURL,
          plistURL: plistURL
        ),
      ]
    }
  }
#endif
