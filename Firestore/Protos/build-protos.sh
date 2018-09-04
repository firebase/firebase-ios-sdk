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

# Helper script to build the proto sources from within the cmake build. Expected
# usage is via cmake. The proto sources are already built and checked into
# source control, so you typically won't need to use this unless you change the
# protos.
#
# Expected Usage (from the top source directory):
#   mkdir build
#   cd build
#   cmake ..
#   make -j generate_protos
#   ls Firestore/Protos/generated_protos
#
# The resulting files are *not* moved into source control, nor is a license
# automatically added to them. You might do that (from the top src dir) via:
#
#   echo "..." > PROTO_LICENSE
#   rm -rf Firestore/Protos/{cpp,objc,nanopb}
#   mv build/Firestore/Protos/generated_protos/{cpp,objc,nanopb} \
#       Firestore/Protos/
#   for f in `find Firestore/Protos/{cpp,objc,nanopb} -type f`; do
#     cat PROTO_LICENSE $f > $f.tmp
#     mv $f.tmp $f
#   done
#
#
# Direct usage (only expected via cmake):
#   ./build-protos-cmake.sh PROTOC_BIN GRPC_OBJC_PLUGIN PROTOBUF_PYTHONPATH \
#       NANOPB_GENERATOR_DIR OUT_DIR
# Params:
#   PROTOC_BIN - path to protoc binary.
#   GRPC_OBJC_PLUGIN - path to grpc_objective_c_plugin binary.
#   PROTOBUF_PYTHONPATH - path to python protobuf library. Must match the
#     version of the PROTOC_BIN (or else protoc will notice and error out).
#   NANOPB_GENERATOR_DIR - The directory where the nanopb protoc plugin has been
#     built. This should be the './generator' directory within the nanopb repo.
#   OUT_DIR - The output directory for the generated protos. A subdirectory will
#     be created for each variant (eg objc, cpp, nanopb)

if [ $# -ne 4 ] ; then
  echo "Direct usage strongly discouraged. Use via cmake instead."
  exit 1
fi

readonly PROTOC_BIN="$1"
readonly GRPC_OBJC_PLUGIN="$2"
readonly PROTOBUF_PYTHONPATH="$3"
readonly OUT_DIR="$4"

# Create the output directories for each variant.
mkdir -p "${OUT_DIR}/cpp" "${OUT_DIR}/objc"

# Generate the proto sources for all variants.
# TODO(rsgowman): Eventually, we'll need to run this separately for each
# variant, since grpc only allows a single output directory. For now, we only
# generate the grpc sources for objc, so we don't care.
PYTHONPATH="${PROTOBUF_PYTHONPATH}" "${PROTOC_BIN}" \
  --plugin=protoc-gen-grpc="${GRPC_OBJC_PLUGIN}" \
  -I ./protos/ \
  --cpp_out="${OUT_DIR}/cpp" \
  --objc_out="${OUT_DIR}/objc" \
  --grpc_out="${OUT_DIR}/objc" \
  $(find protos -name *.proto -print | xargs)

# Remove "well-known" protos from objc and cpp. (We get these for free via
# libprotobuf. We only need them for nanopb.)
rm -rf "${OUT_DIR}/objc/google/protobuf/"
rm -rf "${OUT_DIR}/cpp/google/protobuf/"

# CocoaPods does not like paths in library imports, flatten them.
for i in $(find "${OUT_DIR}/objc" -name "*.[mh]"); do
  perl -i -pe 's#import ".*/#import "#' "$i";
done

# Remove the unnecessary extensionRegistry functions.
for i in $(find "${OUT_DIR}/objc" -name "*.[m]"); do
  ./strip-registry.py "$i"
done

# Remove non-buildable code from Annotations.pbobjc.*.
echo "static int annotations_stub  __attribute__((unused,used)) = 0;" > "${OUT_DIR}/objc/google/api/Annotations.pbobjc.m"
echo "// Empty stub file" > "${OUT_DIR}/objc/google/api/Annotations.pbobjc.h"
