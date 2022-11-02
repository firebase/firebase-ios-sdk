#!/bin/bash

# Copyright 2020 Google LLC
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
#

# Example usage:
# ./generate_protos.sh <path to nanopb>

# Dependencies: git, protobuf, python-protobuf, pyinstaller

readonly DIR="$( git rev-parse --show-toplevel )"

readonly LIBRARY_DIR="${DIR}/FirebaseMessaging/Sources/"
readonly PROTO_DIR="${DIR}/FirebaseMessaging/ProtoSupport/Protos/"
readonly PROTOGEN_DIR="${LIBRARY_DIR}/Protogen/"
readonly INCLUDE_PREFIX="FirebaseMessaging/Sources/Protogen/nanopb/"

./scripts/nanopb/generate_protos.sh "$PROTO_DIR" "$PROTOGEN_DIR" "$INCLUDE_PREFIX"
