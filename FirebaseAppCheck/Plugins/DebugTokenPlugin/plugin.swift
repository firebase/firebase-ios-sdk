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

/// Embeds the Firebase App Check debug token for the target's app in Debug builds.
///
/// Before every build, the plugin looks up the token for the `GOOGLE_APP_ID` in the target's
/// `GoogleService-Info.plist` in the Firebase CLI configuration file and generates
/// `AppCheckDebugToken.generated.swift`. See README.md for details.
@main
struct FirebaseAppCheckDebugTokenPlugin: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    let files = (target as? SourceModuleTarget)?.sourceFiles.map(\.url) ?? []
    return try [
      DebugTokenGenerator.command(
        workDirectory: context.pluginWorkDirectoryURL,
        googleServiceInfoPlist: DebugTokenGenerator.googleServiceInfoPlist(
          in: files,
          fallbackDirectory: target.directoryURL
        )
      ),
    ]
  }
}

#if canImport(XcodeProjectPlugin)
  import XcodeProjectPlugin

  extension FirebaseAppCheckDebugTokenPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext,
                             target: XcodeTarget) throws -> [Command] {
      return try [
        DebugTokenGenerator.command(
          workDirectory: context.pluginWorkDirectoryURL,
          googleServiceInfoPlist: DebugTokenGenerator.googleServiceInfoPlist(
            in: target.inputFiles.map(\.url),
            fallbackDirectory: context.xcodeProject.directoryURL
          )
        ),
      ]
    }
  }
#endif

enum DebugTokenGenerator {
  static let plistName = "GoogleService-Info.plist"

  static func googleServiceInfoPlist(in files: [URL], fallbackDirectory: URL) -> URL? {
    if let plist = files.first(where: { $0.lastPathComponent == plistName }) {
      return plist
    }
    let candidate = fallbackDirectory.appending(path: plistName)
    if FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
      return candidate
    }
    Diagnostics.warning(
      "FirebaseAppCheckDebugTokenPlugin: \(plistName) not found; no App Check debug token " +
        "will be embedded."
    )
    return nil
  }

  /// Locations of the Firebase CLI configuration file, in lookup order. Matches the CLI's
  /// configstore: `$XDG_CONFIG_HOME/configstore` when `XDG_CONFIG_HOME` is set, otherwise
  /// `~/.config/configstore`.
  static func configFileCandidates() -> [String] {
    var directories: [URL] = []
    if let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"],
       !xdgConfigHome.isEmpty {
      directories.append(URL(fileURLWithPath: xdgConfigHome).appending(path: "configstore"))
    }
    directories.append(
      FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/configstore")
    )
    return directories.map {
      $0.appending(path: "firebase-appcheck.json").path(percentEncoded: false)
    }
  }

  /// A prebuild command runs before every build, so a new or rotated token is picked up without a
  /// clean build. The script is embedded in the plugin because a plugin can't reference files in
  /// its own package from a client's build; it's written to the plugin work directory so that
  /// build logs show a short command line.
  static func command(workDirectory: URL, googleServiceInfoPlist: URL?) throws -> Command {
    let scriptURL = workDirectory.appending(path: "embed_debug_token.sh")
    let scriptData = Data(script.utf8)
    if (try? Data(contentsOf: scriptURL)) != scriptData {
      try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
      try scriptData.write(to: scriptURL, options: .atomic)
    }
    let outputDirectory = workDirectory.appending(path: "GeneratedSources")
    return .prebuildCommand(
      displayName: "Embed Firebase App Check debug token (Debug builds only)",
      executable: URL(fileURLWithPath: "/bin/sh"),
      arguments: [
        scriptURL.path(percentEncoded: false),
        outputDirectory.path(percentEncoded: false),
        googleServiceInfoPlist?.path(percentEncoded: false) ?? "",
      ] + configFileCandidates(),
      outputFilesDirectory: outputDirectory
    )
  }

  /// Arguments: output directory, `GoogleService-Info.plist` path (may be empty), and candidate
  /// configuration file paths. Keep in sync with FirebaseAppCheck/Scripts/inject_debug_token.sh.
  static let script = #"""
  set -eu
  PATH=/usr/bin:/bin:/usr/sbin:/sbin
  export PATH

  output_dir="$1"
  plist_path="$2"
  shift 2
  output_file="$output_dir/AppCheckDebugToken.generated.swift"
  tmp_file="$(dirname "$output_dir")/AppCheckDebugToken.generated.swift.tmp"
  mkdir -p "$output_dir"

  config_file=""
  for candidate in "$@"; do
    if [ -f "$candidate" ]; then
      config_file="$candidate"
      break
    fi
  done

  app_id=""
  if [ -n "$plist_path" ] && [ -f "$plist_path" ]; then
    app_id="$(plutil -extract GOOGLE_APP_ID raw -o - "$plist_path" 2>/dev/null || true)"
  fi

  token=""
  if [ -n "$config_file" ] && [ -n "$app_id" ]; then
    case "$app_id" in
      *[!0-9A-Za-z:_-]*)
        echo "warning: FirebaseAppCheckDebugTokenPlugin: unexpected GOOGLE_APP_ID format." >&2
        ;;
      *)
        token="$(plutil -extract "tokens.$app_id" raw -o - "$config_file" 2>/dev/null || true)"
        ;;
    esac
    # Only accept characters that can't break out of the generated Swift string literal.
    case "$token" in
      *[!0-9A-Za-z._~-]*)
        echo "warning: FirebaseAppCheckDebugTokenPlugin: ignoring malformed debug token." >&2
        token=""
        ;;
    esac
    if [ -z "$token" ]; then
      echo "note: FirebaseAppCheckDebugTokenPlugin: no debug token for $app_id in $config_file." >&2
    fi
  fi

  if [ -n "$token" ]; then
    tokens="[\"$app_id\": \"$token\"]"
  else
    tokens="[:]"
  fi

  cat > "$tmp_file" <<EOF
  // Generated by FirebaseAppCheckDebugTokenPlugin. Do not edit or commit this file.
  import Foundation

  #if DEBUG
    @objc(FIRAppCheckInjectedDebugToken)
    public final class FIRAppCheckInjectedDebugToken: NSObject {
      @objc public static let tokens: [String: String] = $tokens
    }
  #endif
  EOF

  # Rewrite the file only when its contents change to avoid unnecessary recompilation.
  if [ -f "$output_file" ] && cmp -s "$tmp_file" "$output_file"; then
    rm -f "$tmp_file"
  else
    mv -f "$tmp_file" "$output_file"
  fi
  """#
}
