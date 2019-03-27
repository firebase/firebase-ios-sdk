#!/bin/bash

# Copyright 2019 Google
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

# From https://stackoverflow.com/a/246128/361918
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Current release of nanopb being used  to build the CCT protos
NANOPB_ZIPFILE="https://github.com/nanopb/nanopb/archive/nanopb-0.3.9.2.tar.gz"

NANOPB_TEMPDIR="$DIR/nanopb_temp"

rm -rf "$NANOPB_TEMPDIR"

echo "Downloading nanopb..."
mkdir -p "$NANOPB_TEMPDIR"
curl -o "$NANOPB_TEMPDIR/nanopb_temp.zip" $NANOPB_ZIPFILE -O -J -L

echo "Unzipping nanopb..."
tar xf "$NANOPB_TEMPDIR/nanopb_temp.zip" -C "$NANOPB_TEMPDIR/" --strip-components=1

echo "Building nanopb..."
pushd "$NANOPB_TEMPDIR"
git init > /dev/null
git add * > /dev/null
git commit -a -m "Initial commit." > /dev/null
GIT_DESCRIPTION=`git describe --always`-macosx-x86
./tools/make_mac_package.sh
NANOPB_BIN_DIR="dist/$GIT_DESCRIPTION"
popd

echo "Removing existing CCT protos..."
rm -rf "GoogleDataTransportCCTSupport/GoogleDataTransportCCTSupport/Classes/Protogen/*"


echo "Generating CCT protos..."
python "$DIR"/proto_generator.py \
  --nanopb \
  --protos_dir=GoogleDataTransportCCTSupport/GoogleDataTransportCCTSupport/Classes/Protos/ \
  --pythonpath="$NANOPB_TEMPDIR/$NANOPB_BIN_DIR/generator" \
  --output_dir=GoogleDataTransportCCTSupport/GoogleDataTransportCCTSupport/Classes/Protogen/ \
  --include=GoogleDataTransportCCTSupport/GoogleDataTransportCCTSupport/Classes/Protos/

rm -rf "$NANOPB_TEMPDIR"