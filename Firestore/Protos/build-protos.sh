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
#   ./build-protos-cmake.sh PROTOC_BIN PROTOBUF_PYTHONPATH NANOPB_GENERATOR_DIR OUT_DIR
# Params:
#   PROTOC_BIN - path to protoc binary.
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
readonly PROTOBUF_PYTHONPATH="$2"
readonly NANOPB_GENERATOR_DIR="$3"
readonly OUT_DIR="$4"

# Create the output directories for each variant.
mkdir -p "${OUT_DIR}/cpp" "${OUT_DIR}/objc" "${OUT_DIR}/nanopb"

# Generate the proto sources for all variants.
PYTHONPATH="${PROTOBUF_PYTHONPATH}" "${PROTOC_BIN}" \
  --plugin="${NANOPB_GENERATOR_DIR}"/protoc-gen-nanopb \
  -I ./protos/ \
  -I "${NANOPB_GENERATOR_DIR}/proto/" \
  --cpp_out="${OUT_DIR}/cpp" \
  --objc_out="${OUT_DIR}/objc" \
  --nanopb_out="--options-file=protos/%s.options --extension=.nanopb:${OUT_DIR}/nanopb" \
  $(find protos -name *.proto -print | xargs)

# Remove "well-known" protos from objc and cpp. (We get these for free via
# libprotobuf. We only need them for nanopb.)
rm -rf "${OUT_DIR}/objc/google/protobuf/"
rm -rf "${OUT_DIR}/cpp/google/protobuf/"

# If a proto uses a field named 'delete', nanopb happily uses that in the
# message definition. Works fine for C; not so much for C++. Rename uses of this
# to delete_ (which is how protoc does it for c++ files.)
perl -i -pe 's/\bdelete\b/delete_/g' $(find "${OUT_DIR}/nanopb" -type f)

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
