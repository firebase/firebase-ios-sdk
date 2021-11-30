#!/bin/bash
function FoldBuildcacheParams() {
  local XCODEBUILD_ARGS=$1
  XCODEBUILD_ARGS="CC=clang CPLUSPLUS=clang++ LD=clang LDPLUSPLUS=clang++ ${XCODEBUILD_ARGS}"
}

XCODE_COMMAND=$1

if [ "$XCODE_COMMAND" == "echo" ]; then
    XCODEBUILD_ARGS="${@:2}"
    FoldBuildcacheParams $XCODEBUILD_ARGS
    echo xcodebuild ${XCODEBUILD_ARGS}
else
    XCODEBUILD_ARGS="$@"
    FoldBuildcacheParams $XCODEBUILD_ARGS
    xcodebuild ${XCODEBUILD_ARGS}
fi
