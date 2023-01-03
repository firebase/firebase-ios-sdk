#!/bin/bash

# Copyright 2022 Google LLC
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
# ./build_protos <path to nanopb>

# Dependencies: git, protobuf, python-protobuf, pyinstaller

readonly DIR="$( git rev-parse --show-toplevel )"

# Current release of nanopb being used  to build the CCT protos
readonly NANOPB_VERSION="0.3.9.9"
readonly NANOPB_TEMPDIR="${DIR}/scripts/nanopb/nanopb_temp"

readonly PROTO_DIR="$1"
readonly PROTOGEN_DIR="$2"
readonly INCLUDE_PREFIX="$3"

echoColor() {
  COLOR='\033[0;35m'
  NC='\033[0m'
  printf "${COLOR}$1${NC}\n"
}

echoRed() {
  RED='\033[0;31m'
  NC='\033[0m'
  printf "${RED}$1${NC}\n"
}

cleanup_and_exit() {
  rm -rf "${NANOPB_TEMPDIR}"
  exit
}

rm -rf "${NANOPB_TEMPDIR}"

echoColor "Downloading nanopb..."
git clone --branch "${NANOPB_VERSION}" https://github.com/nanopb/nanopb.git "${NANOPB_TEMPDIR}"

echoColor "Building nanopb..."
pushd "${NANOPB_TEMPDIR}"
./tools/make_mac_package.sh
GIT_DESCRIPTION=`git describe --always`-macosx-x86
NANOPB_BIN_DIR="dist/${GIT_DESCRIPTION}"
popd

echoColor "Removing existing protos..."
rm -rf "${PROTOGEN_DIR}/*"

echoColor "Generating protos..."

if ! command -v python &> /dev/null
then
    echoRed ""
    echoRed "'python' command not found."
    echoRed "You may be able to resolve this by installing python with homebrew and linking 'python' to 'python3'. Eg. run:"
    echoRed ""
    echoRed '$ brew install python && cd $(dirname $(which python3)) && ln -s python3 python'
    echoRed ""
    cleanup_and_exit
fi

python "${DIR}/scripts/nanopb/proto_generator.py" \
  --nanopb \
  --protos_dir="${PROTO_DIR}" \
  --pythonpath="${NANOPB_TEMPDIR}/${NANOPB_BIN_DIR}/generator" \
  --output_dir="${PROTOGEN_DIR}" \
  --include="${PROTO_DIR}" \
  --include_prefix="${INCLUDE_PREFIX}"

RED='\033[0;31m'
NC='\033[0m'
echoRed ""
echoRed ""
echoRed -e "Important: Any new proto fields of type string, repeated, or bytes must be specified in the proto's .options file with type:FT_POINTER"
echoRed ""
echoRed ""

cleanup_and_exit
