#!/bin/bash

# Copyright 2017 Google
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Run this script from firebase-ios-sdk/Firestore/Protos to regnenerate the
# Objective C files from the protos.

# pod update to install protoc and the gRPC plugin compiler.
rm -rf Pods
rm Podfile.lock
pod update

# Generate the objective C files from the protos.
./Pods/!ProtoCompiler/protoc \
  --plugin=protoc-gen-grpc=Pods/\!ProtoCompiler-gRPCPlugin/grpc_objective_c_plugin \
  --plugin=../../build/external/nanopb/src/nanopb-build/generator/protoc-gen-nanopb \
  -I protos --objc_out=objc --grpc_out=objc \
  --nanopb_out="--options-file=protos/%s.options:nanopb" \
  `find protos -name *.proto -print | xargs`

# If a proto uses a field named 'delete', nanopb happily uses that in the
# message definition. Works fine for C; not so much for C++. Rename uses of this
# to delete_ (which is how protoc does it for c++ files.)
perl -i -pe 's/\bdelete\b/delete_/g' `find nanopb -type f`

# CocoaPods does not like paths in library imports, flatten them.

for i in `find objc  -name "*.[mh]"` ; do
  perl -i -pe 's#import ".*/#import "#' $i;
done

# Remove the unnecessary extensionRegistry functions.

for i in `find objc  -name "*.[m]" ` ; do
  ./strip-registry.py $i
done

# Remove non-buildable code from Annotations.pbobjc.*.

echo "static int annotations_stub  __attribute__((unused,used)) = 0;" > objc/google/api/Annotations.pbobjc.m
echo "// Empty stub file" > objc/google/api/Annotations.pbobjc.h
