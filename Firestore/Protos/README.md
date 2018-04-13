## Usage

```
cd firebase-ios-sdk/Firestore/Protos
./build-protos.sh
```

Verify diffs, tests and make PR

### Script Details

Get the protoc and the gRPC plugin. See
[here](https://github.com/grpc/grpc/tree/master/src/objective-c). The
easiest way I found was to add
`pod '!ProtoCompiler-gRPCPlugin'` to a Podfile and do `pod update`.

After running the protoc, shell commands run to fix up the generated code:
  * Flatten import paths for CocoaPods library build.
  * Remove unneeded extensionRegistry functions.
  * Remove non-buildable code from Annotations.pbobjc.*.
