# Metrics

A swift utility for collecting project health metrics on Travis and uploading to a database. It
currently only supports parsing a Code Coverage report generated from XCov.

## Run the metrics uploader

Make sure that a valid database.config is in the current directory.

```
host:<Cloud SQL IP address>
database:<Database Name>
user:<Username>
password:<Password>
```

Use the following commands to build and run.  This will parse the example coverage report and
upload the results to the database.

```
swift build
.build/debug/Metrics -c Tests/MetricsTests/example_report.json -p 99
```


## Run the unit tests

```
swift test
```
