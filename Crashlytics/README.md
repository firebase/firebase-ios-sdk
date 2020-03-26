# Firebase Crashlytics SDK

## Development

Follow the subsequent instructions to develop, debug, unit test, and
integration test FirebaseCrashlytics:

### Prereqs

- At least CocoaPods 1.6.0
- Install [cocoapods-generate](https://github.com/square/cocoapods-generate)
- For nanopb and GDT:
    - `brew install protobuf nanopb-generator`
    - `easy_install protobuf python`

### To Develop

- Run `Crashlytics/generate_project.sh`
- `open gen/FirebaseCrashlytics/FirebaseCrashlytics.xcworkspace`

You're now in an Xcode workspace generate for building, debugging and
testing the FirebaseCrashlytics CocoaPod.

### Running Unit Tests

Open the generated workspace, choose the FirebaseCrashlytics-Unit-unit scheme and press Command-u.

### Changing crash report uploads (using GDT)

#### Update report proto

If the crash report proto needs to be updated, follow these instructions:

- Update `ProtoSupport/Protos/crashlytics.proto` with the new changes
- Depending on the type of fields added/removed, also update `ProtoSupport/Protos/crashlytics.options`.
 `CALLBACK` type fields in crashlytics.nanopb.c needs to be changed to `POINTER`
 (through the options file). Known field types that require an entry in crashlytics.options are
 `strings`, `repeated` and `bytes`.
- Run `generate_project.sh` to update the nanopb .c/.h files.

#### Debugging missing uploads

- Verify the report is written out to disk:
    - Generate a crash
    - Disable internet on the device
    - Export out the app data
        - XCode -> Windows -> Devices and Simulator ->  
        Select device -> Settings icon -> Download app data
    - View event in google-sdks-events folder
        - `AppData/Library/Caches/google-sdks-events`
    - There will be some non-Crashlytics events (~299B), but look for events that are in the magnitude of kilobytes. Open the files and you should see the contents of the clsrecords.
- Verify the event was sent to the backend:
    - Enable verbose logging for GDT. Search for the `GDT_VERBOSE_LOGGING` macro and set the value to `1`.
    - In `[GDTCCTUploader uploadPackage]`, put a breakpoint after the receiving a response from 
    the server
        - With GoogleDataTransportCCTSupport 2.0.1, put a breakpoint on line 201.
    - Check if error is nil
       - If not, run the following command in the debugger: `po [[NSString alloc] initWithData:data encoding:1]`
        for additional information.
- Verify the data sent up is be successfully decoded:
    - Generate a crash and before relaunching the app, copy the contents inside the crash report folder
     from app data (`AppData/Library/Caches/{bundle_id}/{version}/reports/active/{report_id}`) to
      `Crashlytics/UnitTests/Data/bare_min_crash`
    - Run `[FIRCLSAdapterTests testProtoOutput]` to export encoded bytes into a file
    - Put a breakpoint before the end of the test to copy the file (`output.proto`) before it gets 
    deleted
    - Run the command to decode binaries using the proto: `protoc --decode google_crashlytics.Report --proto_path=. crashlytics.proto < output.proto`
    - Sample command to append commands together: `cp /Users/{user}/Library/Developer/Xcode/DerivedData/FirebaseCrashlytics-hfsqekzlhvlckxemmmikglxrkxqt/Build/Products/Debug-iphonesimulator/FirebaseCrashlytics-iOS-Unit-unit.xctest/output.proto test_folder && cp {git_root}/Crashlytics/ProtoSupport/Protos/crashlytics.proto test_folder && protoc --decode google_crashlytics.Report --proto_path=. crashlytics.proto < output.proto`