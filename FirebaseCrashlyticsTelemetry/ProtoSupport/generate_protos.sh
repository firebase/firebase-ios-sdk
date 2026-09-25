#!/bin/bash

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

# usage ./generate_protos.sh

set -euo pipefail

readonly DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Version of otel protos used from https://github.com/open-telemetry/opentelemetry-proto/releases
readonly OTEL_PROTO_VERSION="v1.11.0"

# Path to the local copy of the Firebase generation script
readonly FIREBASE_SCRIPT_DIR="$(cd "${DIR}/../../../scripts/nanopb" && pwd)"
readonly FIREBASE_SCRIPT="${FIREBASE_SCRIPT_DIR}/generate_protos.sh"

readonly LIBRARY_DIR="$(cd "${DIR}/../Sources" && pwd)"
readonly PROTO_BASE_DIR="${DIR}/third_party/opentelemetry-proto"
readonly PROTO_DIR="${PROTO_BASE_DIR}/Protos"
readonly OPTIONS_DIR="${DIR}/options"
readonly PROTOGEN_BASE_DIR="${LIBRARY_DIR}/third_party/opentelemetry-proto"
readonly PROTOGEN_DIR="${PROTOGEN_BASE_DIR}/Protogen"

# List of the nested OpenTelemetry schemas we want to fetch
readonly PROTO_FILES=(
  "opentelemetry/proto/common/v1/common.proto"
  "opentelemetry/proto/resource/v1/resource.proto"
  "opentelemetry/proto/trace/v1/trace.proto"
  "opentelemetry/proto/collector/trace/v1/trace_service.proto"
)

echo "📥 Creating temporary directory..."
TEMP_DIR="$(mktemp -d)"

track_temp_dir_cleanup() {
  rm -rf "${TEMP_DIR}"
}
trap track_temp_dir_cleanup EXIT

echo "📥 Cloning OpenTelemetry Protos repository at version ${OTEL_PROTO_VERSION}..."
git clone \
  --quiet \
  --depth 1 \
  --branch "${OTEL_PROTO_VERSION}" \
  https://github.com/open-telemetry/opentelemetry-proto.git \
  "${TEMP_DIR}"

echo "🔄 Refreshing structures in ${PROTO_DIR}..."
rm -rf "${PROTO_DIR}"
mkdir -p "${PROTO_DIR}"

for file_path in "${PROTO_FILES[@]}"; do
  # Imports in otel protos a relative to the dir structure so we
  # need to maintain the structure when copying the proto files we need
  dest_file_dir="${PROTO_DIR}/$(dirname "${file_path}")"
  mkdir -p "${dest_file_dir}"
  cp "${TEMP_DIR}/${file_path}" "${PROTO_DIR}/${file_path}"
  echo "   ✅ Imported Proto: ${file_path}"
  
  # Copy matching .option files from ProtoSupport/Options and place it next to the .proto
  file_name=$(basename "${file_path}" .proto)
  options_source="${OPTIONS_DIR}/${file_name}.options"
  if [ -f "${options_source}" ]; then
    cp "${options_source}" "${dest_file_dir}/${file_name}.options"
    echo "   ➕ Paired Options: ${file_name}.options -> ${dest_file_dir}/"
  fi
done

echo "🧹 Cleaning previous compiled C/H outputs in ${PROTOGEN_DIR}..."
rm -rf "${PROTOGEN_DIR}"
mkdir -p "${PROTOGEN_DIR}"

if [ ! -f "${FIREBASE_SCRIPT}" ]; then
  echo "❌ Error: Could not find 'generate_protos.sh' at: ${FIREBASE_SCRIPT}" >&2
  exit 1
fi

echo "⚙️ Compiling nanopb protobufs via local copy of generate_protos.sh from the firebase-ios-sdk"
bash "${FIREBASE_SCRIPT}" \
  "${PROTO_DIR}" \
  "${PROTOGEN_DIR}" \
  ""

if [ -f "${TEMP_DIR}/LICENSE" ]; then
  mkdir -p "${PROTO_BASE_DIR}"
  cp "${TEMP_DIR}/LICENSE" "${PROTO_BASE_DIR}/LICENSE"
  mkdir -p "${PROTOGEN_BASE_DIR}"
  cp "${TEMP_DIR}/LICENSE" "${PROTOGEN_BASE_DIR}/LICENSE"
  echo "   📄 Imported LICENSE"
fi

mkdir -p "${PROTO_BASE_DIR}"
echo "${OTEL_PROTO_VERSION}" > "${PROTO_BASE_DIR}/VERSION"
mkdir -p "${PROTOGEN_BASE_DIR}"
echo "${OTEL_PROTO_VERSION}" > "${PROTOGEN_BASE_DIR}/VERSION"
echo "   📄 Created VERSION"

echo "🎉 Nanopb proto generation completed successfully!"
echo "📂 Outputs placed in: ${PROTOGEN_DIR}"
