#  FirebaseDataConnect

1. First build the Swift proto extension/plugin

- Clone the grpc-swift project.
- From Terminal, go the grpc-swift folder that you cloned above
- Follow instructions from here ->
https://github.com/grpc/grpc-swift#getting-the-protoc-plugins

2. Then run the following to generate the Swift code

protoc [PATH_TO_FIREBASE_IOS_SDK_FOLDER]/FirebaseDataConnect/Protos/data_service.proto \
    --proto_path=[PATH_FIREBASE_IOS_SDK_FOLDER]/FirebaseDataConnect/Protos \
    --plugin=[PATH_TO_SWIFT_PLUGINS]/protoc-gen-swift \
    --swift_opt=Visibility=Public \
    --swift_out=[PATH_TO_FIREBASE_IOS_SDK_FOLDER]/FirebaseDataConnect/Protos \
    --plugin=[PATH_TO_SWIFT_PLUGINS]/protoc-gen-grpc-swift \
    --grpc-swift_opt=Visibility=Public \
    --grpc-swift_out=[PATH_TO_FIREBASE_IOS_SDK]/FirebaseDataConnect/Protos
