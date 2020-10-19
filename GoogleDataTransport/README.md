# Google Data Transport Lib

This library is for internal Google use only. It allows the logging of data and
telemetry from Google SDKs.

## Set logging level

### Swift

- Import `GoogleDataTransport` module:
    ```
    import GoogleDataTransport
    ```
- Set logging level global variable to the desired value before calling `FirebaseApp.config()`:
    ```
    GDTCORConsoleLoggerLoggingLevel = GDTCORLoggingLevel.debug.rawValue
    ```
### Objective-C

- Import `GoogleDataTransport`:
    ```
    #import <GoogleDataTransport/GoogleDataTransport.h>
    ```
- Set logging level global variable to the desired value before calling `-[FIRApp config]`:
    ```
    GDTCORConsoleLoggerLoggingLevel = GDTCORLoggingLevelDebug;
    ```

## Prereqs

- `gem install --user cocoapods cocoapods-generate`
- `brew install protobuf nanopb-generator`
- `easy_install --user protobuf`

## To develop

- Run `generate_project.sh` after installing the prereqs

## When adding new logging endpoint

- Use commands similar to:
    - `python -c "line='https://www.firebase.com'; print line[0::2]" `
    - `python -c "line='https://www.firebase.com'; print line[1::2]" `

## When adding internal code that shouldn't be easily usable on github

- Consider using go/copybara-library/scrubbing#cc_scrub