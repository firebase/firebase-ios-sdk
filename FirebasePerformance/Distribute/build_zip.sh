#!/bin/bash

# Copyright 2020 Google LLC
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

usage()
{
  echo "USAGE: "
  echo "sh build_zip.sh [--zipbuilder zipbuilder_dir] [--podspec podspec_dir] \\"
  echo "[--out output_dir] --version version"
  echo ""
  echo "By default, zipbuilder_dir is set to ../../ZipBuilder, podspec_dir is \\"
  echo "set to ../../, and output_dir is set to output."
  echo ""
  echo "EXAMPLE: "
  echo "sh build_zip.sh --version 3.2.0"
  echo ""
  echo "sh build_zip.sh --zipbuilder ../../ZipBuilder \\"
  echo "                --podspec ../../ \\"
  echo "                --out output \\"
  echo "                --version 3.2.0"
}

zipbuilder_dir="../../ReleaseTooling"
podspec_dir=""
output_dir=""
version=""

while [[ "$1" != "" ]]; do
  case $1 in
    --zipbuilder )  shift
                    zipbuilder_dir=$1
                    ;;
    --podspec )     shift
                    podspec_dir=$1
                    ;;
    --out )         shift
                    output_dir=$1
                    ;;
    --version )     shift
                    version=$1
                    ;;
    --help )        usage
                    exit
                    ;;
    * )             usage
                    exit 1
  esac
  shift
done

if [[ -z "${zipbuilder_dir}" ]]; then
  zipbuilder_dir="../../ZipBuilder"
fi

if [[ ! -d "${zipbuilder_dir}" ]]; then
  echo "Error: cannot find a valid ZipBuilder directory."
  echo "Please use --zipbuilder to specify the ZipBuilder directory."
  usage
  exit 1
fi

if [[ -z "${podspec_dir}" ]]; then
  podspec_dir="../../"
fi

if [[ ! -d "${podspec_dir}" ]]; then
  echo "Error: cannot find a valid podspec directory."
  echo "Please use --podspec to specify the podspec directory."
  usage
  exit 1
fi

if [[ -z "${version}" ]]; then
  echo "Error: Version number is not provided."
  echo "Please use --version to specify the version number."
  usage
  exit 1
fi

if ! [[ "${version}" =~ ^[1-9]+[0-9]*\.[0-9]+\.[0-9]+ ]]; then
    echo "Error: Illegal version number."
    usage
    exit 1
fi

if [[ -z "${output_dir}" ]]; then
  output_dir="output"
fi

base_dir=`pwd`

# Create a direcotry with hashed name
hash=$(echo -n `date` | md5)
hash_dir=${hash:0:16}

output_dir="$base_dir/$output_dir/$hash_dir"

# Update version number in FirebasePerformance.podspec.
sed -i '' -E "/s\.version/s/[1-9]+[0-9]*\.[0-9]+\.[0-9]+/${version}/" ../../FirebasePerformance.podspec

# Update version number in pods.json.
sed -i '' -E "/version/s/[1-9]+[0-9]*\.[0-9]+\.[0-9]+/${version}/" ./CocoaPods/pods.json

# Create the output directory.
mkdir -p "${output_dir}"

# Create a zip file containing all xcframeworks.
cd "${zipbuilder_dir}"
swift run zip-builder \
  --platforms iphonesimulator iphoneos \
  --disable-build-dependencies \
  --repo-dir "../" \
  --output-dir "${output_dir}" \
  --local-podspec-path "../" \
  --update-pod-repo \
  --zip-pods "$base_dir/CocoaPods/pods.json"

cd "${output_dir}"
unzip Frameworks.zip

# Make a directory with the version name.
sdk_dir=FirebasePerformance-"${version}"
mkdir "${sdk_dir}"
mkdir "${sdk_dir}"/Frameworks
mv "staging/FirebasePerformance.xcframework" "${sdk_dir}"/Frameworks/

cp ../../CocoaPods/README.md ./"${sdk_dir}"

# Clean up and repack SDK to tar.gz.
rm Framework*
rm -rf staging
tar czvf "${sdk_dir}".tar.gz ./"${sdk_dir}"
rm -rf "${sdk_dir}"
