#!/bin/bash

# Copyright 2018 Google
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

# Converts text protos to binary protos. Text protos are retrieved from the
# folder defined by SCRIPT_INPUT_FILE_0 and the generated binary protos are
# stored in the folder defined by SCRIPT_OUTPUT_FILE_0. Both SCRIPT_INPUT_FILE_0
# and SCRIPT_OUTPUT_FILE_0 are defined in the Run Script Build Phase of the
# XCode build target Firestore_FuzzTests_iOS that executes this script. XCode
# defines these environment variables and makes them available to the script.

# Directory that contains the text protos to convert to binary protos.
text_protos_dir="${SCRIPT_INPUT_FILE_0}"

# Create a folder to write binary protos to. This is our corpus.
binary_protos_dir="${SCRIPT_OUTPUT_FILE_0}"
mkdir -p "${binary_protos_dir}"

echo "Converting text proto files in directory: $text_protos_dir"
echo "Writing binary proto files to directory: $binary_protos_dir"

# Run proto conversion command for each file content.
for text_proto_file in "${text_protos_dir}"/*; do
  file_name="$(basename -- "${text_proto_file}")"
  file_content="$(cat "${text_proto_file}")"

  # Choose an appropriate message type depending on the prefix of the file.
  message_type="Value"
  if [[ "${file_name}" == doc-* ]]; then
    message_type="Document"
  elif [[ "${file_name}" == fv-* ]]; then
    message_type="Value"
  elif [[ "${file_name}" == arr-* ]]; then
    message_type="ArrayValue"
  elif [[ "${file_name}" == map-* ]]; then
    message_type="MapValue"
  fi

  # Run the conversion.
  echo "Converting file: ${file_name} (type: ${message_type})"
  echo "${file_content}" \
    | "${SRCROOT}/Pods/!ProtoCompiler/protoc" \
    -I"${SRCROOT}/../../Firestore/Protos/protos" \
    --encode=google.firestore.v1."${message_type}" \
    google/firestore/v1/document.proto > "${binary_protos_dir}/${file_name}"
done
