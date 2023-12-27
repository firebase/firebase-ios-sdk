#!/bin/bash

#This is a convenience script to build protos and generate Swift files
#It requires the Swift grpc and proto plugins which are part of swift-grpc project

protoc_path="protoc"
sdk_folder="/Users/aashishp/Code/firebase-private/firebase-ios-sdk"
sdk_name="FirebaseDataConnect"
plugin_folder="/Users/aashishp/Code/grpc-swift/.build/release"


protoc data_service.proto \
    --proto_path=$sdk_folder/$sdk_name/Protos/ \
    --plugin=$plugin_folder/protoc-gen-swift \
    --swift_opt=Visibility=Public \
    --swift_out=$sdk_folder/$sdk_name/Sources/ProtoGen \
    --plugin=$plugin_folder/protoc-gen-grpc-swift \
    --grpc-swift_opt=Visibility=Public \
    --grpc-swift_out=$sdk_folder/$sdk_name/Sources/ProtoGen


