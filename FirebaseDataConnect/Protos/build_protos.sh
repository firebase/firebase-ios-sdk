#!/bin/bash

#This is a temporary convenience script.

protoc_path="protoc"
sdk_folder="/Users/aashishp/Code/firebase-private/firebase-ios-sdk"
plugin_folder="/Users/aashishp/Code/grpc-swift/.build/release"


protoc data_service.proto \
    --proto_path=$sdk_folder/FirebaseDataConnect/Protos/ \
    --plugin=$plugin_folder/protoc-gen-swift \
    --swift_opt=Visibility=Public \
    --swift_out=$sdk_folder/FirebaseDataConnect/Sources/ProtoGen \
    --plugin=$plugin_folder/protoc-gen-grpc-swift \
    --grpc-swift_opt=Visibility=Public \
    --grpc-swift_out=$sdk_folder/FirebaseDataConnect/Sources/ProtoGen


