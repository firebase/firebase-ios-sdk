# Metrics

A swift utility for collecting project health metrics on Travis and uploading to a database. It
currently only supports parsing a Code Coverage report generated from XCov.

## Run the coverage parser

```
swift build
.build/debug/Metrics -c=example_report.json -o=database.json -p=99
```

This generates a database.json file that can be executed through a pre-existing Java uploader that
will push the data to a Cloud SQL database.

## Run the unit tests

```
swift test
```
