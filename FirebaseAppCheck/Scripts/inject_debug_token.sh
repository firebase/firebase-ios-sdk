#!/bin/sh

# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Generates AppCheckDebugToken.generated.swift from ~/.config/configstore/firebase-appcheck.json
# for Debug builds on physical Apple devices.
#
# Usage:
#   inject_debug_token.sh [output_swift_file] [google_service_info_plist]

set -eu

OUTPUT_FILE="${1:-${SCRIPT_OUTPUT_FILE_0:-${DERIVED_FILE_DIR:-.}/AppCheckDebugToken.generated.swift}}"
PLIST_PATH="${2:-${GOOGLE_SERVICE_INFO_PLIST:-}}"

mkdir -p "$(dirname "$OUTPUT_FILE")"

emit_empty_stub() {
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
}

# Safeguard: Never inject debug tokens into non-Debug (Release) Xcode build configurations.
if [ -n "${CONFIGURATION:-}" ]; then
  case "$CONFIGURATION" in
    *Debug* | *debug* | *DEBUG*)
      ;;
    *)
      emit_empty_stub
      exit 0
      ;;
  esac
fi

CONFIG_FILE="${FIREBASE_APPCHECK_CONFIG_PATH:-}"
if [ -z "$CONFIG_FILE" ]; then
  HOST_HOME="${SIMULATOR_HOST_HOME:-${HOME:-}}"
  if [ -n "$HOST_HOME" ] && [ -f "$HOST_HOME/.config/configstore/firebase-appcheck.json" ]; then
    CONFIG_FILE="$HOST_HOME/.config/configstore/firebase-appcheck.json"
  elif [ -n "${XDG_CONFIG_HOME:-}" ] && [ -f "$XDG_CONFIG_HOME/configstore/firebase-appcheck.json" ]; then
    CONFIG_FILE="$XDG_CONFIG_HOME/configstore/firebase-appcheck.json"
  fi
fi

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
  emit_empty_stub
  exit 0
fi

# Locate GoogleService-Info.plist if not explicitly provided.
if [ -z "$PLIST_PATH" ] || [ ! -f "$PLIST_PATH" ]; then
  if [ -n "${BUILT_PRODUCTS_DIR:-}" ] && [ -n "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ] && \
     [ -f "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist" ]; then
    PLIST_PATH="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"
  elif [ -n "${PROJECT_DIR:-}" ] && [ -f "${PROJECT_DIR}/GoogleService-Info.plist" ]; then
    PLIST_PATH="${PROJECT_DIR}/GoogleService-Info.plist"
  elif [ -n "${SRCROOT:-}" ] && [ -f "${SRCROOT}/GoogleService-Info.plist" ]; then
    PLIST_PATH="${SRCROOT}/GoogleService-Info.plist"
  fi
fi

GOOGLE_APP_ID="${FIREBASE_GOOGLE_APP_ID:-}"
if [ -z "$GOOGLE_APP_ID" ] && [ -n "$PLIST_PATH" ] && [ -f "$PLIST_PATH" ]; then
  if [ -x /usr/bin/plutil ]; then
    GOOGLE_APP_ID="$(/usr/bin/plutil -extract GOOGLE_APP_ID raw -o - "$PLIST_PATH" 2>/dev/null || true)"
  elif [ -x /usr/libexec/PlistBuddy ]; then
    GOOGLE_APP_ID="$(/usr/libexec/PlistBuddy -c "Print :GOOGLE_APP_ID" "$PLIST_PATH" 2>/dev/null || true)"
  fi
fi

# Extract token(s) from firebase-appcheck.json and write AppCheckDebugToken.generated.swift.
if command -v python3 >/dev/null 2>&1; then
  python3 - "$CONFIG_FILE" "$OUTPUT_FILE" "$GOOGLE_APP_ID" << 'PYEOF'
import json
import sys

config_path = sys.argv[1]
output_path = sys.argv[2]
google_app_id = sys.argv[3] if len(sys.argv) > 3 else ""

tokens_map = {}
try:
    with open(config_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, dict) and isinstance(data.get("tokens"), dict):
        for k, v in data["tokens"].items():
            if isinstance(k, str) and isinstance(v, str) and k and v:
                tokens_map[k] = v
except Exception:
    tokens_map = {}

def swift_escape(val: str) -> str:
    return val.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r")

selected_token = None
if google_app_id and google_app_id in tokens_map:
    selected_token = tokens_map[google_app_id]
elif not google_app_id and len(tokens_map) == 1:
    selected_token = next(iter(tokens_map.values()))

lines = [
    "import Foundation",
    "",
    "#if DEBUG",
    "  @objc(FIRAppCheckInjectedDebugToken)",
    "  public final class FIRAppCheckInjectedDebugToken: NSObject {",
]

if tokens_map:
    lines.append("    @objc public static let tokens: [String: String] = [")
    for k in sorted(tokens_map.keys()):
        lines.append(f'      "{swift_escape(k)}": "{swift_escape(tokens_map[k])}",')
    lines.append("    ]")
else:
    lines.append("    @objc public static let tokens: [String: String] = [:]")

if selected_token:
    lines.append(f'    @objc public static let token: String? = "{swift_escape(selected_token)}"')
else:
    lines.append("    @objc public static let token: String? = nil")

lines.extend([
    "  }",
    "#endif",
    "",
])

with open(output_path, "w", encoding="utf-8") as out:
    out.write("\n".join(lines))
PYEOF
  exit 0
fi

# Fallback when python3 is unavailable: use macOS /usr/bin/plutil.
RESOLVED_TOKEN=""
if [ -n "$GOOGLE_APP_ID" ] && [ -x /usr/bin/plutil ]; then
  RESOLVED_TOKEN="$(/usr/bin/plutil -extract "tokens.${GOOGLE_APP_ID}" raw -o - "$CONFIG_FILE" 2>/dev/null || true)"
fi

if [ -n "$RESOLVED_TOKEN" ]; then
  ESCAPED_TOKEN="$(printf '%s' "$RESOLVED_TOKEN" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  ESCAPED_APP_ID="$(printf '%s' "$GOOGLE_APP_ID" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  cat > "$OUTPUT_FILE" << EOF
import Foundation

#if DEBUG
  @objc(FIRAppCheckInjectedDebugToken)
  public final class FIRAppCheckInjectedDebugToken: NSObject {
    @objc public static let tokens: [String: String] = [
      "${ESCAPED_APP_ID}": "${ESCAPED_TOKEN}",
    ]
    @objc public static let token: String? = "${ESCAPED_TOKEN}"
  }
#endif
EOF
else
  emit_empty_stub
fi
