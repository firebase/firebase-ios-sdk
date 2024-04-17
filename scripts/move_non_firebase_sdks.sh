#!/bin/bash

for xcframework in "${HOME}"/ios_frameworks/Firebase/NonFirebaseSDKs/**/*.xcframework; do
    if [ -d "$xcframework/Resources" ]; then
        for framework_resource in "$xcframework/Resources"/*; do
            for platform in "ios-arm64" "ios-arm64_x86_64-simulator"; do
                framework="$xcframework/$platform/$(basename "$xcframework" .xcframework).framework"
                if [ -d  $framework ]; then
                    cp -rP $framework_resource $framework
                fi
            done
        done
    fi 
done
