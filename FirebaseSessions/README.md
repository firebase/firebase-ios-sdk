# Firebase Sessions SDK

## Prerequisites
Follow the [Main Firebase Readme](https://github.com/firebase/firebase-ios-sdk#development)

## Development
### Generating the Project and Test Project

 - `generate_project.sh` uses [cocoapods-generate](https://github.com/square/cocoapods-generate) to create an Xcode Workspace that has the SDK installed for all the SDK's supported platforms. This is useful for test-based development.
 - `generate_testapp.sh` generates and opens a test app with the Sessions SDK included. This is useful for developing the Sessions SDK against a real app.

### Debugging

### Command Line Arguments
You can access command line parameters by following: Press `CMD-Shift-,` => Run => Arguments.

 - `-FIRSessionsDebugEvents` will print Session Start events to the console for debugging purposes.

### Updating the Proto
#### Prerequesites
To update the Sessions Proto, Protobuf is required. To install run:

```
brew install protobuf
```

#### Procedure
 1. Follow the directions in `sessions.proto` for updating it
 1. Run the following to regenerate the nanopb source files: `./FirebaseSessions/ProtoSupport/generate_protos.sh`
 1. Update the SDK to use the new proto fields
