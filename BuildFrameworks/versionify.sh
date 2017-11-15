#!/bin/bash

set -euxo pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

framework_dir=$1
platform=$2

framework_no_platform=$(basename "$framework_dir" | sed -e 's/_[^\/]*$//')

cd $framework_dir
executable=$(find . -maxdepth 1 -type f | grep 'Fire' | sed -e 's/^..//')

mkdir -p $framework_dir/Versions/A/Resources

pushd .
cd $framework_dir/Versions
ln -s A Current 
popd

mv "$framework_dir/Headers" "$framework_dir/Versions/A/Headers"
ln -s Versions/Current/Headers Headers

mv "$framework_dir/Modules" "$framework_dir/Versions/A/Modules"
ln -s Versions/Current/Modules Modules 

ln -s Versions/Current/Resources Resources 

mv "$framework_dir/$executable" "$framework_dir/Versions/A"
ln -s "Versions/Current/$executable" "$framework_dir/$executable" 

cat "$DIR/$platform-Info.plist" | sed -e "s/..(EXECUTABLE_NAME|PRODUCT_BUNDLE_IDENTIFIER|PRODUCT_NAME)../$executable/g" > "$framework_dir/Versions/Current/Resources/Info.plist"

mkdir -p "$framework_dir/../$platform"
platform_dir=$(realpath "$framework_dir/../$platform")
mv "$framework_dir" "$platform_dir/$framework_no_platform.framework"
