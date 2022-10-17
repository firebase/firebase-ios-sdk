# Firebase Sessions SDK

## Prerequisites

To update the Sessions Proto, Protobuf is required. To install run:

```
brew install protobuf
```

## Updating the Proto

 1. Follow the directions in `sessions.proto` for updating it
 1. Run the following to regenerate the nanopb source files: `./FirebaseSessions/ProtoSupport/generate_protos.sh`
 1. Update the SDK to use the new proto fields
