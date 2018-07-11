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

# Converts text protos to binary protos and writes the output binary protos to
# the output folder that is specified in SCRIPT_OUTPUT_FILE_0, which is
# retrieved from the Output Files of the Run Script Build Phase that executes
# this script.

# Directory that contains the text protos to convert to binary protos.
text_protos_dir=${SCRIPT_INPUT_FILE_0}

# Create a folder to write binary protos to. This is our corpus.
binary_protos_dir=${SCRIPT_OUTPUT_FILE_0}
mkdir -p ${binary_protos_dir}

echo "Converting text proto files in directory: $text_protos_dir"
echo "Writing binary proto files to directory: $binary_protos_dir"

# Run proto conversion command for each file content.
for text_proto_file in $text_protos_dir/*
do
  file_name=$(basename -- "$text_proto_file")
  file_content=`cat $text_proto_file`

  # Choose an appropriate message type depending on the prefix of the file.
  message_type="Value"
  if [[ $file_name == doc-* ]]; then
    message_type="Document"
  elif [[ $file_name == fv-* ]]; then
    message_type="Value"
  elif [[ $file_name == arr-* ]]; then
    message_type="ArrayValue"
  elif [[ $file_name == map-* ]]; then
    message_type="MapValue"
  fi

  # Run the conversion.
  echo "Converting file: $file_name (type: $message_type)"
  echo "$file_content" \
    | ${SRCROOT}/../../build/external/protobuf/src/protobuf-build/src/protoc \
    -I${SRCROOT}/../../Firestore/Protos/protos \
    -I${SRCROOT}/../../build/external/protobuf/src/protobuf/src \
    --encode=google.firestore.v1beta1."$message_type" \
    google/firestore/v1beta1/document.proto \
    | tee "$binary_protos_dir"/"$file_name" > /dev/null
done
